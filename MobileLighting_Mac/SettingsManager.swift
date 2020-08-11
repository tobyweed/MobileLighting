//
// SettingsManager.swift
// MobileLighting_Mac
//
// Insert description
//

import Foundation
import Yaml

// simple error enum for when trying to read YML settings files
enum YamlError: Error {
    case InvalidFormat
    case MissingRequiredKey
}

//MARK: SETTINGS CLASSES

// InitSettings: represents all settings required for capturing a new scene
// read from YML file
// -consists of required and optional settings
class SceneSettings {
    var yml: Yaml
    var filepath: String
    
    var scenesDirectory: String
    var sceneName: String
    var minSWfilepath: String
    var robotPathName: String
    var yDisparityThreshold: Double
    
    // structured lighting
    var strucExposureDurations: [Double]
    var strucExposureISOs: [Double]
    
    // calibration
    var focus: Double?
    var calibrationExposureDuration: Double?
    var calibrationExposureISO: Double?
    
    // ambient
    var ambientExposureDurations: [Double]?
    var ambientExposureISOs: [Double]?
    
    static var format: Yaml {
        get {
            var maindict = [Yaml : Yaml]()
            maindict[Yaml.string("scenesDir")] = Yaml.string("(value uninitialized)")
            maindict[Yaml.string("sceneName")] = Yaml.string("(value uninitialized)")
            maindict[Yaml.string("minSWdataPath")] = Yaml.string("(value uninitialized)")
            maindict[Yaml.string("robotPathName")] = Yaml.string("(value uninitialized)")
            maindict[Yaml.string("yDisparityThreshold")] = Yaml.double(5.0)
            var struclight = [Yaml : Yaml]()
            struclight[Yaml.string("exposureDurations")] = Yaml.array([0.01,0.03,0.10].map{return Yaml.double($0)})
            struclight[Yaml.string("exposureISOs")] = Yaml.array([50.0,150.0,500.0].map{ return Yaml.double($0)})
            maindict[Yaml.string("struclight")] = Yaml.dictionary(struclight)
            maindict[Yaml.string("focus")] = Yaml.double(0.0)
            var calibration = [Yaml : Yaml]()
            calibration[Yaml.string("exposureDuration")] = Yaml.double(0.075)
            calibration[Yaml.string("exposureISO")] = Yaml.double(66.5)
            maindict[Yaml.string("calibration")] = Yaml.dictionary(calibration)
            var ambient = [Yaml : Yaml]()
            ambient[Yaml.string("exposureDurations")] = Yaml.array([0.01,0.03,0.1].map{return Yaml.double($0)})
            ambient[Yaml.string("exposureISOs")] = Yaml.array([50.0,50.0,50.0].map{ return Yaml.double($0)})
            maindict[Yaml.string("ambient")] = Yaml.dictionary(ambient)
            return Yaml.dictionary([Yaml.string("Settings") : Yaml.dictionary(maindict)])
        }
    }
    
    // Load a SceneSettings dictionary for manipulation from a preexisting Yaml file
    init(_ path: String) throws {
        self.filepath = path
        
        // Load and read the preexisting yaml file
        let ymlStr = try String(contentsOfFile: self.filepath)
        let tmp = try Yaml.load(ymlStr)
        guard let dict = tmp.dictionary else {
            throw YamlError.InvalidFormat
        }
        guard dict[Yaml.string("Settings")] != nil else {
            throw YamlError.MissingRequiredKey
        }
        self.yml = dict[Yaml.string("Settings")]!
        guard let mainDict = dict[Yaml.string("Settings")]!.dictionary else {
            throw YamlError.InvalidFormat
        }
        
        // process required properties:
        guard let scenesDirectory = mainDict[Yaml.string("scenesDir")]?.string,
            let sceneName = mainDict[Yaml.string("sceneName")]?.string,
            let minSWfilepath = mainDict[Yaml.string("minSWdataPath")]?.string,
            let robotPathName = mainDict[Yaml.string("robotPathName")]?.string,
            let yDisparityThreshold = mainDict[Yaml.string("yDisparityThreshold")]?.double else {
                throw YamlError.MissingRequiredKey
        }
        
        self.scenesDirectory = scenesDirectory
        self.sceneName = sceneName
        self.minSWfilepath = minSWfilepath
        self.robotPathName = robotPathName
        self.yDisparityThreshold = yDisparityThreshold
        
        self.strucExposureDurations = (mainDict[Yaml.string("struclight")]?.dictionary?[Yaml.string("exposureDurations")]?.array?.filter({return $0.double != nil}).map{
            (val: Yaml) -> Double in
            return val.double!
            })!
        self.strucExposureISOs = (mainDict[Yaml.string("struclight")]?.dictionary?[Yaml.string("exposureISOs")]?.array?.filter({return $0.double != nil}).map{
            (val: Yaml) -> Double in
            return val.double!
            })!
        self.focus = mainDict[Yaml.string("focus")]?.double
        
        if let calibrationDict = mainDict[Yaml.string("calibration")]?.dictionary {
            if let iso = calibrationDict[Yaml.string("exposureISO")]?.double {
                self.calibrationExposureISO = iso
            }
            if let duration = calibrationDict[Yaml.string("exposureDuration")]?.double {
                self.calibrationExposureDuration = duration
            }
        }
            
        if let ambientDict = mainDict[Yaml.string("ambient")] {
            self.ambientExposureISOs = ambientDict[Yaml.string("exposureISOs")].array?.compactMap {
                return $0.double
            }
            self.ambientExposureDurations = ambientDict[Yaml.string("exposureDurations")].array?.compactMap {
                return $0.double
            }
        }

        guard self.strucExposureDurations.count == self.strucExposureISOs.count else {
            fatalError("invalid initsettings file: mismatch in number of exposure durations & ISOs.")
        }
    }
    
