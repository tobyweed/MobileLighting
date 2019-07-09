// MOBILELIGHTING DATASET ACQUISITION CONTROL SOFTWARE
//
// main.swift
// MobileLighting_Mac
//
// The entrypoint and main program for MobileLighting_Mac
//

import Foundation
import Cocoa
import CoreFoundation
import CocoaAsyncSocket
import AVFoundation
import SwitcherCtrl
import VXMCtrl
import Yaml

// creates shared application instance
//  required in order for windows (for displaying binary codes) to display properly,
//  since the Mac program compiles to a command-line binary
var app = NSApplication.shared

// when debugMode == true, the program will skip communication with the robot server. used to debug the program without having to connect to the robot. note that this will assume 2 positions, potentially excluding some images from processing if there is data for multiple positions in the scene being processed.
var debugMode = true

// communication devices
var cameraServiceBrowser: CameraServiceBrowser!
var photoReceiver: PhotoReceiver!
var displayController: DisplayController!   // manages Kramer switcher box
var vxmController: VXMController!

// settings
let sceneSettingsPath: String
var sceneSettings: SceneSettings!

// use minsw codes, not graycodes
let binaryCodeSystem: BinaryCodeSystem = .MinStripeWidthCode

// required settings vars
var scenesDirectory: String
var sceneName: String
var minSWfilepath: String
var dirStruc: DirectoryStructure

// optional settings vars
//var projectors: Int?
//var exposureDurations: [Double]
//var exposureISOs: [Double]
var nPositions: Int
let focus: Double?

let mobileLightingUsage = "MobileLighting [path to sceneSettings.yml]\n       MobileLighting init [path to scenes folder [scene name]?]?"
// parse command line arguments
guard CommandLine.argc >= 2 else {
    print("usage: \(mobileLightingUsage)")
    exit(0)
}


/* =========================================================================================
 * Based on provided command line arguments, set the necessary settings
 ==========================================================================================*/

switch CommandLine.arguments[1] {
case "init":
    // Initialize necessary settings files, then quit
    print("MobileLighting: entering init mode...")
    
    // If no path is provided, ask for one
    if CommandLine.argc == 2 {
        print("location of scenes folder: ", terminator: "")
        scenesDirectory = readLine() ?? ""
    } else {
        scenesDirectory = CommandLine.arguments[2]
    }
    
    //If a scene name is provided, use it. Otherwise, ask for one
    if CommandLine.argc == 4 {
        sceneName = CommandLine.arguments[3]
    } else {
        print("scene name: ", terminator: "")
        sceneName = readLine() ?? "untitled"
    }
    
    do {
        dirStruc = DirectoryStructure(scenesDir: scenesDirectory, currentScene: sceneName)
        // Generate sceneSettings and calibration Yaml files with default values
        _ = try SceneSettings.create(dirStruc)
        // Set contingent values
        sceneSettings = try SceneSettings(dirStruc.sceneSettingsFile)
        sceneSettings.set( key: "sceneName", value: Yaml.string(sceneName) )
        sceneSettings.set( key: "scenesDir", value: Yaml.string(scenesDirectory) )
        sceneSettings.set( key: "robotPathName", value: Yaml.string("default") )
        sceneSettings.set( key: "minSWdataPath", value: Yaml.string("(Value not initialized. Enter path to minSW data file.)") )
        sceneSettings.save()
        print("successfully created settings file at \(scenesDirectory)/\(sceneName)/settings/sceneSettings.yml")
        
        try CalibrationSettings.create(dirStruc)
        // Set contingent values
        let calibSettings = CalibrationSettings(dirStruc.calibrationSettingsFile)
        calibSettings.set( key: .ExtrinsicOutput_Filename, value: Yaml.string(dirStruc.calibComputed + "/extrinsics.yml"))
        calibSettings.set( key: .IntrinsicOutput_Filename, value: Yaml.string(dirStruc.calibComputed + "/intrinsics.yml"))
        calibSettings.set( key: .ImageList_Filename, value: Yaml.string(dirStruc.calibration + "/imageLists/intrinsicsImageList.yml"))
        calibSettings.save()
        print("successfully created calibration file at \(scenesDirectory)/\(sceneName)/settings/calibration.yml")
    } catch let error {
        print(error.localizedDescription)
    }
    print("MobileLighting exiting...")
    exit(0)
    
// If there is a scenesettings path provided, read the settings from it
case let path where path.lowercased().hasSuffix(".yml"):
    do {
        sceneSettingsPath = path
        sceneSettings = try SceneSettings(path)
    } catch let error {
        print(error.localizedDescription)
        print("MobileLighting exiting...")
        exit(0)
    }
    
default:
    print("usage: \(mobileLightingUsage)")
    exit(0)
}

