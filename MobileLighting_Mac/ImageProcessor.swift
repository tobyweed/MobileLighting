//
//  ImageProcessor.swift
//  demo
//
//  Created by Nicholas Mosier on 6/28/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation
import Darwin
import Yaml


// MARK: control flow

// Utils
// Count the number of -a flags appearing in array of flags
func countAFlags(flags: [String]) -> Int {
    var numAs = 0
    for flag in flags {
        if(flag != "-a") {
            print("Unrecognized flag \(flag)")
            return -1
        } else {
            numAs += 1
        }
    }
    return numAs
}


// Return all projectrs in the given directory
func getAllProj(inputDir: String, prefix: String, suffix: String) -> [Int] {
    let projDirs = try! FileManager.default.contentsOfDirectory(atPath: inputDir)
    let allproj = getIDs(projDirs, prefix: prefix, suffix: suffix).sorted()
    if(allproj.count <= 0) {
        print("No projector positions found.")
        return []
    }
    return allproj
}

func getProjFromParam(param: String, inputDir: String, prefix: String, suffix: String) -> [Int] {
    // make sure we have an array of projectors or a single projector as the second token
    var projs = [Int]()
    if (param.hasPrefix("[")) {
        projs = stringToIntArray(param)
    } else if (Int(param) != nil) {
        projs.append(Int(param)!)
    } else {
        print("Bad input, no projector positions initialized")
        return []
    }
    
    projs.sort()
    return projs
}

// Return all adjacent pairs in the given directory
func getAllPosPairs(inputDir: String, prefix: String, suffix: String) -> [(Int,Int)] {
    let posDirs = try! FileManager.default.contentsOfDirectory(atPath: inputDir)
    let allpos = getIDs(posDirs, prefix: prefix, suffix: suffix).sorted()
    if(allpos.count <= 0) {
        print("No positions found.")
        return []
    }
    return [(Int,Int)](zip(allpos, [Int](allpos[1...])))
}

// Convert input to pairs. Accepts a pair of integer arrays or a pair of integers.
func getPosPairsFromParams(params: [String], prefix: String, suffix: String) -> [(Int,Int)] {
    // make sure we have an array of projectors or a single projector as the second token
    guard (params.count == 2) else {
        print("Must provide two arguments")
        return []
    }
    var pos1 = [Int]()
    var pos2 = [Int]()
    if (params[0].hasPrefix("[") && params[1].hasPrefix("[")) {
        pos1 = stringToIntArray(params[0])
        pos2 = stringToIntArray(params[1])
    } else if (Int(params[0]) != nil && Int(params[1]) != nil) {
        pos1.append(Int(params[0])!)
        pos2.append(Int(params[1])!)
    } else {
        print("Bad input, no position pairs initialized")
        return []
    }
    
    guard pos1.count == pos2.count else {
        print("Each position array must have the same length.")
        return []
    }
    
    pos1.sort()
    pos2.sort()
    let pairs = [(Int,Int)](zip(pos1, pos2))
    return pairs
}


// Processing control flow entrypoints
func runGetExtrinsics(all: Bool, params: [String]) {
    // determine targets
    var positionPairs: [(Int, Int)]
    if (all) {
        positionPairs = getAllPosPairs(inputDir: dirStruc.tracks, prefix: "pos", suffix: "-track.json")
    } else {
        positionPairs = getPosPairsFromParams(params: Array(params[1...]), prefix: "pos", suffix: "-track.json")
    }
    
    // run processing
    for (leftpos, rightpos) in positionPairs {
        var track1: [CChar]
        var track2: [CChar]
        var intrinsicsFile: [CChar]
        do {
            try track1 = safePath("\(dirStruc.tracks)/pos\(leftpos)-track.json")
            try track2 = safePath("\(dirStruc.tracks)/pos\(rightpos)-track.json")
            try intrinsicsFile = safePath("\(dirStruc.calibComputed)/intrinsics.json")
        } catch let err {
            print(err.localizedDescription)
            break
        }
        var outputDir = *"\(dirStruc.calibComputed)"

        ComputeExtrinsics(Int32(leftpos), Int32(rightpos), &track1, &track2, &intrinsicsFile, &outputDir)
    }
}

