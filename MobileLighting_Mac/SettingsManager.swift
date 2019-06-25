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
            var struclight = [Yaml : Yaml]()
            struclight[Yaml.string("exposureDurations")] = Yaml.array([0.01,0.03,0.10].map{return Yaml.double($0)})
            struclight[Yaml.string("exposureISOs")] = Yaml.array([50.0,150.0,500.0].map{ return Yaml.double($0)})
            maindict[Yaml.string("struclight")] = Yaml.dictionary(struclight)
            maindict[Yaml.string("focus")] = Yaml.double(0.0)
            var calibration = [Yaml : Yaml]()
            calibration[Yaml.string("exposureDuration")] = Yaml.double(0.055)
            calibration[Yaml.string("exposureISO")] = Yaml.double(66.5)
            maindict[Yaml.string("calibration")] = Yaml.dictionary(calibration)
            var ambient = [Yaml : Yaml]()
            ambient[Yaml.string("exposureDurations")] = Yaml.array([0.035,0.045,0.055].map{return Yaml.double($0)})
            ambient[Yaml.string("exposureISOs")] = Yaml.array([50.0,60.0,70.0].map{ return Yaml.double($0)})
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
            let robotPathName = mainDict[Yaml.string("robotPathName")]?.string else {
                throw YamlError.MissingRequiredKey
        }
        
        self.scenesDirectory = scenesDirectory
        self.sceneName = sceneName
        self.minSWfilepath = minSWfilepath
        self.robotPathName = robotPathName
        
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
    
    // Set a value on the yaml settings dictionary
    func set(key: String, value: Yaml) {
        guard var dict = self.yml.dictionary else { return }
        dict[Yaml.string(key)] = value
        self.yml = Yaml.dictionary(dict)
    }
    
    // Set the yaml settings dictionary
    func save() {
        try! Yaml.save(Yaml.dictionary([Yaml.string("Settings") : self.yml]), toFile: filepath)
    }
    
    // Generate a sceneSettings file in the appropriate directory with default values from SceneSettings.format
    static func create(_ dirStruc: DirectoryStructure) throws {
        let path = "\(dirStruc.settings)/sceneSettings.yml"
        let dir = ((path.first == "/") ? "/" : "") + path.split(separator: "/").dropLast().joined(separator: "/")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        let yml = try SceneSettings.format.save()
        try yml.write(toFile: path, atomically: true, encoding: .ascii)
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
    
    func set(key: Key, value: Yaml) {
        guard var dict = self.yml.dictionary else { return }
        dict[Yaml.string(key.rawValue)] = value
        self.yml = Yaml.dictionary(dict)
    }
    
    func get(key: Key) -> Yaml? {
        guard var dict = self.yml.dictionary else { return nil }
        return dict[Yaml.string(key.rawValue)]
    }
    
    func save() {
        try! Yaml.save(Yaml.dictionary([Yaml.string("Settings") : self.yml]), toFile: filepath)
    }
    
    static var format: Yaml {
        get {
            var settingsDict = [Yaml : Yaml]()
            settingsDict["Num_MarkersX"] = Yaml.array([8,8].map{return Yaml.int($0)})
            settingsDict["Num_MarkersY"] = Yaml.array([8,7].map{return Yaml.int($0)})
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
            settingsDict["Marker_Length"] = Yaml.array([72,108].map{return Yaml.double($0)})
            settingsDict["Calibrate_FixDistCoeffs"] = Yaml.string("00111")
            settingsDict["First_Marker"] = Yaml.array([113,516].map{return Yaml.int($0)})
            settingsDict["Mode"] = Yaml.string(CalibrationMode.STEREO.rawValue)
            settingsDict["Alpha parameter"] = Yaml.int(-1)
            settingsDict["Resizing factor"] = Yaml.int(2)
            let mainDict = Yaml.dictionary(settingsDict)
            return Yaml.dictionary([Yaml.string("Settings") : mainDict])
        }
    }
    
    static func create(_ dirStruc: DirectoryStructure) throws {
        let path = dirStruc.calibrationSettingsFile
        try Yaml.save(CalibrationSettings.format, toFile: path)
    }
}
