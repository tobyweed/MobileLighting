//
// ProgramControl.swift
// MobileLighting_Mac
//
// Contains central functions to the program, i.e. setting the camera focus, etc.. Manages these via
// the Command enum for use in CLT format.
//

import Foundation
import Cocoa
import VXMCtrl
import SwitcherCtrl
import Yaml
import AVFoundation

// Enum for all commands
enum Command: String, EnumCollection, CaseIterable {      // rawValues are automatically the name of the case, i.e. .help.rawValue == "help" (useful for ensuring the command-handling switch statement is exhaustive)
    case help
    case unrecognized
    case quit
    case reloadsettings
    case printsettings
    
    // photo capture
    case takeintrinsics, ti
    case takeextrinsics, te
    case struclight, sl
    case takeamb, ta
    
    // camera control
    case readfocus, rf, keepfocus, autofocus, setfocus, lockfocus
    case readexposure, autoexposure, lockexposure, setexposure
    case focuspoint
    
    // projector control
    case proj, p
    case cb     // displays checkerboard
    case black, white
    case diagonal, verticalbars   // displays diagonal stripes (for testing 'diagonal' DLP chip)
    
    // communications & serial control
    case connect
    case disconnect, disconnectall
    
    // robot control
    case loadpath
    case movearm
    case setvelocity
    
    // camera calibration
    case getintrinsics, gi
    case getextrinsics, ge
    case trackexistingstereo
    
    // image processing
    case processpairs, pp
    case refine, ref
    case rectify, rect
    case rectifyamb, ra
    case disparity, d
    case merge, m
    case reproject, rp
    case merge2, m2
    
    // debugging
    case showshadows, ss
    case transform
    case dispres
    case dispcode
    case clearpackets
    case toggledebug
    
    // scripting
    case sleep
}

/*=====================================================================================
MARK: usage messages
======================================================================================*/
// Return usage message for appropriate command
func getUsage(_ command: Command) -> String {
    switch command {
    case .unrecognized: return "Command unrecognized. Type \"help\" for a list of commands."
    case .help: return "help [command name]?"
    case .quit: return "quit"
    case .reloadsettings: return "reloadsettings"
    case .printsettings: return "printsettings [type=scene (calib|scene)]" // print settings of calib or scene type. defaults to scene
    // communications
    case .connect: return "connect (switcher|vxm) [/dev/tty*Repleo*]"
    case .disconnect: return "disconnect (switcher|vxm)"
    case .disconnectall: return "disconnectall"
    // photo capture
    case .takeintrinsics, .ti:
        return "takeintrinsics (-d|-a)?\n       -d: delete existing photos\n       -a: append to existing photos"
    case .takeextrinsics, .te: return "takeextrinsics [resolution=high] (-a)?\n        -d: delete existing photos"
    case .struclight, .sl: return "struclight [projector pos id(s)] [projector #(s)] [position #(s)] [resolution=high]\n"
    case .takeamb, .ta: return "takeamb still (-f|-t)? (-a|-d)? [resolution=high]\n       takeamb video (-f|-t)? [exposure#=1]"
    // camera control
    case .readfocus, .rf: return "readfocus"
    case .keepfocus: return "keepfocus"
    case .autofocus: return "autofocus"
    case .lockfocus: return "lockfocus"
    case .setfocus: return "setfocus [lensPosition s.t. 0≤ l.p. ≤1]"
    case .focuspoint: return "focuspoint [x_coord] [y_coord]"
    case .readexposure: return "readexposure"
    case .autoexposure: return "autoexposure"
    case .lockexposure: return "lockexposure"
    case .setexposure: return "setexposure [exposureDuration] [exposureISO]\n       (set either parameter to 0 to leave unchanged)"
    // projector control
    case .proj, .p: return "proj ([projector_#]|all) (on/1|off/0)"
    case .cb: return "cb [squareSize=2]"
    case .black: return "black"
    case .white: return "white"
    case .diagonal: return "diagonal [stripe width]"
    case .verticalbars: return "verticalbars [width]"
    // robot control
    case .loadpath: return "loadpath [pathname]"
    case .movearm: return "movearm [posID]\n        [pose/joint string]\n       (x|y|z) [dist]"
    case .setvelocity: return "setvelocity [velocity]\n"
    // image processing
    case .processpairs, .pp: return "(processpairs | pp) ([-a] | [projectors]) (-a | [left positions] [right positions])"
    case .refine, .ref: return "(refine | ref) ([-a] | [projectors]) (-a | [left positions] [right positions])"
    case .disparity, .d: return "(disparity | d) ([-a] | [projectors]) (-a | [left positions] [right positions])"
    case .rectify, .rect: return "(rectify | rect) ([-a] | [projectors]) (-a | [left positions] [right positions])"
    case .rectifyamb, .ra: return "(rectifyamb | ra) (-a | [left positions] [right positions])\n"
    case .merge, .m: return "(merge | m) (-a | [left positions] [right positions])"
    case .reproject, .rp: return "(reproject | rp) (-a | [left positions] [right positions])"
    case .merge2, .m2: return "(merge2 | m2) (-a | [left positions] [right positions])"
    // camera calibration
    case .getintrinsics, .gi: return "(getintrinsics | gi)"
    case .getextrinsics, .ge: return "(getextrinsics | ge) (-a | [left positions] [right positions])"
    case .trackexistingstereo: return "trackexistingstereo"
    // debugging
    case .showshadows, .ss: return "(showshadows | ss)"
    case .transform: return "transform"
    case .dispres: return "dispres"
    case .dispcode: return "dispcode"
    case .clearpackets: return "clearpackets"
    case .toggledebug: return "toggledebug"
    case .sleep: return "sleep [secs: Float]"
    }
}

// nextCommand: prompts for next command at command line, then handles command
// -Return value -> true if program should continue, false if should exit
func nextCommand() -> Bool {
    print("> ", terminator: "")
    guard let input = readLine(strippingNewline: true) else {
        // if input empty, simply return & continue execution
        return true
    }
    // filter all non-ASCII characters in the string (eg from arrow key presses)
    let command = input.filter({$0.isASCII})
    return processCommand(command)
}