func runRefine(allProj: Bool, allPosPairs: Bool, params: [String]) {
    var projs: [Int] = []
    if (allProj) {
        projs = getAllProj(inputDir: dirStruc.decoded(true), prefix: "proj", suffix: "")
    } else {
        projs = getProjFromParam(param: params[1], inputDir: dirStruc.decoded(true), prefix: "proj", suffix: "")
    }
    
    for proj in projs {
        var positionPairs: [(Int, Int)]
        if (allPosPairs) {
            positionPairs = getAllPosPairs(inputDir: dirStruc.decoded(proj: proj, rectified: true), prefix: "pos", suffix: "")
        } else {
            let args = (params.count == 3) ? Array(params[1...]) : Array(params[2...]) // skip an additional param if needed
            positionPairs = getPosPairsFromParams(params: args, prefix: "pos", suffix: "")
        }

        for (leftpos, rightpos) in positionPairs {
            for direction: Int in [0, 1] {
                for pos in [leftpos, rightpos] {
                    var cimg: [CChar]
                    var coutdir: [CChar]
                    do {
                        try cimg = safePath("\(dirStruc.decoded(proj: proj, pos: pos, rectified: true))/result\(leftpos)\(rightpos)\(direction == 0 ? "u" : "v")-0rectified.pfm")
                        try coutdir = safePath(dirStruc.decoded(proj: proj, pos: pos, rectified: true))
                    } catch let err {
                        print(err.localizedDescription)
                        break
                    }

                    let metadatapath = dirStruc.metadataFile(Int(direction), proj: proj, pos: pos)
                    do {
                        let metadataStr = try String(contentsOfFile: metadatapath)
                        let metadata: Yaml = try Yaml.load(metadataStr)
                        if let angle: Double = metadata.dictionary?["angle"]?.double {
                            var posID = *"\(leftpos)\(rightpos)"
                            refineDecodedIm(&coutdir, Int32(direction), &cimg, angle, &posID)
                        }
                    } catch {
                        print("refine error: could not load metadata file \(metadatapath).")
                    }
                }
            }
        }
    }
}

func runDisparity(allProj: Bool, allPosPairs: Bool, params: [String]) {
    var projs: [Int] = []
    if (allProj) {
        projs = getAllProj(inputDir: dirStruc.decoded(true), prefix: "proj", suffix: "")
    } else {
        projs = getProjFromParam(param: params[1], inputDir: dirStruc.decoded(true), prefix: "proj", suffix: "")
    }
    
    for proj in projs {
        var positionPairs: [(Int, Int)]
        if (allPosPairs) {
            positionPairs = getAllPosPairs(inputDir: dirStruc.decoded(proj: proj, rectified: true), prefix: "pos", suffix: "")
        } else {
            let args = (params.count == 3) ? Array(params[1...]) : Array(params[2...]) // skip an additional param if needed
            positionPairs = getPosPairsFromParams(params: args, prefix: "pos", suffix: "")
        }

        for (leftpos, rightpos) in positionPairs {
            disparityMatch(proj: proj, leftpos: leftpos, rightpos: rightpos, rectified: true)
        }
    }
}

func runRectify(allProj: Bool, allPosPairs: Bool, params: [String]) {
    var projs: [Int] = []
    if (allProj) {
        projs = getAllProj(inputDir: dirStruc.decoded(false), prefix: "proj", suffix: "")
    } else {
        projs = getProjFromParam(param: params[1], inputDir: dirStruc.decoded(false), prefix: "proj", suffix: "")
    }
    
    for proj in projs {
        var positionPairs: [(Int, Int)]
        if (allPosPairs) {
            positionPairs = getAllPosPairs(inputDir: dirStruc.decoded(proj: proj, rectified: false), prefix: "pos", suffix: "")
        } else {
            let args = (params.count == 3) ? Array(params[1...]) : Array(params[2...]) // skip an additional param if needed
            positionPairs = getPosPairsFromParams(params: args, prefix: "pos", suffix: "")
        }

        for (leftpos, rightpos) in positionPairs {
            print("Trying to rectify position pair (\(leftpos),\(rightpos)) for projector \(proj)")
            rectifyDec(left: leftpos, right: rightpos, proj: proj)
        }
    }
}