    // return all property names as an array of Strings
    func properties()-> [(String,Any)] {
        let mirror = Mirror(reflecting: self)
        return mirror.children.compactMap{ ($0.label!, $0.value) }
    }

    // Set a value on the yaml settings dictionary
    func set(key: String, value: Yaml) {
        guard var dict = self.yml.dictionary else { return }
        dict[Yaml.string(key)] = value
        self.yml = Yaml.dictionary(dict)
    }
    
    // Set the yaml settings dictionary
    func save(){
        try! Yaml.save(Yaml.dictionary([Yaml.string("Settings") : self.yml]), toFile: filepath)
    }
    
    // Generate a sceneSettings file in the appropriate directory with default values from SceneSettings.format
    static func create(_ dirStruc: DirectoryStructure) throws {
        let path = "\(dirStruc.settings)/sceneSettings.yml"
        let dir = ((path.first == "/") ? "/" : "") + path.split(separator: "/").dropLast().joined(separator: "/")
        do {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            let yml = try SceneSettings.format.save()
            try yml.write(toFile: path, atomically: true, encoding: .ascii)
        } catch let error {
            print(error.localizedDescription)
        }
    }
}


class Board {
    let filepath: String
    var yml: Yaml
    
    // Strings representing the supported predefined ChArUco dictionaries
    enum BoardDict: String {
        case DICT_4x4
        case DICT_5x5
        case DICT_6x6
    }
    
    var Description: String?
    var SquaresX: Int
    var SquaresY: Int
    var SquareSizeMM: Double
    var MarkerSizeMM: Double
    var BoardWidthMM: Double
    var BoardHeightMM: Double
    var Dict: BoardDict
    var StartCode: Int
    
    init(_ path: String) throws {
        self.filepath = path
        // Load and read the preexisting yaml file
        let ymlStr = try String(contentsOfFile: self.filepath)
        let tmp = try Yaml.load(ymlStr)
        guard let dict = tmp.dictionary else {
            throw YamlError.InvalidFormat
        }
        guard dict[Yaml.string("Board")] != nil else {
            throw YamlError.MissingRequiredKey
        }
        self.yml = dict[Yaml.string("Board")]!
        guard let mainDict = dict[Yaml.string("Board")]!.dictionary else {
            throw YamlError.InvalidFormat
        }
        
        // process required properties:
        guard let SquaresX = mainDict[Yaml.string("squares_x")]?.int,
            let SquaresY = mainDict[Yaml.string("squares_y")]?.int,
            let SquareSizeMM = mainDict[Yaml.string("square_size_mm")]?.double,
            let MarkerSizeMM = mainDict[Yaml.string("marker_size_mm")]?.double,
            let BoardWidthMM = mainDict[Yaml.string("board_width_mm")]?.double,
            let BoardHeightMM = mainDict[Yaml.string("board_height_mm")]?.double,
            let Dict = mainDict[Yaml.string("dict")]?.string,
            let StartCode = mainDict[Yaml.string("start_code")]?.int else {
                throw YamlError.MissingRequiredKey
        }
        
        self.SquaresX = SquaresX
        self.SquaresY = SquaresY
        self.SquareSizeMM = SquareSizeMM
        self.MarkerSizeMM = MarkerSizeMM
        self.BoardWidthMM = BoardWidthMM
        self.BoardHeightMM = BoardHeightMM
        self.Dict = BoardDict(rawValue: Dict) ?? BoardDict(rawValue: "DICT_5x5")!
        self.StartCode = StartCode
    }
    