/*=====================================================================================
MARK: process command
======================================================================================*/
func processCommand(_ input: String) -> Bool {
    var nextToken = 0
    let tokens: [String] = input.split(separator: " ").map{ return String($0) }
    let command: Command
    if let command_ = Command(rawValue: tokens.first ?? "") { // "" is invalid token, automatically rejected
        // if input contains no valid commands, return
        command = command_
    } else {
        command = .unrecognized
    }
    let usage = "usage: \t\(getUsage(command))"
    
    nextToken += 1
    cmdSwitch: switch command {
    case .unrecognized:
        print(usage)
        break
        
    case .help:
        switch tokens.count {
        case 1:
            // print all commands & usage
            for command in Command.allCases {
                print("\(command):\t\(getUsage(command))")
            }
        case 2:
            if let command = Command(rawValue: tokens[1]) {
                print("\(command):\n\(getUsage(command))")
            } else {
                print("Command \(tokens[1]) unrecognized. Enter 'help' for a list of commands")
            }
        default:
            print(usage)
        }
        
    case .quit:
        return false
        
    // rereads scene settings file and reloads attributes
    case .reloadsettings:
        guard tokens.count == 1 else {
            print(usage)
            break
        }
        do {
            sceneSettings = try SceneSettings(sceneSettingsPath)
            print("Successfully loaded scene settings.")
            strucExposureDurations = sceneSettings.strucExposureDurations
            strucExposureISOs = sceneSettings.strucExposureISOs
            if let calibDuration = sceneSettings.calibrationExposureDuration, let calibISO = sceneSettings.calibrationExposureISO {
                calibrationExposure = (calibDuration, calibISO)
            }
        } catch let error {
            print("Fatal error: could not load scene settings, \(error.localizedDescription)")
            break
        }
        
    // print scene settings properties & values
    case .printsettings:
        guard tokens.count <= 2 else {
            print(usage)
            break
        }
        if tokens.count == 2 {
            // print calib or throw an error
            if(tokens[1] == "calib"){
                let calibSettings = CalibrationSettings(dirStruc.calibrationSettingsFile)
                let calibProperties = calibSettings.properties()
                print("Calibration Settings:")
                for prop in calibProperties {
                    print("    \(prop.0): \(prop.1)")
                }
                break
            } else if (tokens[1] != "scene") { // if the second token is not calib or scene, print an error and exit
                print("token \"\(tokens[1])\" is not a valid token.")
                print(usage)
                break
            }
        }
        // if we've gotten this far, print scene settings
        let sceneProperties = sceneSettings.properties()
        print("Scene Settings:")
        for prop in sceneProperties {
            // exclude the yml property
            if(prop.0 != "yml") {
                print("    \(prop.0): \(prop.1)")
            }
        }
    
    // connect: use to connect external devices
    case .connect:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        guard tokens.count >= 2 else {
            print(usage)
            break
        }
        
        switch tokens[1] {
        case "iphone":
            initializeIPhoneCommunications()
            
        case "switcher":
            guard tokens.count == 3 else {
                print("usage: connect switcher: must specify port (e.g. /dev/cu.usbserial\n(hint: ls /dev/cu.*)")
                break
            }
            displayController.switcher = Switcher(portName: tokens[2])
            displayController.switcher!.startConnection()
            
        case "vxm":
            guard tokens.count == 3 else {
                print("connect vxm: must specify port (e.g. /dev/cu.usbserial\n(hint: ls /dev/cu.*)")
                break
            }
            vxmController = VXMController(portName: tokens[2])
            _ = vxmController.startVXM()
            
        case "display":
            guard tokens.count == 2 else {
                print("connect display takes no additional arguments.")
                break
            }
            guard configureDisplays() else {
                print("connect display: failed to configure display.")
                break
            }
            print("connect display: successfully configured display.")
        default:
            print("cannot connect: invalid device name.")
        }
        
    // disconnect: use to disconnect vxm or switcher (generally not necessary)
    case .disconnect:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        guard tokens.count == 2 else {
            print(usage)
            break
        }
        
        switch tokens[1] {
        case "vxm":
            vxmController.stop()
        case "switcher":
            if let switcher = displayController.switcher {
                switcher.endConnection()
            }
        default:
            print("connect: invalid device \(tokens[1])")
            break
        }
        
    // disconnects both switcher and vxm box
    case .disconnectall:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        vxmController.stop()
        displayController.switcher?.endConnection()
      
    /*=====================================================================================
    MARK: photo capture
    ======================================================================================*/
    // takes specified number of calibration images; saves them to (scene)/orig/calibration/other
    case .takeintrinsics, .ti:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        guard tokens.count == 1 || tokens.count == 2 else {
            print(usage)
            break
        }
        
        // Set exposure and ISOs
        if calibrationExposure != (0, 0) {
            let packet = CameraInstructionPacket(cameraInstruction: .SetExposure, photoBracketExposureDurations: [calibrationExposure.0], photoBracketExposureISOs: [calibrationExposure.1])
            cameraServiceBrowser.sendPacket(packet)
        }
        
        // Handle flags
        let _: Int
        let startIndex: Int
        if tokens.count == 2 {
            let mode = tokens[1]
            guard ["-d","-a"].contains(mode) else {
                print("takeintrinsics: unrecognized flag \(mode)")
                break
            }
            let photos = (try! FileManager.default.contentsOfDirectory(atPath: dirStruc.intrinsicsPhotos)).map {
                return "\(dirStruc.intrinsicsPhotos)/\($0)"
            }
            switch mode {
            case "-d":
                for photo in photos {
                    do { try FileManager.default.removeItem(atPath: photo) }
                    catch { print("Could not remove \(photo)") }
                }
                startIndex = 0
//            case "-a":
//                photos = photos.map{
//                    return String($0.split(separator: "/").last!)
//                }
//                let ids: [Int] = photos.map{
//                    guard $0.hasPrefix("IMG"), $0.hasSuffix(".JPG"), let id = Int($0.dropFirst(3).dropLast(4)) else {
//                        return -1
//                    }
//                    return id
//                }
//                startIndex = ids.max()! + 1
            default:
                startIndex = 0
            }
        } else {
            startIndex = 0
        }
        
        // Load and create boards
        print("Collecting board paths")
        let (boardPaths, boards) = loadBoardsFromDirectory(boardsDir: dirStruc.boardsDir) // collect boards
        guard boards.count > 0 else {
            print("ERROR: No boards were successfully initialized.")
            break
        }
        // convert boardPaths from [String] -> [[CChar]] -> [UnsafeMutablePointer<Int8>?] -> Optional<UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>> so they can be passed to C bridging header
        var boardPathsCChar = *boardPaths // Convert [String] -> [[CChar]]
        var boardPathsCpp = **(boardPathsCChar) // Convert [[CChar]] -> [UnsafeMutablePointer<Int8>?]
        
        // Initialize an object to store the data (charuco corners, object points, etc..) gained during calibration photo capture
        var intrinsicsPhotosDir = *dirStruc.intrinsicsPhotos;
        var calibDataPtr: [UnsafeMutableRawPointer?] = [UnsafeMutableRawPointer(mutating: InitializeCalibDataStorage(&intrinsicsPhotosDir))]; // wrapped in an array for compatibility with TrackMarkers
        
        // Prepare for photo capture
        let packet = CameraInstructionPacket(cameraInstruction: .CaptureStillImage, resolution: defaultResolution)
        print("\nHit Enter to begin taking photos, or q then enter to quit.")
        guard let input = readLine() else {
            fatalError("Unexpected error reading stdin.")
        }
        if input == "q" {
            print("Program quit. Exiting command \(tokens[0])")
            break
        }
        
        // Insert photos starting at the correct index, stopping on user prompt
        var keyCode:Int32 = 0;
        var i: Int = startIndex;
        while(keyCode != 113) {
            if keyCode == 114 {
                i -= 1
                print("Retaking last photo")
            } else{
                print("Taking a photo")
            }
            
            // Capture calibration photo
            var receivedCalibrationImage = false
            cameraServiceBrowser.sendPacket(packet)
            let completionHandler = { receivedCalibrationImage = true }
            photoReceiver.dataReceivers.insertFirst(
                CalibrationImageReceiver(completionHandler, dir: dirStruc.intrinsicsPhotos, id: i)
            )
            while !receivedCalibrationImage {}
            
            // Make sure there is a photo where we think there is
            do {
                try _ = safePath("\(dirStruc.intrinsicsPhotos)/IMG\(i).JPG")
            } catch let err {
                print("No file found with name \(dirStruc.intrinsicsPhotos)/IMG\(i).JPG")
                print(err.localizedDescription)
                break
            }
            let imgName = "IMG\(i).JPG"
            var imgNamesCChar = *[imgName]
            var imgNameCpp = **(imgNamesCChar); // wrap in ptr-to-ptr format for compatibility with TrackMarkers
            
            print("Tracking ChArUco markers from image")
            
            // Track ChArUco markers: detect markers, show visualization, and save data on user prompt
            DispatchQueue.main.sync(execute: {
                keyCode = TrackMarkers(&imgNameCpp,Int32(1),&boardPathsCpp,Int32(boards.count),&calibDataPtr)
            })
            
            if( keyCode == -1 ) {
                print("ERROR: Something went wrong with call to TrackMarkers.")
                break;
            }
            
            print("\n\(i-startIndex+1) photos recorded.")
            i += 1
        }
        
        let outputTrackPath = "\(dirStruc.tracks)/intrinsics-track.json"
        print("Saving track to path \(outputTrackPath)")
        var outputTrackPathCString = *outputTrackPath
        SaveCalibDataToFile( &outputTrackPathCString, calibDataPtr[0] ); // write the data extracted by TrackMarkers to a file
        
        print("Photo capture ended. Exiting command \(tokens[0])")
        break
        
    case .takeextrinsics, .te:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        let (params, flags) = partitionTokens([String](tokens[1...]))
        // Make sure we have the right number of tokens
        guard params.count <= 1, flags.count <= 1 else {
            print(usage)
            break
        }
        
        // Get resolution
        let resolution: String
        if params.count == 1 {
            resolution = params[0]
        } else {
            resolution = defaultResolution
        }
        
        var mode: String = "default"; // Arbitrary initialization
        // Get optional flag
        if flags.count == 1 {
            mode = flags[0]
        }
//        
//        var appending = false
//        for flag in flags {
//            switch flag {
//            case "-a":
//                print("takeextrinsics: appending images.")
//                appending = true
//            default:
//                print("takeextrinsics: unrecognized flag \(flag).")
//            }
//        }
        
        if calibrationExposure != (0, 0) {
            let packet = CameraInstructionPacket(cameraInstruction: .SetExposure, photoBracketExposureDurations: [calibrationExposure.0], photoBracketExposureISOs: [calibrationExposure.1])
            cameraServiceBrowser.sendPacket(packet)
        }
        
        var posIDs: [Int]
        if( !emulateRobot ) {
            posIDs = Array(0..<nPositions)
        } else {
            print("Emulating robot motion. Proceeding with photo capture as though there were 3 robot positions.")
            posIDs = Array(0..<3)
        }
        captureNPosCalibration(posIDs: posIDs, resolution: resolution, mode: mode, live: true)
        print("Photo capture ended. Exiting command.")
        break
        
    case .trackexistingstereo:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        let (params, flags) = partitionTokens([String](tokens[1...]))
        // Make sure we have the right number of tokens
        guard params.count <= 1, flags.count <= 1 else {
            print(usage)
            break
        }
        var posIDs: [Int]
        if( !emulateRobot ) {
            posIDs = Array(0..<nPositions)
        } else {
            posIDs = Array(0..<3)
        }
        captureNPosCalibration(posIDs: posIDs, resolution: defaultResolution, mode: "default", live: false)
        
    // captures scene using structured lighting from specified projector
    case .struclight, .sl:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        let system: BinaryCodeSystem
        
        guard tokens.count >= 4 else {
            print(usage)
            break
        }
        
        var multiProj = false;
        var projIDs: [Int] = []
        let arg1 = tokens[1]
        if arg1.hasPrefix("[") { // if the string starts with [ assume we're being passed an array of strings
            multiProj = true
            projIDs = stringToIntArray(arg1)
        } else { // otherwise make sure we can conver the arg to an int
            guard let projPosID = Int(arg1) else {
                print(usage)
                break
            }
            projIDs.append(projPosID)
            print("projPosID: \(projPosID)")
        }
        
        var projNums: [Int] = []
        let arg2 = tokens[2]
        if arg2.hasPrefix("[") { // if the string starts with [ assume we're being passed an array of strings
            if(!multiProj) { // make sure projPosID was also passed an array
                print(usage)
                break
            }
            projNums = stringToIntArray(arg2)
        } else { // otherwise make sure we can conver the arg to an int
            guard let projNum = Int(tokens[2]) else {
                print(usage)
                break
            }
            projNums.append(projNum)
            print("projNum: \(projNum)")
        }
        
        var multiPos = false
        var poses: [Int] = []
        let arg3 = tokens[3]
        if arg3.hasPrefix("[") { // if the string starts with [ assume we're being passed an array of strings
            multiPos = true
            let poses_ = stringToIntArray(arg3)
            for pos in poses_ {
                if pos < 0 || pos >= nPositions {
                    print("pos \(pos) is not a valid robot position; not including it in poses array.")
                } else {
                    poses.append(pos)
                }
            }
        } else if arg3.contains("-a") { // otherwise just use all positiosn
            poses = Array(0..<nPositions)
        } else { // otherwise make sure we can conver the arg to an int
            guard let pos = Int(tokens[3]) else {
                print(usage)
                break
            }
            if pos < 0 || pos >= nPositions {
                print("pos \(pos) is not a valid robot position.")
                break
            }
            poses.append(pos)
        }
        
        // make sure we have at least one proj in array & both arrays are of the same length
        if(multiProj) {
            if(projIDs.count < 1) {
                print(usage)
                break
            }
            if( projNums.count != projIDs.count ) {
                print("projector position id array count must be the same as projector number array count")
                print(usage)
                break
            }
        }
        
        print("projIDs: \(projIDs)")
        print("projNums: \(projNums)")
        print("poses: \(poses)")

        system = .MinStripeWidthCode
        
        let resolution: String
        if tokens.count == 5 {
            resolution = tokens[3]
        } else {
            resolution = defaultResolution
        }
        
        struclightloop: for i in 0..<projIDs.count {
            displayController.switcher?.turnOff(0)   // turns off all projs
            print("Hit enter when all projectors off.")
            _ = readLine()  // wait until user hits enter
            displayController.switcher?.turnOn(projNums[i])
            print("Hit enter when selected projector ready.") // Turn on the selected projector
            _ = readLine()  // wait until user hits enter
            
            for pos in poses {
                // Tell the Rosvita server to move the arm to the selected position
                if( !emulateRobot ) {
                    var posStr = *String(pos) // get cchar version of pose string
                    if(GotoView(&posStr) < 0) {
                        print("ROBOT ERROR: problem moving to start position")
                        break struclightloop
                    }
                } else {
                    print("program is in emulateRobot mode. skipping robot motion")
                }
                captureWithStructuredLighting(system: system, projector: projIDs[i], position: pos, resolution: resolution)
            }
        }
        break
        
    /* take ambient images from all positions at all exposures
       flags: -t: use torch mode
              -f: use flash mode
              -a: append to existing photos
              -d: delete ALL contents of the ambient/photos directory
        if neither -a nor -d is given, photos will be written to IMG0.JPG, overwriting any previous file with the same name */
    case .takeamb, .ta:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        let (params, flags) = partitionTokens([String](tokens[1...]))
        
        guard params.count >= 1 else {
            print(usage)
            break
        }
        
        switch params[0] {
        case "still":
            let resolution: String
            if params.count == 2 {
                resolution = params[1]
            } else {
                resolution = defaultResolution
            }
            
            // set torch, flash mode, and determine whether we're appending photos to existing ones based on flags
            var mode = "normal"
            var flashMode = AVCaptureDevice.FlashMode.off
            var torchMode = AVCaptureDevice.TorchMode.off
            var appending = false
            var ball = false
            for flag in flags {
                switch flag {
                case "-f":
                    print("using flash mode...")
                    flashMode = .on
                    mode = "flash"
                case "-t":
                    print("using torch mode...")
                    mode = "torch"
                    torchMode = .on
                // save photos to ambientBall instead of ambient. used for taking ambients with a ball
                case "-b":
                    print("taking ambients with mirror ball...")
                    ball = true
                // create a new directory with a higher index. used for taking photos under different lighting conditions
                case "-a":
                    print("appending another ambient image directory...")
                    appending = true
                // delete all contents of ambient or ambientBall. note that the -b must precede the -d to successfully delete ambientBall instead of ambient
                case "-d":
                    print("deleting all ambient photos...")
                    // delete ALL contents of the ambient/photos directory
                    let photoDirectoryContents: [String] = (try! FileManager.default.contentsOfDirectory(atPath: dirStruc.ambientPhotos(ball))).map {
                        return "\(dirStruc.ambientPhotos(ball))/\($0)"
                    }
                    for item in photoDirectoryContents {
                        do { try FileManager.default.removeItem(atPath: item) }
                        catch { print("could not remove \(item)") }
                    }
                default:
                    print("flag \(flag) not recognized.")
                }
            }
            
            // make the camera intruction packet
            let packet = CameraInstructionPacket(cameraInstruction: .CapturePhotoBracket, resolution: resolution, photoBracketExposureDurations: sceneSettings.ambientExposureDurations, torchMode: torchMode, flashMode: flashMode, photoBracketExposureISOs: sceneSettings.ambientExposureISOs)
            
            let startIndex = dirStruc.getAmbientDirectoryStartIndex(appending: appending, photo: true, ball: ball, mode: mode)
            
            // Move the robot to the correct position and prompt photo capture
            for pos in 0..<nPositions {
                if ( !emulateRobot ) {
                    var posStr = *String(pos) // get cchar version of pos string
                    if(GotoView(&posStr) < 0) {
                        print("ROBOT ERROR: problem moving to start position")
                        break
                    }
                } else {
                    print("program is in emulateRobot mode. skipping robot motion")
                }
            
                // take photo bracket
                cameraServiceBrowser.sendPacket(packet)
                
                // set up image recievers for all exposures
                func receivePhotos() {
                    var nReceived = 0
                    let completionHandler = {
                        nReceived += 1
                    }
                    let numExps = (mode == "flash") ? (1) : (sceneSettings.ambientExposureDurations!.count)
                    for exp in 0..<numExps {
                        let path = (dirStruc.ambientPhotos(ball: ball, pos: pos, mode: mode, lighting: startIndex) + "/exp\(exp).JPG")
                        let ambReceiver = AmbientImageReceiver(completionHandler, path: path)
                        photoReceiver.dataReceivers.insertFirst(ambReceiver)
                    }
                    while nReceived != numExps {}
                }
                
                switch mode {
                case "torch":
                    let torchPacket = CameraInstructionPacket(cameraInstruction: .ConfigureTorchMode, torchMode: .on, torchLevel: torchModeLevel)
                    cameraServiceBrowser.sendPacket(torchPacket)
                    receivePhotos()
                    torchPacket.torchMode = .off
                    torchPacket.torchLevel = nil
                    cameraServiceBrowser.sendPacket(torchPacket)
                    break
                    
                default:
                    receivePhotos()
                }
            }
            break
            
        case "video":
            guard params.count >= 1, params.count <= 2 else {
                print(usage)
                break cmdSwitch
            }
            
            // get the right exposures to take video at
            var exps: [Int] = []
            if params.count == 1 {
                // if no exposure is explicitly given, assume we're looping through all exposures
                exps = Array(0..<min(sceneSettings.ambientExposureDurations?.count ?? -1, sceneSettings.ambientExposureISOs?.count ?? -1))
            } else {
                // if we're given an integer in the right range, assign the exposure of that index
                if let exp = Int(params[1]), exp >= 0, exp < min(sceneSettings.ambientExposureDurations?.count ?? -1, sceneSettings.ambientExposureISOs?.count ?? -1) {
                    exps.append(exp)
                } else if params[1] == "all" { // if we're given string "all", use all exposures
                    exps = Array(0..<min(sceneSettings.ambientExposureDurations?.count ?? -1, sceneSettings.ambientExposureISOs?.count ?? -1))
                } else { // otherwise give a message and break
                    print("invalid exposure number \(params[1])")
                    break cmdSwitch
                }
            }
            
            var torchMode: AVCaptureDevice.TorchMode = .off
            var mode = "normal"
            var appending = false
            var humanMotion = false
            for flag in flags {
                switch flag {
                case "-t":
                    print("using torch mode...")
                    torchMode = .on
                    mode = "torch"
                    break
                case "-a":
                    print("appending a new video directory...")
                    appending = true
                    break
                case "-h":
                    print("using realistic VIVE recorded trajectory...")
                    humanMotion = true
                    break
                default:
                    print("flag \(flag) not recognized.")
                }
            }
            
            // get the right lighting to write to
            let startIndex = dirStruc.getAmbientDirectoryStartIndex(appending: appending, photo: false, ball: false, mode: mode, humanMotion: humanMotion)
            
            // capture video at all selected exposures
            for exp in exps {
                print("\ntaking video at exposure \(exp)")
                
                // go to the start position
                if( !emulateRobot ) {
                    if (GotoVideoStart() == 0) {
                        print("robot moved to video start position.")
                    } else {
                        print("ROBOT ERROR: problem moving to start position")
                        break
                    }
                } else {
                    print("program is in emulateRobot mode. skipping robot motion")
                }
                
                print("starting to record")
                
                var packet = CameraInstructionPacket(cameraInstruction: .StartVideoCapture, photoBracketExposureDurations: [sceneSettings.ambientExposureDurations![exp]], torchMode: torchMode, photoBracketExposureISOs: [sceneSettings.ambientExposureISOs![exp]])
                cameraServiceBrowser.sendPacket(packet)
                
                // configure video data receiver
                var videoReceiver: AmbientVideoReceiver
                var imuReceiver: IMUDataReceiver
                var videoReceived: Bool = false
                var imuReceived: Bool = false
                
                videoReceiver = AmbientVideoReceiver({
                    videoReceived = true
                }, path: "\(dirStruc.ambientVideos(mode: mode, lighting: startIndex, humanMotion: humanMotion))/exp\(exp)video.mp4")
                photoReceiver.dataReceivers.insertFirst(videoReceiver)
                imuReceiver = IMUDataReceiver({
                    imuReceived = true
                }, path: "\(dirStruc.ambientVideos(mode: mode, lighting: startIndex, humanMotion: humanMotion))/exp\(exp)imu.yml")
                photoReceiver.dataReceivers.insertFirst(imuReceiver)
                
                // Tell the Rosvita server to move the robot smoothly through its whole trajectory
                if( !emulateRobot ) {
                    if( !humanMotion && ExecutePath(0.05, 0.7) == 0 ) { // velocities hard-coded, should be programmatically set prob from sceneSettings file
                        print("path completed. stopping recording.")
                    } else if( ExecuteHumanPath() == 0 ) {
                        print("path completed. stopping recording.")
                    } else {
                        print("ERROR: Problem executing path.")
                        break
                    }
                } else {
                    print("Program is in emulateRobot mode. Skipping robot motion")
                    print("Hit enter when ready to take video.")
                    _ = readLine()
                }
                
                packet = CameraInstructionPacket(cameraInstruction: .EndVideoCapture)
                cameraServiceBrowser.sendPacket(packet)
                
                // wait to receive video and imu as the network connection can get clogged
                while (!videoReceived) {}
                while (!imuReceived) {}
            }
            break
        default:
            break
        }
        break
        
        
    /*=====================================================================================
    MARK: control
    ======================================================================================*/
    // requests current lens position from iPhone camera, prints it
    case .readfocus, .rf:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        let packet = CameraInstructionPacket(cameraInstruction: .GetLensPosition)
        cameraServiceBrowser.sendPacket(packet)
        
        photoReceiver.dataReceivers.insertFirst(
            LensPositionReceiver { (pos: Float) in
                print("Lens position: \(pos)")
            }
        )
        
    // locks the focus and writes it to the sceneSettings file so it gets set whenever the app is booted up
    case .keepfocus:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        // lock the focus
        let pos = lockLensPosition()
        print("Locked lens position to \(pos)")
        
        //save the focus to the sceneSettings files
        do {
            sceneSettings = try SceneSettings(dirStruc.sceneSettingsFile)
            print("float: \(Float(pos))")
            print("double: \(Double(Float(pos)))")
            sceneSettings.set( key: "focus", value: Yaml.double(Double(Float(pos))) )
            sceneSettings.save()
            print("Saved lens position \(pos) to scene settings")
        } catch let error {
            print(error.localizedDescription)
        }
        
    // tells the iPhone to use the 'auto focus' focus mode
    case .autofocus:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        _ = setLensPosition(-1.0)
        
    // tells the iPhone to lock the focus at the current position
    case .lockfocus:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        let pos = lockLensPosition()
        print("Locked lens position to \(pos)")
        
    // tells the iPhone to set the focus to the given lens position & lock the focus
    case .setfocus:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        guard nextToken < tokens.count else {
            print(usage)
            break
        }
        guard let pos = Float(tokens[nextToken]) else {
            print("ERROR: Could not parse float value for lens position.")
            break
        }
        print("pos: \(pos)")
        _ = setLensPosition(pos)
        
        // autofocus on point, given in normalized x and y coordinates
    // NOTE: top left corner of image frame when iPhone is held in landscape with home button on the right corresponds to (0.0, 0.0).
    case .focuspoint:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        // arguments: x coord then y coord (0.0 <= 1.0, 0.0 <= 1.0)
        guard tokens.count >= 3 else {
            //            print("usage: focuspoint [x_coord] [y_coord]")
            print(usage)
            break
        }
        guard let x = Float(tokens[1]), let y = Float(tokens[2]) else {
            print("invalid x or y coordinate: must be on interval [0.0, 1.0]")
            break
        }
        let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
        let packet = CameraInstructionPacket(cameraInstruction: .SetPointOfFocus, pointOfFocus: point)
        cameraServiceBrowser.sendPacket(packet)
        _ = photoReceiver.receiveLensPositionSync()
        break
        
    // tells iphone to send current exposure duration & ISO
    case .readexposure:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        let packet = CameraInstructionPacket(cameraInstruction: .ReadExposure)
        cameraServiceBrowser.sendPacket(packet)
        let completionHandler = { (exposure: (Double, Float)) -> Void in
            print("exposure duration = \(exposure.0), iso = \(exposure.1)")
        }
        photoReceiver.dataReceivers.insertFirst(ExposureReceiver(completionHandler))
        
    // tells iPhone to use auto exposure mode (automatically adjusts exposure)
    case .autoexposure:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        let packet = CameraInstructionPacket(cameraInstruction: .AutoExposure)
        cameraServiceBrowser.sendPacket(packet)
        
        // tells iPhone to use locked exposure mode (does not change exposure settings, even when lighting changes)
    case .lockexposure:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        let packet = CameraInstructionPacket(cameraInstruction: .LockExposure)
        cameraServiceBrowser.sendPacket(packet)
        
    case .setexposure:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        guard tokens.count == 3 else {
            print(usage)
            break
        }
        guard let exposureDuration = Double(tokens[1]), let exposureISO = Float(tokens[2]) else {
            print("setexposure: invalid parameters \(tokens[1]), \(tokens[2])")
            break
        }
        let packet = CameraInstructionPacket(cameraInstruction: .SetExposure, photoBracketExposureDurations: [exposureDuration], photoBracketExposureISOs: [Double(exposureISO)])
        cameraServiceBrowser.sendPacket(packet)
        
        // displays checkerboard pattern
    // optional parameter: side length of squares, in pixels
    case .cb:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        //        let usage = "usage: cb [squareSize]?"
        let size: Int
        guard tokens.count >= 1 && tokens.count <= 2 else {
            print(usage)
            break
        }
        if tokens.count == 2 {
            size = Int(tokens[nextToken]) ?? 2
        } else {
            size = 2
        }
        displayController.currentWindow?.displayCheckerboard(squareSize: size)
        break
        
    // paints entire window black
    case .black:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        displayController.currentWindow?.displayBlack()
        break
        
    // paints entire window white
    case .white:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        displayController.currentWindow?.displayWhite()
        break
        
        // displays diagonal stripes (at 45°) of specified width (measured horizontally)
    // (tool for testing pico projector and its diagonal pixel grid)
    case .diagonal:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        guard tokens.count == 2, let stripeWidth = Int(tokens[1]) else {
            print(usage)
            break
        }
        displayController.currentWindow?.displayDiagonal(width: stripeWidth)
        break
        
        // displays vertical bars of specified width
    // (tool originaly made for testing pico projector)
    case .verticalbars:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        guard tokens.count == 2, let stripeWidth = Int(tokens[1]) else {
            print(usage)
            break
        }
        displayController.currentWindow?.displayVertical(width: stripeWidth)
        break
        
    // Select the appropriate robot arm path for the Rosvita server to load
    case .loadpath:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        guard tokens.count == 2 else {
            print(usage)
            break
        }

        let path: String = tokens[1] // the first argument should specify a pathname
        // Load a path from the robot server
        print("Attempting to load path \(path) from Rosvita server...")
        loadPathFromRobotServer(path: path, emulate: emulateRobot)
        break
        
    // moves robot arm to specified position ID by communicating with Rosvita server
    case .movearm:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        switch tokens.count {
        case 2:
            if let posInt = Int(tokens[1]) {
                if( posInt >= 0 && posInt < nPositions ) {
                    print("Moving arm to position \(posInt)")
                    DispatchQueue.main.async {
                        // Tell the Rosvita server to move the arm to the selected position
                        if (!emulateRobot) {
                            var posStr = *String(posInt)
                            if(GotoView(&posStr) < 0) {
                                print("ROBOT ERROR: problem moving to start position")
                            }
                        }
                    }
                } else if (!(posInt >= 0)) {
                    print("Please enter a positive number.")
                } else {
                    print("\(posInt) is not a position ID. There are only \(nPositions) in the path currently loaded.")
                }
            } else {
                print("\(tokens[1]) is not a valid position ID string.")
            }
        default:
            print(usage)
            break
        }
        break
        
    // Set robot arm velocity. Expects a float from 0 to 1. Note that higher velocities correspond to less repetition (eg precision) in positions.
    case .setvelocity:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        switch tokens.count {
        case 2:
            if let vFloat = Float(tokens[1]) {
                if( vFloat >= 0.0 && vFloat <= 1.0 ) {
                    print("Setting velocity to \(vFloat)")
                    DispatchQueue.main.async {
                        // Tell the Rosvita server to set the velocity to the specified Float
                        SetVelocity(vFloat)
                    }
                } else {
                    print("Please enter a Float between 0.0 and 1.0.")
                } 
            } else {
                print("\(tokens[1]) is not a valid Float.")
            }
        default:
            print(usage)
            break
        }
        break
        
    // used to turn projectors on or off
    //  -argument 1: either projector # (1–8) or 'all', which addresses all of them at once
    //  -argument 2: either 'on', 'off', '1', or '0', where '1' turns the respective projector(s) on
    // NOTE: the Kramer switcher box must be connected (use 'connect switcher' command), of course
    case .proj, .p:
        if( processingMode ) {
            print("\(tokens[0]) cannot be run in processing mode.")
            break
        }
        guard tokens.count == 3 else {
            print(usage)
            break
        }
        if let projector = Int(tokens[1]) {
            switch tokens[2] {
            case "on", "1":
                displayController.switcher?.turnOn(projector)
            case "off", "0":
                displayController.switcher?.turnOff(projector)
            default:
                print("Unrecognized argument: \(tokens[2])")
            }
        } else if tokens[1] == "all" {
            switch tokens[2] {
            case "on", "1":
                displayController.switcher?.turnOn(0)
            case "off", "0":
                displayController.switcher?.turnOff(0)
            default:
                print("Unrecognized argument: \(tokens[2])")
            }
        } else {
            print("Not a valid projector number: \(tokens[1])")
        }
        break
        
        
    /*=====================================================================================
    MARK: processing
    ======================================================================================*/
    // Runs all processing steps on given pairs and projectors
    case .processpairs, .pp:
        // check input format
        let (params, flags) = partitionTokens(tokens)
        let numAs = countAFlags(flags: flags)

        var allProj = false, allPosPairs = false
        if (numAs == 2 && params.count == 1) { // all projectors and position pairs
            allProj = true; allPosPairs = true
        } else if (numAs == 1 && params.count == 2) { // all position pairs, projectors specified
            allPosPairs = true
        } else if (numAs == 1 && params.count == 3) { // all projectors, position pairs specified
            allProj = true
        } else if !(numAs == 0 && params.count == 4) {
            print(usage)
            break
        }
        
        _ = getintrinsics()
        runGetExtrinsics(all: allPosPairs, params: params)
        runRectify(allProj: allProj, allPosPairs: allPosPairs, params: params)
        runRectifyAmb(allPosPairs: allPosPairs, params: params)
        runRefine(allProj: allProj, allPosPairs: allPosPairs, params: params)
        runDisparity(allProj: allProj, allPosPairs: allPosPairs, params: params)
        runMerge(allPosPairs: allPosPairs, params: params)
        runReproject(allPosPairs: allPosPairs, params: params)
        runMerge2(allPosPairs: allPosPairs, params: params)
        
        break
        
    // do intrinsics calibration
    case .getintrinsics, .gi:
        guard tokens.count == 1 else {
            print(usage)
            break
        }
        _ = getintrinsics()
        break
        
    // do stereo calibration
    case .getextrinsics, .ge:
        // check input format
        let (params, flags) = partitionTokens(tokens)
        let numAs = countAFlags(flags: flags)
        
        if !((numAs == 1 && params.count == 1) ||
            (numAs == 0 && params.count == 3)) {
            print(usage)
            break
        }
        
        // determine targets
        let all = (numAs == 1) ? true : false
        
        runGetExtrinsics(all: all, params: params)
    
    case .rectify, .rect:
        // check input format
        let (params, flags) = partitionTokens(tokens)
        let numAs = countAFlags(flags: flags)

        var allProj = false, allPosPairs = false
        if (numAs == 2 && params.count == 1) { // all projectors and position pairs
            allProj = true; allPosPairs = true
        } else if (numAs == 1 && params.count == 2) { // all position pairs, projectors specified
            allPosPairs = true
        } else if (numAs == 1 && params.count == 3) { // all projectors, position pairs specified
            allProj = true
        } else if !(numAs == 0 && params.count == 4) {
            print(usage)
            break
        }
        
        runRectify(allProj: allProj, allPosPairs: allPosPairs, params: params)
        
    // rectify ambient images of all positions and exposures
    case .rectifyamb, .ra:
        let (params, flags) = partitionTokens([String](tokens[1...]))
        let numAs = countAFlags(flags: flags)
        if !((numAs == 1 && params.count == 0) ||
            (numAs == 0 && params.count == 2)) {
            print(usage)
            break
        }
        let allPosPairs = (numAs == 1) ? true : false
        
        runRectifyAmb(allPosPairs: allPosPairs, params: params)
        
        // refines decoded PFM image with given name (assumed to be located in the decoded subdirectory)
        //  and saves intermediate and final results to refined subdirectory
        //    -direction argument specifies which axis to refine in, where 0 <-> x-axis
        // TO-DO: this does not take advantage of the ideal direction calculations performed at the new smart
    //  thresholding step
    case .refine, .ref:
        // check input format
        let (params, flags) = partitionTokens(tokens)
        let numAs = countAFlags(flags: flags)

        var allProj = false, allPosPairs = false
        if (numAs == 2 && params.count == 1) { // all projectors and position pairs
            allProj = true; allPosPairs = true
        } else if (numAs == 1 && params.count == 2) { // all position pairs, projectors specified
            allPosPairs = true
        } else if (numAs == 1 && params.count == 3) { // all projectors, position pairs specified
            allProj = true
        } else if !(numAs == 0 && params.count == 4) {
            print(usage)
            break
        }
        
        runRefine(allProj: allProj, allPosPairs: allPosPairs, params: params)
        
        
        // computes disparity maps from decoded & refined images; saves them to 'disparity' directories
        // usage options:
        //  -'disparity': computes disparities for all projectors & all consecutive positions
        //  -'disparity [projector #]': computes disparities for given projectors for all consecutive positions
    //  -'disparity [projector #] [leftPos] [rightPos]': computes disparity map for single viewpoint pair for specified projector
    case .disparity, .d:
        // check input format
        let (params, flags) = partitionTokens(tokens)
        let numAs = countAFlags(flags: flags)

        var allProj = false, allPosPairs = false
        if (numAs == 2 && params.count == 1) { // all projectors and position pairs
            allProj = true; allPosPairs = true
        } else if (numAs == 1 && params.count == 2) { // all position pairs, projectors specified
            allPosPairs = true
        } else if (numAs == 1 && params.count == 3) { // all projectors, position pairs specified
            allProj = true
        } else if !(numAs == 0 && params.count == 4) {
            print(usage)
            break
        }
        
        runDisparity(allProj: allProj, allPosPairs: allPosPairs, params: params)
        
    case .merge, .m:
        // check input format
        let (params, flags) = partitionTokens(tokens)
        let numAs = countAFlags(flags: flags)

        var allPosPairs = false
        if (numAs == 1 && params.count == 1) { // all projectors and position pairs
            allPosPairs = true
        } else if !(numAs == 0 && params.count == 3) {
            print(usage)
            break
        }
        
        runMerge(allPosPairs: allPosPairs, params: params)
        
    case .reproject, .rp:
        // check input format
        let (params, flags) = partitionTokens(tokens)
        let numAs = countAFlags(flags: flags)

        var allPosPairs = false
        if (numAs == 1 && params.count == 1) { // all projectors and position pairs
            allPosPairs = true
        } else if !(numAs == 0 && params.count == 3) {
            print(usage)
            break
        }
        
        runReproject(allPosPairs: allPosPairs, params: params)
        
    case .merge2, .m2:
        // check input format
        let (params, flags) = partitionTokens(tokens)
        let numAs = countAFlags(flags: flags)

        var allPosPairs = false
        if (numAs == 1 && params.count == 1) { // all projectors and position pairs
            allPosPairs = true
        } else if !(numAs == 0 && params.count == 3) {
            print(usage)
            break
        }
        
        runMerge2(allPosPairs: allPosPairs, params: params)
        
        
    /*=====================================================================================
     MARK: debugging
     ======================================================================================*/

    // creates png files meshing images from different projectors to help determine projector placement
    case .showshadows, .ss:
        guard tokens.count >= 1 && tokens.count <= 3 else {
            print(usage)
            break
        }
        
        // later insert functionality to not automatically use all projectors & positions
        let allproj = true
        var projs: [Int] = []
        if allproj {
            let projDirs = try! FileManager.default.contentsOfDirectory(atPath: dirStruc.decoded(false))
            projs = getIDs(projDirs, prefix: "proj", suffix: "")
        }
        
        var projectors: [Int32] = []
        // convert Ints to Int32s
        for proj in projs {
            projectors.append(Int32(proj))
        }
        
        var allpos = true
        // loop through all positions
        for i in 0..<nPositions {
            showShadows(projs: projectors, pos: Int32(i))
        }
        
    // currently just transforms all decoded images
    case .transform:
        guard tokens.count >= 1 && tokens.count <= 3 else {
            print(usage)
            break
        }
        
        var mode: String
        if (tokens[1] == "rotate90cw") {
            print("rotating images 90 degrees CW...")
            mode = "rotate90cw"
        } else if (tokens[1] == "flipY") {
            print("flipping images over y axis...")
            mode = "flipY"
        } else {
            print("transformation \(tokens[0]) unrecognized")
            break
        }
        
        // later insert functionality to transform image by image
        var allimg = true
        var projs: [Int] = []
        let projDirs = try! FileManager.default.contentsOfDirectory(atPath: dirStruc.decoded(false))
        projs = getIDs(projDirs, prefix: "proj", suffix: "")
        
        transLoop: for rect in 0...1 {
            for proj in projs {
                for pos in 0..<nPositions {
                    let rectified = (rect == 0) ? false : true
                    let decodedUrl = URL(string: dirStruc.decoded(proj: proj, pos: pos, rectified: rectified))
                    var fileURLs: [URL]
                    do {
                        try fileURLs = FileManager.default.contentsOfDirectory(at: decodedUrl!, includingPropertiesForKeys: nil)
                    } catch let err {
                        print(err.localizedDescription)
                        break transLoop
                    }
                    for fileURL in fileURLs {
                        var path: [CChar]
                        do {
                            print(fileURL.path)
                            try path = safePath("\(fileURL.path)")
                        } catch let err {
                            print(err.localizedDescription)
                            break transLoop
                        }
                        var transform: [CChar] = *mode
                        transformPfm(&path, &transform)
                    }
                }
            }
        }
        
        
        
        // displays current resolution being used for external display
    // -useful for troubleshooting with projector display issues
    case .dispres:
        let screen = displayController.currentWindow!
        print("Screen resolution: \(screen.width)x\(screen.height)")
        
        // displays a min stripe width binary code pattern
    //  useful for verifying the minSW.dat file loaded properly
    case .dispcode:
        displayController.currentWindow!.displayBinaryCode(forBit: 0, system: .MinStripeWidthCode)
    
    // toggle debug. Note that this will not affect what path has been loaded on the Rosvita server. 
    case .toggledebug:
        emulateRobot = !emulateRobot
        
        
    // scripting
    case .sleep:
        guard tokens.count == 2 else {
            print(usage)
            break
        }
        guard let secs = Double(tokens[1]) else {
            print("sleep: \(tokens[1]) not a valid number of seconds.")
            break
        }
        usleep(UInt32(secs * 1000000))
        
    case .clearpackets:
        photoReceiver.dataReceivers.removeAll()
        
    }
    return true
}


