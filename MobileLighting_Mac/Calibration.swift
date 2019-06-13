import Foundation
import Yaml

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
