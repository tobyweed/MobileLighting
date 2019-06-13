import Foundation
import Yaml


// captureStereoCalibration: captures specified number of image pairs from specified linear robot arm positions
//   -left arm position should be greater (i.e. farther from 0 on robot arm) than right arm position
//   -requires user input to indicate when robot arm has finished moving to position
//   -minimizes # of robot arm movements required
//   -stores images in 'left' and 'right' folders of 'calibration' subdir (under 'orig')
func captureStereoCalibration(left pos0: Int, right pos1: Int, nPhotos: Int, resolution: String = "high") {
    let packet = CameraInstructionPacket(cameraInstruction: .CaptureStillImage, resolution: resolution)
    var receivedCalibrationImage: Bool = false
    let completionHandler = {
        receivedCalibrationImage = true
    }
    let msgMove = "Hit enter when camera in position."
    let msgBoard = "Hit enter when board repositioned."
    let leftSubdir = dirStruc.stereoPhotos(pos0)
    let rightSubdir = dirStruc.stereoPhotos(pos1)
    
    // delete all existing photos
    //    func removeImages(dir: String) -> Void {
    //        guard let paths = try? FileManager.default.contentsOfDirectory(atPath: dir) else {
    //            return
    //        }
    //        for path in paths {
    //            do { try FileManager.default.removeItem(atPath: "\(dir)/\(path)") }
    //            catch let error { print(error.localizedDescription) }
    //        }
    //    }
    removeFiles(dir: leftSubdir)
    removeFiles(dir: rightSubdir)
    
    
    
    let settingsPath = dirStruc.calibrationSettingsFile
    var cSettingsPath = settingsPath.cString(using: .ascii)!
    let settings = CalibrationSettings(settingsPath)
    settings.set(key: .Calibration_Pattern, value: Yaml.string("ARUCO_SINGLE"))
    settings.set(key: .Mode, value: Yaml.string("STEREO"))
    settings.save()
    
    
    var index: Int = 0
    while index < nPhotos {
        var posStr = positions[pos0].cString(using: .ascii)!
        GotoView(&posStr)
        print(msgBoard)
//        guard calibration_wait(currentPos: pos0) else {
//            return
//        }
        
        // take photo at pos0
        cameraServiceBrowser.sendPacket(packet)
        receivedCalibrationImage = false
        photoReceiver.dataReceivers.insertFirst(
            CalibrationImageReceiver(completionHandler, dir: leftSubdir, id: index)
        )
        while !receivedCalibrationImage {}
        
        posStr = positions[pos1].cString(using: .ascii)!
        GotoView(&posStr)
        print(msgMove)
//        guard calibration_wait(currentPos: pos1) else {
//            return
//        }
        
        // take photo at pos1
        cameraServiceBrowser.sendPacket(packet)
        receivedCalibrationImage = false
        
        photoReceiver.dataReceivers.insertFirst(
            CalibrationImageReceiver(completionHandler, dir: rightSubdir, id: index)
        )
        while !receivedCalibrationImage {}
        
        var leftpath = *"\(leftSubdir)/IMG\(index).JPG"
        var rightpath = *"\(rightSubdir)/IMG\(index).JPG"
        let shouldSkip: Bool
        //        var cSettingsPath2 = cSettingsPath
        //        var leftpath2 = *leftpath
        //        var rightpath2 = *rightpath
        _ = DetectionCheck(&cSettingsPath, &leftpath, &rightpath)
        switch readLine() {
        case "c","k":
            shouldSkip = false
        case "s","r","i":
            shouldSkip = true
        default:
            shouldSkip = false
        }
        if shouldSkip {
            print("skipping...")
        } else {
            index += 1
        }
    }
}


