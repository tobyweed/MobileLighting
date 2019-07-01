//
//  CommunicationUtils.swift
//  MobileLighting_Mac
//
//  Created by Toby Weed on 6/18/19.
//  Copyright © 2019 Nicholas Mosier. All rights reserved.
//

import Foundation

/*=====================================================================================
 Setup/capture routines and utils
 ======================================================================================*/

// setLensPosition
// -Parameters
//      - lensPosition: Float -> what to set the camera's lens position to
// -Return value: Float -> camera's lens position directly after done adjusting focus
// NOTE: return value seems to be inaccurate - just ignore it for now
func setLensPosition(_ lensPosition: Float) -> Float {
    let packet = CameraInstructionPacket(cameraInstruction: .SetLensPosition, lensPosition: lensPosition)
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
