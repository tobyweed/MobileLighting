//
//  CommunicationUtils.swift
//  MobileLighting_Mac
//
//  Created by Toby Weed on 6/18/19.
//  Copyright © 2019 Nicholas Mosier. All rights reserved.
//

import Foundation
import AVFoundation

/*=====================================================================================
 Setup/capture routines and utils
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
    
    photoReceiver.startBroadcast()
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
