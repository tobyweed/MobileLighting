//
//  DirectoryStructure.swift
//  MobileLighting_Mac
//
//  Created by Nicholas Mosier on 6/6/18.
//

import Foundation

// manages the directory structure of the MobileLighting project
class DirectoryStructure {
    let scenesDir: String
    public var currentScene: String
    
    init(scenesDir: String, currentScene: String) {
        self.scenesDir = scenesDir
        self.currentScene = currentScene
    }
    
    private var dirList: [String] {
        get {
            return [scenes, scene, settings, orig, tracks, ambient, ambientBall, computed, decoded, disparity, merged, calibComputed, intrinsicsPhotos, stereoPhotos, metadata, imageLists, reprojected, merged2, ambientPhotos, ambientVideos]
        }
    }
    
    var scenes: String {
        get {
            return scenesDir
        }
    }
    var scene: String {
        return [scenesDir, currentScene].joined(separator: "/")
    }
    var sceneInfo: String {
        return scene + "/sceneInfo"
    }
    
    var ambientDefault: String {
        return "\(self.scene)/defaultAmbient"
    }
    
    func ambientDefault(rectified: Bool) -> String {
        return "\(self.scene)/defaultAmbient/\( rectified ? "rectified" : "unrectified" )"
    }
    
    var orig: String {
        get {
            return self.scene + "/" + "orig"
        }
    }
    
    var tracks: String {
        get {
            return self.scene + "/" + "tracks"
        }
    }
    
    var settings: String {
        return "\(self.scene)/settings"
    }
    
    var scenePictures: String {
        return "\(self.sceneInfo)/scenePictures"
    }
    
    var sceneSettingsFile: String {
        get {
            return self.settings + "/" + "sceneSettings.yml"
        }
    }
    
    var calibrationSettingsFile: String {
        get {
            return self.settings + "/" + "calibration.yml"
        }
    }
    
    var boardsDir: String {
        get {
            return "\(self.settings)/boards"
        }
    }
    
    
    
    
    /*=====================================================================================
     Ambients
     ======================================================================================*/
    func ambients(ball: Bool, photo: Bool, humanMotion: Bool) -> String {
        return (photo) ? ((ball) ? ambientBallPhotos : ambientPhotos) : ambientVideos(humanMotion)
    }
    
    // gets the right index to write ambients to
    // appending: whether we're adding another directory or writing to the 0th directory
    // photo: whether we're in photo or video mode
    // ball: whether we should save to ambient or ambientBall (only applies to photo mode)
    // mode: what mode we're in (eg "flash", "torch", "normal")
    func getAmbientDirectoryStartIndex(appending: Bool, photo: Bool, ball: Bool, mode: String, humanMotion: Bool = false) -> Int {
        var ids: [Int] = []
        var startIndex = 0
        if(appending) {
            do {
                // create an array of paths to all the prior directories
                let dirs = try FileManager.default.contentsOfDirectory(atPath: dirStruc.ambients(ball: ball, photo: photo, humanMotion: humanMotion)).map {
                    return "\(dirStruc.ambients(ball: ball, photo: photo, humanMotion: humanMotion))/\($0)"
                }
                // collect all the directory IDs, ignoring all directories not in the appropriate format (eg [F|T|L]x)
                switch mode {
                case "flash":
                    ids = getIDs(dirs, prefix: "F", suffix: "")
                    break
                case "torch":
                    ids = getIDs(dirs, prefix: "T", suffix: "")
                    break
                default:
                    ids = getIDs(dirs, prefix: "L", suffix: "")
                }
            } catch {
                // print a message if we couldn't get the prior IDs. this could be caused by the absence of prior IDs, in which case we just want to keep startIndex at 0.
                print("error getting IDs of previous ambient directories. perhaps there are none.")
            }
            // if we can get a max value from ids, set startIndex to one greater than the largest collected ID
            if(ids.max() != nil) { startIndex = ids.max()! + 1 }
            
        }
        return startIndex
    }
    
    // Photos ---------------------------------------------------------------------------------------------------------
    private var ambient: String {
        get {
            return self.orig + "/" + "ambient"
        }
    }
    
