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

// crop videos to path endpoints

// crop videos given two images
// write a video to outpath
//func cropVideoToImages() {
//    // extract images
//    do {
////        let path = URL(fileURLWithPath: "/Users/tobyweed/Desktop/exp1video.mp4")
////        let videoFile = AVAsset(url: path)
////        AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:videoFile error:&error];
////        AVAssetTrack *songTrack = [audioTrackArray objectAtIndex:0];
////        AVAssetReaderTrackOutput *output = [[AVAssetReaderTrackOutput alloc] initWithTrack:songTrack outputSettings:outputSettingsDict];
//
////        let path = URL(fileURLWithPath: "/Users/tobyweed/Desktop/exp1video.mp4")
////        let videoFile = AVAsset(url: path)
////        let videoFileReader = try AVAssetReader(asset: videoFile)
////        let assetReadOutput = AVAssetReaderTrackOutput(track: videoFileReader.outputs[0])
//        //    AVAssetReaderTrackOutput * assetReaderOutput = [videoFileReader.outputs objectAtIndex:0];
//        //    CMSampleBuffer sampleBuffer = [assetReaderOutput copyNextSampleBuffer];
//        //
//        //    CMTime frameTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
//        //    double frameTimeMillisecs = CMTimeGetSeconds(frameTime);
//
//    } catch let err {
//        print(err.localizedDescription)
//    }
//}

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
