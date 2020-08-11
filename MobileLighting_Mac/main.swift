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
var robotPoses: [RobotPose]
var nPositions = 0
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
        print("Location of scenes folder: ", terminator: "")
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
        // generate sceneSettings and calibration Yaml files with default values
        print("Generating sceneSettings.yml file")
        _ = try SceneSettings.create(dirStruc)
        // set contingent values
        sceneSettings = try SceneSettings(dirStruc.sceneSettingsFile)
        sceneSettings.set( key: "sceneName", value: Yaml.string(sceneName) )
        sceneSettings.set( key: "scenesDir", value: Yaml.string(scenesDirectory) )
        sceneSettings.set( key: "robotPathName", value: Yaml.string("default") )
        sceneSettings.set( key: "minSWdataPath", value: Yaml.string("(Value not initialized. Enter path to minSW data file.)") )
        sceneSettings.save()
        print("Successfully created settings file at \(scenesDirectory)/\(sceneName)/settings/sceneSettings.yml")
        
        // Generate a board
        print("Generating board.yml file")
        try Board.create(dirStruc)
        let board = try Board("\(dirStruc.boardsDir)/board0.yml")
        board.save()
        print("Successfully created board file at \(dirStruc.boardsDir)/board0.yml")
        
//        OLD
        try CalibrationSettings.create(dirStruc)
        // set contingent values
        let calibSettings = CalibrationSettings(dirStruc.calibrationSettingsFile)
        calibSettings.set( key: .ExtrinsicOutput_Filename, value: Yaml.string(dirStruc.calibComputed + "/extrinsics.yml"))
        calibSettings.set( key: .IntrinsicOutput_Filename, value: Yaml.string(dirStruc.calibComputed + "/intrinsics.yml"))
        calibSettings.set( key: .ImageList_Filename, value: Yaml.string(dirStruc.calibration + "/imageLists/intrinsicsImageList.yml"))
        calibSettings.save()
        print("successfully created calibration file at \(scenesDirectory)/\(sceneName)/settings/calibration.yml")
        
        // try to create scenePictures directory
        let sceneInfo = dirStruc.sceneInfo
        try? FileManager.default.createDirectory(atPath: sceneInfo, withIntermediateDirectories: true, attributes: nil)
        
        // try to save scene description file
        let sceneDescription = URL(fileURLWithPath: dirStruc.sceneInfo + "/sceneDescription.txt")
        let text = "Scene name: \(sceneName)\n\nScene location:\n\nScene date:\n\nScene content: (insert description of scene content)\n\nLighting conditions: (insert mapping of directory labels to lighting conditions)\n\nRobot motion: (insert description of robot motion)\n\nProjector configuration: (insert description of projector positions)"
        try? text.write(to: sceneDescription, atomically: false, encoding: String.Encoding.utf8)
        
        // try to create scenePictures directory
        let scenePics = dirStruc.scenePictures
        try? FileManager.default.createDirectory(atPath: scenePics, withIntermediateDirectories: true, attributes: nil)
        
        let defaultDirectory = dirStruc.ambientDefault
        try? FileManager.default.createDirectory(atPath: defaultDirectory, withIntermediateDirectories: true, attributes: nil)
    } catch let error {
        print(error.localizedDescription)
    }
    print("MobileLighting exiting...")
    exit(0)
    
// If there is a scenesettings path provided, read the settings from it
case let path where path.lowercased().hasSuffix(".yml"):
    do {
        print("Reading settings from \(path)...")
        sceneSettingsPath = path
        sceneSettings = try SceneSettings(path)
        print("Settings read successufully.")
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
print("\nInitializing dataset directory structure at \(dirStruc.scenes)/\(sceneName)...")
do {
    try dirStruc.createDirs()
    print("Directory structure already existed or was successfully created.")
} catch {
    print("Could not create directory structure at \(dirStruc.scenes)")
    exit(0)
}


/* =========================================================================================
 * Establishes connection with/configures the iPhone, structured lighting displays, and robot
 ==========================================================================================*/
if(!processingMode) {
    // Configure the structured lighting displays
    print("\nConfiguring structured lighting displays...")
    if configureDisplays() {
        print("Structured lighting display successfully configured.")
    } else {
        print("Failed to configure structured lighting display.")
    }

    // Establish connection with the iPhone and set the instruction packet
    print("\nInitializing iPhone and Mac connection browsing...")
    initializeIPhoneCommunications()

    // Load a path from the robot server
    print("\nLoading path \(sceneSettings.robotPathName) from Rosvita server...")
    loadPathFromRobotServer(path: sceneSettings.robotPathName, emulate: emulateRobot)

    // focus iPhone if focus provided
    if focus != nil {
        print("\nQueuing request to set lens position...")
        // set lens position from value provided in scene settings file
        let packet = CameraInstructionPacket(cameraInstruction: .SetLensPosition, lensPosition: Float(focus!))
        cameraServiceBrowser.sendPacket(packet)
        let receiver = LensPositionReceiver { _ in return }
        photoReceiver.dataReceivers.insertFirst(receiver)
    } else {
        print("No lens position provided. Focus not set")
    }
} else {
    print("\nProgram running in processing mode. Skipping communication initialization.")
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
