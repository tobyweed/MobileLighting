//
//  Debug.swift
//  MobileLighting
//
//  Created by Nicholas Mosier on 5/28/18.
//

import Foundation
import AVFoundation

// when emulateRobot == true, the program will skip communication with the robot server. used to debug the program without having to connect to the robot. note that this will assume 2 positions, potentially excluding some images from processing if there is data for multiple positions in the scene being processed.
var emulateRobot = false

let shouldSaveOriginals = false
let shouldSendThreshImgs = false

// thresholding parameters
let threshold_val = 0.035

// refinement parameters
let maxdiff0: Float = 1.0
let maxdiff1: Float = 0.1

// rectification
enum RectificationMode {
    case ON_PHONE, ON_MAC, NONE
}

let rectificationMode: RectificationMode = .NONE
let stereoPosition = 1 // change laters // what does that even mean?!?!

// photo capture
let defaultResolution = "high"

// robot control
let robotAcceleration: Float = 0.15
let robotVelocity: Float = 0.15
let robotDelay: Float = 5.0

// calibration detection
let minDetectedObjs: Int = 5

// orientation
//let cameraOrientation: CameraOrientation = .Portrait
let cameraOrientation: AVCaptureVideoOrientation = .landscapeLeft


// torch mode
let torchModeLevel: Float = 1.0 // max
let torchModeFrequency: Double = 5.0 // in flashes / sec

// jpeg quality
let jpegQuality: NSNumber = 1.0