func runRectifyAmb(allPosPairs: Bool, params: [String]) {
    let modes: [String] = ["normal", "flash", "torch"]
    
    // loop though all modes & rectify them
    for mode in modes {
        let dirNames = (try! FileManager.default.contentsOfDirectory(atPath: dirStruc.ambientPhotos)).map {
            return "\(dirStruc.ambientPhotos)/\($0)"
        }
        var prefix: String
        switch mode {
        case "flash":
            prefix = "F"
            break
        case "torch":
            prefix = "T"
            break
        default:
            prefix = "L"
        }
        let lightings = getIDs(dirNames, prefix: prefix, suffix: "")
        for lighting in lightings {
            print("\nRectifying directory: \(prefix)\(lighting)");
            var positionPairs: [(Int, Int)]
            if (allPosPairs) {
                positionPairs = getAllPosPairs(inputDir: dirStruc.ambientPhotos(ball: false, mode: mode, lighting: lighting), prefix: "pos", suffix: "")
            } else {
                positionPairs = getPosPairsFromParams(params: params, prefix: "pos", suffix: "")
            }
            
            // loop through all pos pairs and rectify them
            for (left, right) in positionPairs {
                print("Rectifying position pair: \(left) (left) and \(right) (right)");
                // set numExp to zero if in flash mode
                let numExp: Int = (mode == "flash") ? ( 1 ) : (sceneSettings.ambientExposureDurations!.count)
                // loop through all exposures
                for exp in 0..<numExp {
                    print("Rectifying exposure: \(exp)");
                    rectifyAmb(ball: false, left: left, right: right, mode: mode, exp: exp, lighting: lighting)
                }
            }
        }
    }
}

func runMerge(allPosPairs: Bool, params: [String]) {
    var positionPairs: [(Int, Int)]
    if (allPosPairs) {
        positionPairs = getAllPosPairs(inputDir: dirStruc.decoded(proj: 0, rectified: true), prefix: "pos", suffix: "")
    } else {
        let args = (params.count == 3) ? Array(params[1...]) : Array(params[2...]) // skip an additional param if needed
        positionPairs = getPosPairsFromParams(params: args, prefix: "pos", suffix: "")
    }

    for (left, right) in positionPairs {
        merge(left: left, right: right, rectified: true)
    }
}

func runReproject(allPosPairs: Bool, params: [String]) {
    var positionPairs: [(Int, Int)]
    if (allPosPairs) {
        positionPairs = getAllPosPairs(inputDir: dirStruc.decoded(proj: 0, rectified: true), prefix: "pos", suffix: "")
    } else {
        let args = (params.count == 3) ? Array(params[1...]) : Array(params[2...]) // skip an additional param if needed
        positionPairs = getPosPairsFromParams(params: args, prefix: "pos", suffix: "")
    }

    for (left, right) in positionPairs {
        reproject(left: left, right: right)
    }
}

func runMerge2(allPosPairs: Bool, params: [String]) {
    var positionPairs: [(Int, Int)]
    if (allPosPairs) {
        positionPairs = getAllPosPairs(inputDir: dirStruc.reprojected(proj: 0), prefix: "pos", suffix: "")
    } else {
        let args = (params.count == 3) ? Array(params[1...]) : Array(params[2...]) // skip an additional param if needed
        positionPairs = getPosPairsFromParams(params: args, prefix: "pos", suffix: "")
    }

    for (left, right) in positionPairs {
        mergeReprojected(left: left, right: right)
    }
}



//MARK: disparity matching
// uses bridged C++ code from image processing pipeline
// NOTE: this decoding step is not yet automated; it must manually be executed from
//    the main command-line user input loop