    static var format: Yaml {
        get {
            var maindict = [Yaml : Yaml]()
            maindict[Yaml.string("description")] = Yaml.string("(value uninitialized)")
            maindict[Yaml.string("squares_x")] = Yaml.int(12)
            maindict[Yaml.string("squares_y")] = Yaml.int(9)
            maindict[Yaml.string("square_size_mm")] = Yaml.double(60)
            maindict[Yaml.string("marker_size_mm")] = Yaml.double(45)
            maindict[Yaml.string("board_width_mm")] = Yaml.double(800)
            maindict[Yaml.string("board_height_mm")] = Yaml.double(600)
            maindict[Yaml.string("dict")] = Yaml.string("DICT_5x5")
            maindict[Yaml.string("start_code")] = Yaml.int(300)
            return Yaml.dictionary([Yaml.string("Board") : Yaml.dictionary(maindict)])
        }
    }
    
    // return all property names as an array of Strings
    func properties()-> [(String,Any)] {
        let mirror = Mirror(reflecting: self)
        return mirror.children.compactMap{ ($0.label!, $0.value) }
    }
    
    // Set a value on the yaml settings dictionary
    func set(key: String, value: Yaml) {
        guard var dict = self.yml.dictionary else { return }
        dict[Yaml.string(key)] = value
        self.yml = Yaml.dictionary(dict)
    }
    
    // Set the yaml settings dictionary
    func save(){
        try! Yaml.save(Yaml.dictionary([Yaml.string("Board") : self.yml]), toFile: filepath)
    }
    
    // Generate a sceneSettings file in the appropriate directory with default values from SceneSettings.format
    static func create(_ dirStruc: DirectoryStructure) throws {
        let path = "\(dirStruc.boardsDir)/board0.yml"
        let dir = ((path.first == "/") ? "/" : "") + path.split(separator: "/").dropLast().joined(separator: "/")
        do {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            let yml = try Board.format.save()
            try yml.write(toFile: path, atomically: true, encoding: .ascii)
        } catch let error {
            print(error.localizedDescription)
        }
    }
}

// OLD
class CalibrationSettings {
    let filepath: String
    var yml: Yaml

    enum CalibrationMode: String {
        case INTRINSIC, STEREO, PREVIEW
    }
    enum CalibrationPattern: String {
        case CHESSBOARD, ARUCO_SINGLE
    }

    enum Key: String {
        case Mode, Calibration_Pattern, ChessboardSize_Width
        case ChessboardSize_Height
        case Num_MarkersX, Num_MarkersY
        case First_Marker
        case Num_of_Boards
        case ImageList_Filename
        case IntrinsicInput_Filename, IntrinsicOutput_Filename, ExtrinsicOutput_Filename
        case UndistortedImages_Path, RectifiedImages_Path
        case DetectedImages_Path, Calibrate_FixDistCoeffs
        case Calibrate_FixAspectRatio, Calibrate_AssumeZeroTangentialDistortion
        case Calibrate_FixPrincipalPointAtTheCenter
        case Show_UndistortedImages, ShowRectifiedImages
        case Wait_NextDetecedImage
    }

    init(_ path: String) {
        self.filepath = path
        do {
            let ymlStr = try String(contentsOfFile: self.filepath)
            let tmp = try Yaml.load(ymlStr)
            guard let dict = tmp.dictionary else {
                throw YamlError.InvalidFormat
            }
            guard dict[Yaml.string("Settings")] != nil else {
                throw YamlError.MissingRequiredKey
            }
            self.yml = dict[Yaml.string("Settings")]!
        } catch let error {
            print(error.localizedDescription)
            fatalError()
        }
    }

    // return all property names as an array of Strings
    func properties()-> [(String,Any)] {
        let mirror = Mirror(reflecting: self)
        return mirror.children.compactMap{ ($0.label!, $0.value) }
    }

    func set(key: Key, value: Yaml) {
        guard var dict = self.yml.dictionary else { return }
        dict[Yaml.string(key.rawValue)] = value
        self.yml = Yaml.dictionary(dict)
    }

    func get(key: Key) -> Yaml? {
        guard let dict = self.yml.dictionary else { return nil }
        return dict[Yaml.string(key.rawValue)]
    }

    func save() {
        try! Yaml.save(Yaml.dictionary([Yaml.string("Settings") : self.yml]), toFile: filepath)
    }

