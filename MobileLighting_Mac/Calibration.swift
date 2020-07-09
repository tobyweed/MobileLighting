import Foundation
import Yaml

// Load boards from all eligible .yml files in given directory
// returns an array of paths to valid board Yaml files and an array of Boards
// returns empty arrays when errors are thrown
func loadBoardsFromDirectory(boardsDir: String) -> ([String], [Board]) {
    // Retrieve paths of all files in given directory
    var paths: [String]
    do {
        paths = try FileManager.default.contentsOfDirectory(atPath: "\(boardsDir)/")
    } catch let err {
        print(err.localizedDescription)
        return ([],[])
    }
    guard paths.count > 0 else {
        print("No files were found in directory \(boardsDir)/")
        return ([],[])
    }
    
    // Try to load a board from each path. If successful, load a board and add a path to the return list.
    // else print a message
    var boards: [Board] = []
    var boardPaths: [String] = []
    for path in paths {
        do {
            let board = try Board("\(boardsDir)/\(path)")
            boards.append(board)
            boardPaths.append("\(boardsDir)/\(path)")
        } catch let err {
            print(err.localizedDescription)
            print("Could not initialize board from file \(path).")
        }
    }
    return (boardPaths,boards)
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
    
    print("\nHit Enter to begin taking photos, or q then enter to quit.")
    guard let input = readLine() else {
        fatalError("Unexpected error reading stdin.")
    }
    if input == "q" {
        print("Program quit. Exiting command.")
        return
    }

    // Insert photos starting at the correct index, stopping on user prompt
    var keyCode:Int32 = 0;
    var i: Int = photoID;
        while(keyCode != 113) {
        if keyCode == 114 {
            i -= 1
            print("Retaking last set")
        } else {
            print("Taking a photo set")
        }
        var i = 0
        
        // Load and create boards
        print("Collecting board paths")
        let (boardPaths, boards) = loadBoardsFromDirectory(boardsDir: dirStruc.boardsDir) // collect boards
        guard boards.count > 0 else {
            print("No boards were successfully initialized. Exiting.")
            break
        }
        // convert boardPaths from [String] -> [[CChar]] -> [UnsafeMutablePointer<Int8>?] -> Optional<UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>> so they can be passed to C bridging header
        var boardPathsCChar = *boardPaths // Convert [String] -> [[CChar]]
        var boardPathsCpp = **(boardPathsCChar) // Convert [[CChar]] -> [UnsafeMutablePointer<Int8>?]
        
        var calibDataPtrs: [UnsafeMutableRawPointer?] = []
        var imgNames: [String] = []
        // Take set of calibration photos, one from each position
        while i < posIDs.count {
            // Move the robot to the right position
            if (!debugMode) {
                var posStr = *String(i)
                GotoView(&posStr)
            }

            print("\nTaking image from position \(i)...")

            // Take photo at position i
            guard let photoDir = stereoDirDict[i] else {
                print("stereocalib: ERROR -- could not find directory for position \(i)")
                return
            }
            receiveCalibrationImageSync(dir: photoDir, id: i)
            
            print("\nChecking path \(photoDir)/IMG\(i).JPG")
            do {
                try _ = safePath("\(photoDir)/IMG\(i).JPG")
            } catch let err {
                print(err.localizedDescription)
                break
            }
            // Initialize an object to store the data (charuco corners, object points, etc..) gained during calibration photo capture
            var photoDirPtr = *photoDir;
            let calibDataPtr = UnsafeMutableRawPointer(mutating: InitializeCalibDataStorage(&photoDirPtr));
            calibDataPtrs.append(calibDataPtr)
            
            let imgName = "IMG\(i).JPG";
            imgNames.append(imgName);
            
            i += 1
        }
        print("\nFinished \(photoID + 1) set.")
//        print("Imgnames : \(&imgNames[0]) \n data pointers: \(&calibDataPtrs[0])");
        var imgNamesCChar = *imgNames;
        var imgNamesCpp = **(imgNamesCChar);
        
        DispatchQueue.main.sync(execute: {
            keyCode = TrackMarkersStereo(&imgNamesCpp, Int32(imgNames.count), &boardPathsCpp, Int32(boards.count), &calibDataPtrs)
        })
        
        if( keyCode == -1 ) {
            print("Something went wrong with call to TrackMarkers. Exiting command.")
            return;
        }
        
//        // Ask the user if they'd like to retake the photo from that position
//        print("Continue (c), retake the last set (r), or finish taking photos (q).")
//        var quit = false
//        switch readLine() {
//        case "c":
//            photoID += 1
//        case "r":
//            print("Retaking...")
//        case "q":
//            quit = true
//        default:
//            photoID += 1
//        }
//        if(quit){ break }
    }
}