// computes & saves disparity maps for images of the given image position pair taken with the given projector
// NOW: also refines disparity maps
func disparityMatch(proj: Int, leftpos: Int, rightpos: Int, rectified: Bool) {
    var refinedDirLeft: [CChar], refinedDirRight: [CChar]
    do {
        try refinedDirLeft = safePath(dirStruc.decoded(proj: proj, pos: leftpos, rectified: rectified))
        try refinedDirRight = safePath(dirStruc.decoded(proj: proj, pos: rightpos, rectified: rectified))
        try _ = safePath("\(dirStruc.decoded(proj: proj, pos: rightpos, rectified: rectified))/result\(leftpos)\(rightpos)u-4refined2.pfm") // just check one of the files that should be there, hope that if it is the others will be there too. necessary to avoid crashes from C exceptions due to missing files
    } catch let err {
        print(err.localizedDescription)
        return
    }
    var disparityDirLeft = *dirStruc.disparity(proj: proj, pos: leftpos, rectified: rectified)//*dirStruc.subdir(dirStruc.disparity(rectified), proj: proj, pos: leftpos)
    var disparityDirRight = *dirStruc.disparity(proj: proj, pos: rightpos, rectified: rectified)//*dirStruc.subdir(dirStruc.disparity(rectified), proj: proj, pos: rightpos)
    let l = Int32(leftpos)
    let r = Int32(rightpos)
    
    // get the maximum allowable y disparities from scene settings
    let ythresh = sceneSettings.yDisparityThreshold
    
    let xmin, xmax, ymin, ymax: Int32
    if (rectified) {
        xmin = -1080
        xmax = 1080
//        ymin = -1
//        ymax = 1
        // will round ythresh to nearest int
        ymin = -Int32(ythresh)
        ymax = Int32(ythresh)
    } else {
        xmin = 0
        xmax = 0
        ymin = 0
        ymax = 0
    }
    
    disparitiesOfRefinedImgs(&refinedDirLeft, &refinedDirRight,
                             &disparityDirLeft,
                             &disparityDirRight,
                             l, r, rectified ? 1 : 0,
                             xmin, xmax, ymin, ymax)
    var in_suffix = "0initial".cString(using: .ascii)!
    var out_suffix = "1crosscheck1".cString(using: .ascii)!
    crosscheckDisparities(&disparityDirLeft, &disparityDirRight, l, r, 1.5, 0, 0, &in_suffix, &out_suffix)
    // if images are not rectified, do not perform filter disparities
    if !rectified {
        return
    }
    
    let in_suffix_x = "/disp\(leftpos)\(rightpos)x-1crosscheck1.pfm".cString(using: .ascii)!
    let in_suffix_y = "/disp\(leftpos)\(rightpos)y-1crosscheck1.pfm".cString(using: .ascii)!
    let out_suffix_x = "/disp\(leftpos)\(rightpos)x-2filtered.pfm".cString(using: .ascii)!
    let out_suffix_y = "/disp\(leftpos)\(rightpos)y-2filtered.pfm".cString(using: .ascii)!
    
    var dispx, dispy, outx, outy: [CChar]
    
    // Filter the LEFT disparities
    dispx = disparityDirLeft + in_suffix_x
    dispy = disparityDirLeft + in_suffix_y
    outx = disparityDirLeft + out_suffix_x
    outy = disparityDirLeft + out_suffix_y
//    filterDisparities(&dispx, &dispy, &outx, &outy, l, r, 1.5, 3, 0, 20, 200)
    filterDisparities(&dispx, &dispy, &outx, &outy, l, r, Float(ythresh), 3, 0, 20, 200)

    // Filter the RIGHT disparities
    dispx = disparityDirRight + in_suffix_x
    dispy = disparityDirRight + in_suffix_y
    outx = disparityDirRight + out_suffix_x
    outy = disparityDirRight + out_suffix_y
//    filterDisparities(&dispx, &dispy, &outx, &outy, l, r, 1.5, 3, 0, 20, 200)
    filterDisparities(&dispx, &dispy, &outx, &outy, l, r, Float(ythresh), 3, 0, 20, 200)
    in_suffix = "2filtered".cString(using: .ascii)!
    out_suffix = "3crosscheck2".cString(using: .ascii)!
    crosscheckDisparities(&disparityDirLeft, &disparityDirRight, l, r, 1.5, 1, 0, &in_suffix, &out_suffix)
}


//MARK: rectification
//rectify decoded images
func rectifyDec(left: Int, right: Int, proj: Int) {
//    var intr = *dirStruc.intrinsicsJSON
//    var extr = *dirStruc.extrinsicsJSON(left: left, right: right)
    //paths for storing output
    let rectdirleft = dirStruc.decoded(proj: proj, pos: left, rectified: true)
    let rectdirright = dirStruc.decoded(proj: proj, pos: right, rectified: true)
    //paths for retreiving input
    var intr: [CChar]
    var extr: [CChar]
    var result0l: [CChar]
    var result0r: [CChar]
    var result1l: [CChar]
    var result1r: [CChar]
    do {
        try intr = safePath(dirStruc.intrinsicsJSON)
        try extr = safePath(dirStruc.extrinsicsJSON(left: left, right: right))
        try result0l = safePath("\(dirStruc.decoded(proj: proj, pos: left, rectified: false))/result\(left)u-2holefilled.pfm")
        try result0r = safePath("\(dirStruc.decoded(proj: proj, pos: right, rectified: false))/result\(right)u-2holefilled.pfm")
        try result1l = safePath("\(dirStruc.decoded(proj: proj, pos: left, rectified: false))/result\(left)v-2holefilled.pfm")
        try result1r = safePath("\(dirStruc.decoded(proj: proj, pos: right, rectified: false))/result\(right)v-2holefilled.pfm")
    } catch let err {
        print(err.localizedDescription)
        return
    }
    computeMaps(&result0l, &intr, &extr)

    let outpaths = [rectdirleft + "/result\(left)\(right)u-0rectified.pfm",
        rectdirleft + "/result\(left)\(right)v-0rectified.pfm",
        rectdirright + "/result\(left)\(right)u-0rectified.pfm",
        rectdirright + "/result\(left)\(right)v-0rectified.pfm",
        ]
    for path in outpaths {
        let dir = path.split(separator: "/").dropLast().joined(separator: "/")
        do { try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil) }
        catch { print("rectify: could not create dir at \(dir).") }
    }
    var coutpaths = outpaths.map {
        return $0.cString(using: .ascii)!
    }
    rectifyDecoded(0, &result0l, &coutpaths[0])
    rectifyDecoded(0, &result1l, &coutpaths[1])
    rectifyDecoded(1, &result0r, &coutpaths[2])
    rectifyDecoded(1, &result1r, &coutpaths[3])
}