    static var format: Yaml {
        get {
            var settingsDict = [Yaml : Yaml]()
            settingsDict["Num_MarkersX"] = Yaml.array([8,7].map{return Yaml.int($0)})
            settingsDict["Num_MarkersY"] = Yaml.array([7,6].map{return Yaml.int($0)})
            settingsDict["Num_of_Boards"] = Yaml.int(2)
            settingsDict["ChessboardSize_Width"] = Yaml.int(17)
            settingsDict["ChessboardSize_Height"] = Yaml.int(12)
            settingsDict["Calibration_Pattern"] = Yaml.string("ARUCO_SINGLE")
            settingsDict["Calibrate_AssumeZeroTangentialDistortion"] = Yaml.int(1)
            settingsDict["ImageList_Filename"] = Yaml.string("(value uninitialized)")
            settingsDict["ExtrinsicOutput_Filename"] = Yaml.string("(value uninitialized)")
            settingsDict["Show_UndistortedImages"] = Yaml.int(0)
            settingsDict["Wait_NextDetectedImage"] = Yaml.int(0)
            settingsDict["IntrinsicInput_Filename"] = Yaml.string("(value uninitialized)")
            settingsDict["Calibrate_FixPrincipalPointAtTheCenter"] = Yaml.int(0)
            settingsDict["UndistortedImages_Path"] = Yaml.string("0")
            settingsDict["DetectedImages_Path"] = Yaml.string("0")
            settingsDict["Show_RectifiedImages"] = Yaml.int(1)
            settingsDict["Square size"] = Yaml.double(25.4)
            settingsDict["IntrinsicOutput_Filename"] = Yaml.string("(value uninitialized)")
            settingsDict["Dictionary"] = Yaml.int(11)
            settingsDict["Calibrate_FixAspectRatio"] = Yaml.int(0)
            settingsDict["RectifiedImages_Path"] = Yaml.string("0")
            settingsDict["Marker_Length"] = Yaml.array([108,144].map{return Yaml.double($0)})
            settingsDict["Calibrate_FixDistCoeffs"] = Yaml.string("00111")
            settingsDict["First_Marker"] = Yaml.array([516,614].map{return Yaml.int($0)})
            settingsDict["Mode"] = Yaml.string(CalibrationMode.STEREO.rawValue)
            settingsDict["Alpha_Parameter"] = Yaml.int(-1)
            settingsDict["Resizing_Factor"] = Yaml.int(1)
            let mainDict = Yaml.dictionary(settingsDict)
            return Yaml.dictionary([Yaml.string("Settings") : mainDict])
        }
    }

    static func create(_ dirStruc: DirectoryStructure) throws {
        let path = dirStruc.calibrationSettingsFile
        try Yaml.save(CalibrationSettings.format, toFile: path)
    }
}


func generateIntrinsicsImageList(imgsdir: String = dirStruc.intrinsicsPhotos, outpath: String = dirStruc.intrinsicsImageList) {
    guard var imgs = try? FileManager.default.contentsOfDirectory(atPath: imgsdir) else {
        print("could not read contents of directory \(imgsdir)")
        return
    }
    
    imgs = imgs.filter { (_ filepath: String) in
        guard let file = filepath.split(separator: "/").last else { return false }
        guard file.hasPrefix("IMG"), file.hasSuffix(".JPG"), Int(file.dropFirst("IMG".count).dropLast(".JPG".count)) != nil else {
            return false
        }
        return true
    }

    var imgList: [Yaml] = [Yaml]()
    for path in imgs {
        imgList.append(Yaml.string("\(imgsdir)/\(path)"))
    }
    let ymlList = Yaml.array(imgList)
    let ymlDict = Yaml.dictionary([Yaml.string("images") : ymlList])

    try! Yaml.save(ymlDict, toFile: outpath)
}

func generateStereoImageList(left ldir: String, right rdir: String, outpath: String = dirStruc.stereoImageList) {
    guard var limgs = try? FileManager.default.contentsOfDirectory(atPath: ldir), var rimgs = try? FileManager.default.contentsOfDirectory(atPath: rdir) else {
        print("could not read contents of directory \(ldir) or \(rdir)")
        return
    }
    
    let filterIms: (String) -> Bool = { (_ filepath: String) in
        let file = filepath.split(separator: "/").last!
        return (file.hasPrefix("IMG") || file.hasPrefix("img")) && (file.hasSuffix(".JPG") || file.hasSuffix(".jpg"))
    }
    limgs = limgs.filter(filterIms)
    rimgs = rimgs.filter(filterIms)
    let mapNames: (String) -> String = {(_ fullpath: String) in
        return String(fullpath.split(separator: "/").last!)
    }
    let lnames = limgs.map(mapNames)
    let rnames = rimgs.map(mapNames)
    let names = Set(lnames).intersection(rnames)
    var imgList = [Yaml]()
    for name in names {
        imgList.append(Yaml(stringLiteral: "\(ldir)/\(name)"))
        imgList.append(Yaml(stringLiteral: "\(rdir)/\(name)"))
    }
    let ymlList = Yaml.array(imgList)
    let ymlDict = Yaml(dictionaryLiteral: (Yaml(stringLiteral: "images"), ymlList))
    try! Yaml.save(ymlDict, toFile: outpath)
}