/* The following extension could be implemented to suggest similar commands on unrecognized input,
 but is buggy:
 extension Command {
 init(closeTo unknown: String) {
 if let known = Command(rawValue: unknown) {
 self = known
 } else {
 // if command unrecognized, find closest match
 var cases: [String] = Command.cases().map { return $0.rawValue }
 // now D.P. solution
 let costs: [Int] = cases.map { (command: String) in
 var cache = [[Int]](repeating: [Int](repeating: 0, count: command.count+1), count: unknown.count+1)
 var runs = [[Int]](repeating: [Int](repeating:0, count: command.count+1), count: unknown.count+1)
 for i in 0..<command.count+1 {
 cache[0][i] = i
 }
 for j in 0..<unknown.count+1 {
 cache[j][0] = j
 }
 for j in 1..<unknown.count+1 {
 for i in 1..<command.count+1 {
 let cost = min(min(cache[j][i-1] + 1, cache[j-1][i] + 1), cache[j-1][i-1] + ((command[i-1] == unknown[j-1]) ? -runs[j-1][i-1] : 1) )
 cache[j][i] = cost
 switch cost {
 case cache[j][i-1] + 1:
 // zero out run
 runs[j][i] = 0
 case cache[j-1][i] + 1:
 // zero out run
 runs[j][i] = 0
 case cache[j-1][i-1] - runs[j-1][i-1]:
 // increase run
 runs[j][i] = runs[j-1][i-1] + 1
 case cache[j-1][i-1] + 1:
 runs[j][i] = 0
 default:
 // impossible
 break
 }
 //                        print("\(cost) ", separator: " ", terminator: "")
 }
 }
 return cache[unknown.count][command.count]
 }
 let mincost = costs.min() ?? 0
 let bestMatch = cases[costs.index(of: mincost)!]
 self = Command(rawValue: bestMatch)!
 }
 }
 }
 */