//rectify ambient images
func rectifyAmb(ball: Bool, left: Int, right: Int, mode: String, exp: Int, lighting: Int) {
    var intr: [CChar]
    var extr: [CChar]
    var resultl: [CChar]
    var resultr: [CChar]
    do {
        try intr = safePath(dirStruc.intrinsicsJSON)
        try extr = safePath(dirStruc.extrinsicsJSON(left: left, right: right))
        try resultl = safePath("\(dirStruc.ambientPhotos(ball: ball, pos: left, mode: mode, lighting: lighting))/exp\(exp).JPG")
        try resultr = safePath("\(dirStruc.ambientPhotos(ball: ball, pos: right, mode: mode, lighting: lighting))/exp\(exp).JPG")
    } catch let err {
        print(err.localizedDescription)
        return
    }
    var settings = *dirStruc.calibrationSettingsFile
    if(exp == 0) { //maps only need to be computed once per stereo pair
        computeMaps(&resultl, &intr, &extr)
    }
    
    //paths for storing output
    let outpaths: [String] = [dirStruc.ambientComputed(ball: ball, mode: mode, pos: left, lighting: lighting, rectified: true) + "/\(left)\(right)rectified-exp\(exp).png",
        dirStruc.ambientComputed(ball: ball, mode: mode, pos: right, lighting: lighting, rectified: true) + "/\(left)\(right)rectified-exp\(exp).png"
    ]
    
    var coutpaths = outpaths.map {
        return $0.cString(using: .ascii)!
    }
    
    //rectify both poses
    print("trying to save rectified image to path: \(outpaths[0])");
    rectifyAmbient(0, &resultl, &coutpaths[0])
    print("trying to save rectified image to path: \(outpaths[1])");
    rectifyAmbient(1, &resultr, &coutpaths[1])
}


