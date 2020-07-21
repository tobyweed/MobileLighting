//
//  CommunicationUtils.swift
//  MobileLighting_Mac
//
//  Created by Toby Weed on 6/18/19.
//  Copyright © 2019 Nicholas Mosier. All rights reserved.
//

import Foundation
import AVFoundation
import Cocoa

// Struct for coding robot positions to and from JSON strings
struct RobotPose: Codable {
    let posNum: Int
    let translation: [Float]
    let rotation: [[Float]]

    private enum CodingKeys: String, CodingKey {
        case posNum = "pos_num"
        case translation = "translation"
        case rotation = "rotation"
    }
}

/*=====================================================================================
Robot communication
======================================================================================*/
// Attempts to load the path listed on the robot server. Also, writes a JSON file containing the poses returned by the server.
func loadPathFromRobotServer(path: String, emulate: Bool) -> [RobotPose] {
    var poses: [RobotPose] = []
    if( !emulate ) {
        var pathChars = *path
        let jsonBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: 1024) // create a buffer for the C++ to write to
        
        let status = LoadPath(&pathChars, jsonBuffer)
        
        if status < 0 { // print a message if the LoadPath indicates failure
            print("Could not load path \"\(path)\" to Rosvita server. Positions not initialized.")
        } else {
            let jsonString = String(cString: jsonBuffer) // convert the C-string to String
            if(jsonString.isEmpty) {
                print("No robot poses received. Check Rosvita server.")
                return []
            }
            let data: Data? = jsonString.data(using: .utf8) // get a Data object from the String
            do {
                try data!.write(to: URL(fileURLWithPath:"\(dirStruc.tracks)/robot-poses.json"))
                poses = try JSONDecoder().decode([RobotPose].self, from: data!) // attempt to decode Data to [Poses]
            } catch {
                print(error)
                print("Issue loading path \"\(path)\" to Rosvita server. No poses initialized.")
                return []
            }
            print("Succesfully loaded path \"\(path)\".")
        }
    } else {
        print("Emulating robot motion, assigning empty path with 3 positions.")
        return []
    }
    return poses
}



/*=====================================================================================
 Camera setup/capture routines and utils
 ======================================================================================*/

// -Parameters
//      - lensPosition: Float -> what to set the camera's lens position to
// -Return value: Float -> camera's lens position directly after done adjusting focus
// Note that the focus apparently cannot be set perfectly -- there are only some values which the camera focus can be set to, so the camera will default to the closest possible
func setLensPosition(_ lensPosition: Float) -> Float {
    let packet = CameraInstructionPacket(cameraInstruction: .SetLensPosition, lensPosition: lensPosition)
    cameraServiceBrowser.sendPacket(packet)
    let lensPos = photoReceiver.receiveLensPositionSync()
    return lensPos
}

// lock the lens position
func lockLensPosition() -> Float {
    let packet = CameraInstructionPacket(cameraInstruction: .LockLensPosition)
    cameraServiceBrowser.sendPacket(packet)
    let lensPos = photoReceiver.receiveLensPositionSync()
    return lensPos
}

// creates the camera service browser (for sending instructions to iPhone) and
//    the photo receiver (for receiving photos, updates, etc from iPhone)
// NOTE: returns immediately; doens't wait for connection with iPhone to be established.
func initializeIPhoneCommunications() {
    cameraServiceBrowser = CameraServiceBrowser()
    photoReceiver = PhotoReceiver(scenesDirectory)
    
    print("Initializing PhotoReceiver broadcast")
    photoReceiver.startBroadcast()
    print("Initializing CameraServiceBrowser browsing")
    cameraServiceBrowser.startBrowsing()
}

// waits for both photo receiver & camera service browser communications
// to be established (synchronous)
// NOTE: only call if you're sure it won't seize control of the program / cause it to hang
//    e.g. it should be executed within a DispatchQueue
func waitForEstablishedCommunications() {
    while !cameraServiceBrowser.readyToSendPacket {}
    while !photoReceiver.readyToReceive {}
}
