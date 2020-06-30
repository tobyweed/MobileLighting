import Foundation
import Yaml


// Load boards from all eligible .yml file in given directory
func loadBoardsFromDirectory(boardsDir: String) -> [Board] {
    var boardPaths: [String]
    do {
        boardPaths = try FileManager.default.contentsOfDirectory(atPath: "\(boardsDir)/")
    } catch let err {
        print(err.localizedDescription)
        return []
    }
    guard boardPaths.count > 0 else {
        print("No files were found in directory \(boardsDir)/")
        return []
    }
    var boards: [Board] = []
    for path in boardPaths {
        do {
            let board = try Board("\(boardsDir)/\(path)")
            boards.append(board)
        } catch let err {
            print(err.localizedDescription)
            print("Could not initialize board from file \(path).")
        }
    }
    return boards
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
    var cSettingsPath: [CChar]
    do {
        try cSettingsPath = safePath(settingsPath)
    } catch let err {
        print(err.localizedDescription)
        return
    }
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
            if (!debugMode) {
                var posStr = *String(i)
                GotoView(&posStr)
            }

            print("\nTaking image from position \(i)...")

            // take photo at position i
            guard let photoDir = stereoDirDict[i] else {
                print("stereocalib: ERROR -- could not find directory for position \(i)")
                return
            }
            receiveCalibrationImageSync(dir: photoDir, id: photoID)
            
            if i > 0 {
                print("\nDetecting objectPoints...")
                var leftpath: [CChar]
                var rightpath: [CChar]
                do {
                    try leftpath = safePath("\(stereoDirDict[i]!)/IMG\(photoID).JPG")
                    try rightpath = safePath("\(stereoDirDict[i-1]!)/IMG\(photoID).JPG")
                } catch let err {
                    print(err.localizedDescription)
                    break
                }
                // generate image lists for DetectionCheck to read
                generateStereoImageList(left: stereoDirDict[i]!, right: stereoDirDict[i-1]!)
                // make sure DetectionCheck will read from the right image list
                settings.set(key: .ImageList_Filename, value: Yaml.string(dirStruc.stereoImageList))
                settings.save()
                // now perform check what patterns were detected
                _ = DetectionCheck(&cSettingsPath, &leftpath, &rightpath)
            }
            i += 1
        }
        print("\nFinished \(photoID + 1) set.")
            
        // Ask the user if they'd like to retake the photo from that position
        print("Continue (c), retake the last set (r), or finish taking photos (q).")
        var quit = false
        switch readLine() {
        case "c":
            photoID += 1
        case "r":
            print("Retaking...")
        case "q":
            quit = true
        default:
            photoID += 1
        }
        if(quit){ break }
    }
}