// captureNPosCalibration: takes stereo calibration photos for all N positions
func captureNPosCalibration(posIDs: [Int], resolution: String = "high", mode: String) {
    // Instruction packet to take a photo
    let packet = CameraInstructionPacket(cameraInstruction: .CaptureStillImage, resolution: resolution)
    
    // Receive photo
    func receiveCalibrationImageSync(dir: String, id: Int) {
        var received = false
        let completionHandler = {
            received = true
        }
        cameraServiceBrowser.sendPacket(packet)
        let dataReceiver = CalibrationImageReceiver(completionHandler, dir: dir, id: id)
        photoReceiver.dataReceivers.insertFirst(dataReceiver)
        while !received {}
    }
    
    // Get the directories to save photos to
    let stereoDirs = posIDs.map {
        return dirStruc.stereoPhotos($0)
    }
    let stereoDirDict = posIDs.reduce([Int : String]()) { (dict: [Int : String], id: Int) in
        var dictNew = dict
        dictNew[id] = dirStruc.stereoPhotos(id)
        return dictNew
    }
    
    // Determine whether to delete or append to photos already in directory
    var photoID: Int // Determines what ID we should write photos with
    switch mode { // Switch in case we want to add more flags later
    case "-a":
        // not yet implemented. TODO: add delete flag support
        let idArray: [[Int]] = stereoDirs.map { (stereoDir: String) in
            let existingPhotos = try! FileManager.default.contentsOfDirectory(atPath: stereoDir)
            return getIDs(existingPhotos, prefix: "IMG", suffix: ".JPG")
        }
        let maxVal = idArray.map {
            return $0.max() ?? -1 // find max photo ID, or -1 if no photos empty, so that counting will begin at 0
            }.max() ?? -1
        // maxVal = max(idArray)
        photoID = maxVal + 1
        break
    default:
        // erase directories
        for dir in stereoDirs {
            removeFiles(dir: dir)
        }
        photoID = 0
    }
    
    let settingsPath = dirStruc.calibrationSettingsFile
    var cSettingsPath = settingsPath.cString(using: .ascii)!
    let settings = CalibrationSettings(settingsPath)
    settings.set(key: .Calibration_Pattern, value: Yaml.string("ARUCO_SINGLE"))
    settings.set(key: .Mode, value: Yaml.string("STEREO"))
    settings.save()
    
    // take the photos
    while(true) {
        var i = 0
        
        print("Hit enter to take a set or write q to finish taking photos");
        guard let input = readLine() else {
            fatalError("Unexpected error in reading stdin.")
        }
        if ["q", "quit"].contains(input) {
            break
        }
        
        // Take set of calibration photos, one from each position
        while i < posIDs.count {
            // Move the robot to the right position
//            var posStr = *String(i)
//            GotoView(&posStr)
//            usleep(UInt32(robotDelay * 1.0e6)) // pause for a moment
            print("\nTaking image from position \(i)...")

            // take photo at position i
            guard let photoDir = stereoDirDict[i] else {
                print("stereocalib: ERROR -- could not find directory for position \(i)")
                return
            }
            receiveCalibrationImageSync(dir: photoDir, id: photoID)
            
            if i > 0 {
                // now perform detection check
                print("\nDetecting objectPoints...")
                var leftpath = *"\(stereoDirDict[i]!)/IMG\(photoID).JPG"
                var rightpath = *"\(stereoDirDict[i-1]!)/IMG\(photoID).JPG"
                _ = DetectionCheck(&cSettingsPath, &leftpath, &rightpath)
            }
            i += 1
        }
        print("\nFinished set.")
            
        // Ask the user if they'd like to retake the photo from that position
        print("Continue (c), retake the last set (r), or finish taking photos (q).")
        var quit = false
        switch readLine() {
        case "c":
            photoID += 1
        case "s":
            print("Retaking...")
        case "q":
            quit = true
        default:
            photoID += 1
        }
        if(quit){ break }
    }
    
    
}

// Old function with added features we don't need right now
//func calibration_wait(currentPos: Int) -> Bool {
//    var input: String
//    repeat {
//        guard let inputtmp = readLine() else {
//            return false
//        }
//        input = inputtmp
//        let tokens = input.split(separator: " ")
//        if tokens.count == 0 {
//            return true
//        } else if ["exit", "e", "q", "quit", "stop", "end"].contains(tokens[0]) {
//            return false
//        } else if tokens.count == 2, let x = Float(tokens[0]), let y = Float(tokens[1]) {
//            let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
//            let packet = CameraInstructionPacket(cameraInstruction: .SetPointOfFocus, pointOfFocus: point)
//            cameraServiceBrowser.sendPacket(packet)
//            _ = photoReceiver.receiveLensPositionSync()
//        } else if tokens.count == 1, let pos = Int(tokens[0]), pos >= 0 && pos < positions.count {
//            var posStr = *positions[pos]
//            GotoView(&posStr)
//            print("Hit enter when ready to return to original position.")
//        } else {
//            return true
//        }
//    } while true
//}