//MARK: merge
// merge disparity maps for one stereo pair across all projectors
func merge(left leftpos: Int, right rightpos: Int, rectified: Bool) {
    var leftx, lefty: [[CChar]]
    var rightx, righty: [[CChar]]
    
    // search for projectors for which disparities have been computed for given left/right positions
    guard let projectorDirs = try? FileManager.default.contentsOfDirectory(atPath: "\(dirStruc.disparity(rectified))") else {
        print("merge: cannot find projectors directory at \(dirStruc.disparity(rectified))")
        return
    }
    let projectors = getIDs(projectorDirs, prefix: "proj", suffix: "")
    let positionDirs = projectors.map {
        return (dirStruc.disparity(proj: $0, pos: leftpos, rectified: rectified), dirStruc.disparity(proj: $0, pos: rightpos, rectified: rectified))
    }
    var pfmPathsLeft, pfmPathsRight: [(String, String)]
    pfmPathsLeft = positionDirs.map {
        return ("\($0.0)/disp\(leftpos)\(rightpos)x-3crosscheck2.pfm", "\($0.0)/disp\(leftpos)\(rightpos)y-3crosscheck2.pfm")
    }
    pfmPathsRight = positionDirs.map {
        return ("\($0.1)/disp\(leftpos)\(rightpos)x-3crosscheck2.pfm", "\($0.1)/disp\(leftpos)\(rightpos)y-3crosscheck2.pfm")
    }
    
    pfmPathsLeft = pfmPathsLeft.filter {
        let (leftx, lefty) = $0
        return FileManager.default.fileExists(atPath: leftx) && FileManager.default.fileExists(atPath: lefty)
    }
    pfmPathsRight = pfmPathsRight.filter {
        let (rightx, righty) = $0
        return FileManager.default.fileExists(atPath: rightx) && FileManager.default.fileExists(atPath: righty)
    }
    leftx = pfmPathsLeft.map{ return $0.0 }.map{ return $0.cString(using: .ascii)! }
    lefty = pfmPathsLeft.map{ return $0.1 }.map{ return $0.cString(using: .ascii)! }
    rightx = pfmPathsRight.map{ return $0.0 }.map{ return $0.cString(using: .ascii)! }
    righty = pfmPathsRight.map{ return $0.1 }.map{ return $0.cString(using: .ascii)! }
    
    var imgsx = [UnsafeMutablePointer<Int8>?]()
    var imgsy = [UnsafeMutablePointer<Int8>?]()
    var outx = [CChar]()
    var outy = [CChar]()
    
    for i in 0..<leftx.count {
        imgsx.append(getptr(&leftx[i]))
    }
    for i in 0..<lefty.count {
        imgsy.append(getptr(&lefty[i]))
    }

    outx = (dirStruc.merged(pos: leftpos, rectified: rectified) + "/disp\(leftpos)\(rightpos)x-0initial.pfm").cString(using: .ascii)!
    outy = (dirStruc.merged(pos: leftpos, rectified: rectified) + "/disp\(leftpos)\(rightpos)y-0initial.pfm").cString(using: .ascii)!
    let mingroup: Int32 = 2
    let maxdiff: Float = 1.0
    guard (imgsx.count > 0 && imgsy.count > 0) else {
        print("No images to be merged for left position \(leftpos), right position \(rightpos).")
        return
    }
    mergeDisparities(&imgsx, &imgsy, &outx, &outy, Int32(imgsx.count), mingroup, maxdiff)
    
    imgsx.removeAll()
    imgsx = [UnsafeMutablePointer<Int8>?]()
    imgsy = [UnsafeMutablePointer<Int8>?]()
    for i in 0..<rightx.count {
        imgsx.append(getptr(&rightx[i]))
    }
    imgsy.removeAll()
    for i in 0..<righty.count {
        imgsy.append(getptr(&righty[i]))
    }
    
    if rectified {
        outx = (dirStruc.merged(pos: rightpos, rectified: rectified) + "/disp\(leftpos)\(rightpos)x-0initial.pfm").cString(using: .ascii)!
        outy = (dirStruc.merged(pos: rightpos, rectified: rectified) + "/disp\(leftpos)\(rightpos)y-0initial.pfm").cString(using: .ascii)!
    } else {
        outx = (dirStruc.merged(pos: rightpos, rectified: rectified) + "/disp\(leftpos)\(rightpos)x.pfm").cString(using: .ascii)!
        outy = (dirStruc.merged(pos: rightpos, rectified: rectified) + "/disp\(leftpos)\(rightpos)y.pfm").cString(using: .ascii)!
    }

    guard (imgsx.count > 0 && imgsy.count > 0) else {
        print("No images to be merged for left position \(leftpos), right position \(rightpos).")
        return
    }
    mergeDisparities(&imgsx, &imgsy, &outx, &outy, Int32(imgsx.count), mingroup, maxdiff)
    
    var posdir0: [CChar]
    var posdir1: [CChar]
    do {
        try posdir0 = safePath(dirStruc.merged(pos: leftpos, rectified: true))
        try posdir1 = safePath(dirStruc.merged(pos: rightpos, rectified: true))
    } catch let err {
        print(err.localizedDescription)
        return
    }
    let l = Int32(leftpos)
    let r = Int32(rightpos)
    let thresh: Float = 0.5
    let xonly: Int32 = 1
    let halfocc: Int32 = 0
    var in_suffix = "0initial".cString(using: .ascii)!
    var out_suffix = "1crosscheck".cString(using: .ascii)!
    
    crosscheckDisparities(&posdir0, &posdir1, l, r, thresh, xonly, halfocc, &in_suffix, &out_suffix)
}

