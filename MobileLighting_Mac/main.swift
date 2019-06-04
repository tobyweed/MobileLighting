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

// Communication devices
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
var positions: [String]
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
    // Initialize settings files, then quit
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
        try SceneSettings.create(dirStruc)
        print("successfully created settings file at \(scenesDirectory)/\(sceneName)/settings/sceneSettings.yml")
        print("successfully created trajectory file at \(scenesDirectory)/\(sceneName)/settings/sceneSettings.yml")
        try CalibrationSettings.create(dirStruc)
        print("successfully created calibration file at \(scenesDirectory)/\(sceneName)/settings/sceneSettings.yml")
        try dirStruc.createDirs()
        print("successfully created directory structure.")
    } catch let error {
        print(error.localizedDescription)
    }
    print("MobileLighting exiting...")
    exit(0)
    
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

// save required settings
scenesDirectory = sceneSettings.scenesDirectory
sceneName = sceneSettings.sceneName
minSWfilepath = sceneSettings.minSWfilepath

positions = sceneSettings.trajectory.waypoints

var strucExposureDurations = sceneSettings.strucExposureDurations
var strucExposureISOs = sceneSettings.strucExposureISOs
var calibrationExposure = (sceneSettings.calibrationExposureDuration ?? 0, sceneSettings.calibrationExposureISO ?? 0)

var trajectory = sceneSettings.trajectory

// calibration settings
focus = sceneSettings.focus

// setup directory structure
dirStruc = DirectoryStructure(scenesDir: scenesDirectory, currentScene: sceneName)
do {
    try dirStruc.createDirs()
} catch {
    print("Could not create directory structure at \(dirStruc.scenes)")
    exit(0)
}


/* =========================================================================================
 * Establishes connection with/configures the iPhone and structured lighting displays
 ==========================================================================================*/

// Establish connection with the iPhone and set the instruction packet
initializeIPhoneCommunications()

// focus iPhone if focus provided
if focus != nil {
    let packet = CameraInstructionPacket(cameraInstruction: CameraInstruction.SetLensPosition, lensPosition: Float(focus!))
    cameraServiceBrowser.sendPacket(packet)
    let receiver = LensPositionReceiver { _ in return }
    photoReceiver.dataReceivers.insertFirst(receiver)
}

// Configure the structured lighting displays
if configureDisplays() {
    print("main: Successfully configured display.")
} else {
    print("main: WARNING - failed to configure display.")
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