    var ambientBall: String {
        get {
            return self.orig + "/" + "ambientBall"
        }
    }
    
    var ambientBallPhotos: String {
        get {
            return self.ambientBall + "/" + "photos"
        }
    }
    
    var ambientPhotos: String {
        get {
            return self.ambient + "/" + "photos"
        }
    }
    
    func ambientPhotos(_ ball: Bool) -> String {
        return (ball) ? ambientBallPhotos : ambientPhotos
    }
    
    func ambientPhotos(ball: Bool, mode: String, lighting: Int) -> String {
        var subdir: String
        switch mode {
        case "flash":
            subdir =  "\(ambientPhotos(ball))/F\(lighting)"
            break
        case "torch":
            subdir =  "\(ambientPhotos(ball))/T\(lighting)"
            break
        default:
            subdir =  "\(ambientPhotos(ball))/L\(lighting)"
        }
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    
    func ambientPhotos(ball: Bool, pos: Int, mode: String, lighting: Int) -> String {
        return subdir(self.ambientPhotos(ball: ball, mode: mode, lighting: lighting), pos: pos)
    }
    
    // Videos ---------------------------------------------------------------------------------------------------------
    var ambientVideos: String {
        get {
            return self.ambient + "/" + "videos"
        }
    }
    
    func ambientVideos(_ humanMotion: Bool) -> String {
        return ambientVideos + ( (humanMotion) ? "/human" : "/smooth" )
    }
    
    func ambientVideos( mode: String, lighting: Int, humanMotion: Bool ) -> String {
        var subdir: String
        switch mode {
        case "torch":
            subdir =  "\(ambientVideos(humanMotion))/T\(lighting)"
            break
        default:
            subdir =  "\(ambientVideos(humanMotion))/L\(lighting)"
        }
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    
    // Computed ---------------------------------------------------------------------------------------------------------
    func ambientComputed(_ ball: Bool) -> String {
        
        let subdir = (ball) ? ("\(self.computed)/ambientBall") : ("\(self.computed)/ambient")
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    
    func ambientComputed(ball: Bool, rectified: Bool) -> String {
        let subdir = "\(self.ambientComputed(ball))/\(rectified ? "rectified" : "unrectified")"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    
    func ambientComputed(ball: Bool, mode: String, lighting: Int, rectified: Bool) -> String {
        var prefix: String
        switch mode {
        case "flash":
            prefix =  "F"
            break
        case "torch":
            prefix =  "T"
            break
        default:
            prefix =  "L"
        }
        
        let subdir = "\(self.ambientComputed(ball: ball, rectified: rectified))/\(prefix)\(lighting)"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    
    func ambientComputed(ball: Bool, mode: String, pos: Int, lighting: Int, rectified: Bool) -> String {
        let subdir = "\(self.ambientComputed(ball: ball, mode: mode, lighting: lighting, rectified: rectified))/pos\(pos)"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    
    
    
    
    /*=====================================================================================
     Calibration
     ======================================================================================*/

    var calibration: String {
        get {
            return self.orig + "/" + "calibration"
        }
    }
    
    var intrinsicsPhotos: String {
        get {
            return self.calibration + "/" + "intrinsics"
        }
    }
    
    var stereoPhotos: String {
        get {
            return self.calibration + "/" + "stereo"
        }
    }
    
    func stereoPhotos(_ pos: Int) -> String {
        return subdir(stereoPhotos, pos: pos)
    }
    
    var imageLists: String {
        get {
            return self.calibration + "/" + "imageLists"
        }
    }
    
    var intrinsicsImageList: String {
        get {
            return self.imageLists + "/" + "intrinsicsImageList.yml"
        }
    }
    var stereoImageList: String {
        get {
            return self.imageLists + "/" + "stereoImageList.yml"
        }
    }
    
    
    
    /*=====================================================================================
     Computed
     ======================================================================================*/
    
    var computed: String {
        get {
            return self.scene + "/" + "computed"
        }
    }
    
    var prethresh: String {
        get {
            return self.computed + "/" + "prethresh"
        }
    }
    
    var thresh: String {
        get {
            return self.computed + "/" + "thresh"
        }
    }
    
    var decoded: String {
        get {
            return self.computed + "/" + "decoded"
        }
    }
    
    func decoded(_ rectified: Bool) -> String {
        let subdir = "\(self.decoded)/\(rectified ? "rectified" : "unrectified")"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    
    func decoded(proj: Int, rectified: Bool) -> String {
        let subdir = "\(self.decoded(rectified))/proj\(proj)"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    
    func decoded(proj: Int, pos: Int, rectified: Bool) -> String {
        let subdir = "\(self.decoded(proj: proj, rectified: rectified))/pos\(pos)"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    
    var shadowvis: String {
        get {
            return self.computed + "/" + "shadowvis"
        }
    }
    
    func shadowvis(pos: Int) -> String {
        let subdir = "\(self.shadowvis)/pos\(pos)"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    
    var disparity: String {
        get {
            return self.computed + "/" + "disparity"
        }
    }
    func disparity(_ rectified: Bool) -> String {
        let subdir = "\(self.disparity)/\(rectified ? "rectified" : "unrectified")"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    
    func disparity(proj: Int, rectified: Bool) -> String {
        let subdir = "\(self.disparity(rectified))/proj\(proj)"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    
    func disparity(proj: Int, pos: Int, rectified: Bool) -> String {
        return subdir(self.disparity(rectified), proj: proj, pos: pos)
    }
    
    var merged: String {
        get {
            return self.computed + "/" + "merged"
        }
    }
    func merged(_ rectified: Bool) -> String {
        let subdir = "\(self.merged)/\(rectified ? "rectified" : "unrectified")"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    func merged(pos: Int, rectified: Bool) -> String {
        let subdir = self.merged(rectified) + "/" + "pos\(pos)"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    
    var reprojected: String {
        get {
            return self.computed + "/" + "reprojected"
        }
    }
    
    func reprojected(proj: Int) -> String {
        return subdir(self.reprojected, proj: proj)
    }
    
    func reprojected(proj: Int, pos: Int) -> String {
        return subdir(self.reprojected, proj: proj, pos: pos)
    }
    
    var merged2: String {
        return self.computed + "/" + "merged2"
    }
    func merged2(_ pos: Int) -> String {
        return subdir(merged2, pos: pos)
    }
    
    
    var calibComputed: String {
        get {
            return self.computed + "/" + "calibration"
        }
    }
    
    var intrinsicsJSON: String {
        get {
            return self.calibComputed + "/" + "intrinsics.json"
        }
    }
    
    func extrinsicsJSON(left: Int, right: Int) -> String {
        return self.calibComputed + "/extrinsics\(left)\(right).json"
    }
    
    // old
    var intrinsicsYML: String {
        get {
            return self.calibComputed + "/" + "intrinsics.yml"
        }
    }
    
    // old
    var extrinsics: String {
        get {
            return self.calibComputed + "/" + "extrinsics"
        }
    }
    
    // old
    func extrinsicsYML(left: Int, right: Int) -> String {
        return self.extrinsics + "/" + "extrinsics\(left)\(right).yml"
    }
    
    
    
    var metadata: String {
        get {
            return self.computed + "/" + "metadata"
        }
    }
    func metadataFile(_ direction: Int, proj: Int, pos: Int) -> String {
        return subdir(metadata, proj: proj, pos: pos) + "/metadata\(direction).yml"
    }
    
    
    //MARK: utility functions
    func createDirs() throws {
        for dir in dirList {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    
    // subdir -- get subdirectory of provided directory path
    // indexed to current/provided projector and position
    private func subdir(_ dir: String, proj: Int, pos: Int) -> String {
        let subdir = self.subdir(dir, proj: proj) + "/" + "pos\(pos)"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    private func subdir(_ dir: String, proj: Int) -> String {
        let subdir = dir + "/" + "proj\(proj)"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
    private func subdir(_ dir: String, pos: Int) -> String {
        let subdir = dir + "/" + "pos\(pos)"
        try! FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true, attributes: nil)
        return subdir
    }
}