//MARK: reproject
// reprojects merged 
func reproject(left leftpos: Int, right rightpos: Int) {
    let projDirs = try! FileManager.default.contentsOfDirectory(atPath: dirStruc.disparity(true))
    let projectors = getIDs(projDirs.map{return String($0.split(separator: "/").last!)}, prefix: "proj", suffix: "")
    
    for proj in projectors {
        for pos in [leftpos, rightpos] {
            var dispx: [CChar], dispy: [CChar], codex: [CChar], codey: [CChar], outx: [CChar], outy: [CChar], errfile: [CChar], matfile: [CChar], logfile: [CChar]
            do {
                try dispx = safePath((dirStruc.merged(pos: pos, rectified: true) + "/disp\(leftpos)\(rightpos)x-1crosscheck.pfm"))
                try dispy = safePath((dirStruc.merged(pos: pos, rectified: true) + "/disp\(leftpos)\(rightpos)y-1crosscheck.pfm"))
                try codex = safePath("\(dirStruc.decoded(proj: proj, pos: pos, rectified: true))/result\(leftpos)\(rightpos)u-4refined2.pfm")
                try codey = safePath("\(dirStruc.decoded(proj: proj, pos: pos, rectified: true))/result\(leftpos)\(rightpos)v-4refined2.pfm")
            } catch let err {
                print(err.localizedDescription)
                print("Skipping projector \(proj), paths \(leftpos), \(rightpos).")
                break
            }
                
            outx = (dirStruc.reprojected(proj: proj, pos: pos) + "/disp\(leftpos)\(rightpos)x-0initial.pfm").cString(using: .ascii)!
            outy = (dirStruc.reprojected(proj: proj, pos: pos) + "/disp\(leftpos)\(rightpos)y-0initial.pfm").cString(using: .ascii)!
            errfile = (dirStruc.reprojected(proj: proj, pos: pos) + "/error\(leftpos)\(rightpos).pfm").cString(using: .ascii)!
            matfile = (dirStruc.reprojected(proj: proj, pos: pos) + "/mat\(leftpos)\(rightpos).txt").cString(using: .ascii)!
            logfile = *(dirStruc.reprojected(proj: proj, pos: pos) + "/log\(leftpos)\(rightpos).txt")
            reprojectDisparities(&dispx, &dispy, &codex, &codey, &outx, &outy, &errfile, &matfile, &logfile)
            
            /*
            need to add code for using nonlinear reprojection -- but need warpdisp code first.
            */
            
            let dir = *dirStruc.reprojected(proj: proj, pos: pos)
            
            let in_suffix_x = *"/disp\(leftpos)\(rightpos)x-0initial.pfm"
            let out_suffix_x = *"/disp\(leftpos)\(rightpos)x-1filtered.pfm"
            let out_suffix_y = *"/disp\(leftpos)\(rightpos)y-1filtered.pfm"
            
            dispx = dir + in_suffix_x
            outx = dir + out_suffix_x
            outy = dir + out_suffix_y
            
            filterDisparities(&dispx, nil, &outx, nil, Int32(leftpos), Int32(rightpos), -1, 3, 0, 0, 200)
        }
    }
}

//MARK: merge reprojected
func mergeReprojected(left leftpos: Int, right rightpos: Int) {
    for pos in [leftpos, rightpos] {
        _ = *(dirStruc.merged(pos: pos, rectified: true) + "/disp\(leftpos)\(rightpos)x-1crosschecked.pfm") // premerged. Currently unused?
        
        let dispProjectors = getIDs(try! FileManager.default.contentsOfDirectory(atPath: dirStruc.disparity(true)), prefix: "proj", suffix: "")
        // viewDisps: [[CChar]], contains all cross-checked, filtered PFM files that exist
        var viewDisps = *dispProjectors.map {
            return dirStruc.disparity(proj: $0, pos: pos, rectified: true) + "/disp\(leftpos)\(rightpos)x-2filtered.pfm"
            }.filter {
                return FileManager.default.fileExists(atPath: $0, isDirectory: nil)
        }
        var viewDispsPtrs = **viewDisps
        let nV = Int32(viewDisps.count)
        
        let reprojProjectors = getIDs(try! FileManager.default.contentsOfDirectory(atPath: dirStruc.reprojected), prefix: "proj", suffix: "")
        let reprojDirs = reprojProjectors.map {
            return dirStruc.reprojected(proj: $0, pos: pos)
        }

        let filteredReprojDirs = filterReliableReprojected(reprojDirs, left: leftpos, right: rightpos)
        var reprojDisps = *filteredReprojDirs.map { return $0 + "/disp\(leftpos)\(rightpos)x-1filtered.pfm" }
        var reprojDispsPtrs = **reprojDisps
        let nR = Int32(reprojDisps.count)
        
        var inmdfile = *(dirStruc.merged(pos: pos, rectified: true) + "/disp\(leftpos)\(rightpos)x-1crosscheck.pfm")
            
        var outdfile = *(dirStruc.merged2(pos) + "/disp\(leftpos)\(rightpos)x-0initial.pfm")
        var outsdfile = *(dirStruc.merged2(pos) + "/disp\(leftpos)\(rightpos)x-sd.pfm")
        var outnfile = *(dirStruc.merged2(pos) + "/disp\(leftpos)\(rightpos)x-nsamples.pgm")
        
        mergeDisparityMaps2(MERGE2_MAXDIFF, nV, nR, &outdfile, &outsdfile, &outnfile, &inmdfile, &viewDispsPtrs, &reprojDispsPtrs)
        
        // filter merged results
        var indispx = outdfile
        var outx = *(dirStruc.merged2(pos) + "/disp\(leftpos)\(rightpos)x-1filtered.pfm")
        filterDisparities(&indispx, nil, &outx, nil, Int32(leftpos), Int32(rightpos), -1, 0, 0, 20, 20)

    }
    
    // crosscheck filtered results
    var leftdir = *(dirStruc.merged2(leftpos))
    var rightdir = *(dirStruc.merged2(rightpos))
    var in_suffix = *"1filtered"
    var out_suffix = *"2crosscheck1"
    crosscheckDisparities(&leftdir, &rightdir, Int32(leftpos), Int32(rightpos), 1.0, 1, 1, &in_suffix, &out_suffix)
    
    // filter again, this can fill small holes of cross-checked regions
    for pos in [leftpos, rightpos] {
        var indispx = *(dirStruc.merged2(pos) + "/disp\(leftpos)\(rightpos)x-2crosscheck1.pfm")
        var outx = *(dirStruc.merged2(pos) + "/disp\(leftpos)\(rightpos)x-3filtered.pfm")
        filterDisparities(&indispx, nil, &outx, nil, Int32(leftpos), Int32(leftpos), -1, 0, 0, 20, 20)
    }
    
    // crosscheck one last time
    in_suffix = *"3filtered"
    out_suffix = *"4crosscheck2"
    crosscheckDisparities(&leftdir, &rightdir, Int32(leftpos), Int32(rightpos), 1, 1, 1, &in_suffix, &out_suffix)
}