// Save the paths to the settings files
scenesDirectory = sceneSettings.scenesDirectory
sceneName = sceneSettings.sceneName
minSWfilepath = sceneSettings.minSWfilepath

// Save the exposure settings
var strucExposureDurations = sceneSettings.strucExposureDurations
var strucExposureISOs = sceneSettings.strucExposureISOs
var calibrationExposure = (sceneSettings.calibrationExposureDuration ?? 0, sceneSettings.calibrationExposureISO ?? 0)

// Save the camera focus
focus = sceneSettings.focus

// Setup directory structure
dirStruc = DirectoryStructure(scenesDir: scenesDirectory, currentScene: sceneName)
do {
    try dirStruc.createDirs()
} catch {
    print("Could not create directory structure at \(dirStruc.scenes)")
    exit(0)
}


/* =========================================================================================
 * Establishes connection with/configures the iPhone, structured lighting displays, and robot
 ==========================================================================================*/
// Configure the structured lighting displays
if configureDisplays() {
    print("Successfully configured display.")
} else {
    print("WARNING - failed to configure display.")
}

// Establish connection with the iPhone and set the instruction packet
initializeIPhoneCommunications()

if( !debugMode ) {
    // Attempt to load the path listed in the sceneSettings file to the Rosvita server
    let path: String = sceneSettings.robotPathName
    var pathPointer = *path
    var status = LoadPath(&pathPointer) // load the path on Rosvita server
    if status < 0 { // print a message if the LoadPath doesn't return 0
        print("Could not load path \"\(path)\" to robot. nPositions not initialized.")
    } else {
        nPositions = Int(status)
        print("Succesfully loaded path with \(nPositions) positions")
    }
} else {
    nPositions = 2
}

// focus iPhone if focus provided
if focus != nil {
    print("Queuing request to set lens position...")
    // set lens position from value provided in scene settings file
    let packet = CameraInstructionPacket(cameraInstruction: .SetLensPosition, lensPosition: Float(focus!))
    cameraServiceBrowser.sendPacket(packet)
    let receiver = LensPositionReceiver { _ in return }
    photoReceiver.dataReceivers.insertFirst(receiver)
    
    print("Queuing request to lock lens position...")
    // lock lens position
    let packet_ = CameraInstructionPacket(cameraInstruction: .LockLensPosition)
    cameraServiceBrowser.sendPacket(packet_)
    let receiver_ = LensPositionReceiver { _ in return }
    photoReceiver.dataReceivers.insertFirst(receiver_)
} else {
    print("No lens position provided. Focus not set")
}


/* =========================================================================================
 * Run the main loop
 ==========================================================================================*/

let mainQueue = DispatchQueue(label: "mainQueue")
//let mainQueue = DispatchQueue.main    // for some reason this causes the NSSharedApp (which manages the windwos for displaying binary codes, etc) to block! But the camera calibration functions must be run from the DisplatchQueue.main, so async them whenever they are called

mainQueue.async {
    while nextCommand() {}
    
    NSApp.terminate(nil)    // terminates shared application
}

NSApp.run()