func filterReliableReprojected(_ reprojDirs: [String], left leftpos: Int, right rightpos: Int) -> [String] {
    return reprojDirs.filter {
        let logFile = $0 + "/log\(leftpos)\(rightpos).txt"
        if(!FileManager.default.fileExists(atPath: logFile)){
            print("File \(logFile) doesn't exist")
            return false
        }
        let logLines: [String] = (try! String(contentsOfFile: logFile)).split(separator: "\n").map { return String($0) }
        let logTokens: [[String]] = logLines.map {
            return $0.split(separator: " ").map { return String($0) }
        }
        let logVals: [[Double]] = logTokens.map {
            return $0.filter {
                return Double($0) != nil
                }.map {
                    return Double($0)!
            }
        }
        let frac0 = logVals[0][0], frac1 = logVals[1][0]
        let rms0 = logVals[0][1], rms1 = logVals[1][1] // unused, old name: rms0
        let bad0 = logVals[0][2], bad1 = logVals[1][2]
        let thresh0 = logVals[0][3], thresh1 = logVals[1][3] // unused, old name: thresh0, thresh1
        let fracfrac = frac1 / frac0 // fraction of reproj frac vs orig frac
        
        let reliable = fracfrac >= 0.3 && frac1 >= 5 && bad0 <= 50 && bad1 <= 10 && rms1 <= 0.75
        print((reliable ? "reliable: " : "not reliable: ") + logFile )
        return reliable
    }
}

//MARK: misc
// concatenate unrectified u-decoded images at position pos with projector placements projs and write to a png
// used to help determine projector placement
func showShadows(projs: [Int32], pos: Int32) {
    var decodedDir = *dirStruc.decoded(false)
    var outDir: [CChar] = *dirStruc.shadowvis(pos: Int(pos))
    
    // convert projs Int32 array to a pointer so that it can be passed to the C
    var projs_: [Int32] = projs // first put it in another array bc parameter is let constant
    let projsPointer = UnsafeMutablePointer<Int32>.allocate(capacity: projs_.count) // allocate space for the pointer
    projsPointer.initialize(from: &projs_, count: projs_.count)
    
    writeShadowImgs( &decodedDir, &outDir, projsPointer, Int32(projs_.count), pos )
}

// Not sure what this is about -- Toby Weed, 8/20/20
func decodedImageHandler(_ decodedImPath: String, horizontal: Bool, projector: Int, position: Int) {
    /*
    let direction: Int = horizontal ? 1 : 0
    
    
    let outdir = dirStruc.subdir(dirStruc.refined, proj: projector, pos: position)
    let completionHandler: () -> Void = {
        let filepath = dirStruc.metadataFile(direction)
        do {
            let metadataStr = try String(contentsOfFile: filepath)
            let metadata: Yaml = try Yaml.load(metadataStr)
            if let angle: Double = metadata.dictionary?[Yaml.string("angle")]?.double {
                refineDecodedIm(swift2Cstr(outdir), horizontal ? 1:0, swift2Cstr(decodedImPath), angle)
            } else {
                print("refine error: could not load angle (double) from YML file.")
            }
        } catch {
            print("refine error: could not load metadata file.")
        }
    }
    photoReceiver.dataReceivers.insertFirst(
        SceneMetadataReceiver(completionHandler, path: dirStruc.metadataFile(direction))
    )
 */
}
