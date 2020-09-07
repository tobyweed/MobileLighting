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

// Takes an array of tokens, returns a tuple of arrays representing the projectors (1st array) and positions (2nd array)
//  that the flags indicate using
func getProjs(tokens: [String], usage: String, inputDir: String) -> [Int] {
    let (params, flags) = partitionTokens(tokens)

    let numAs = countAFlags(flags: flags)

    // determine whether/how many -a flags were used
    var allproj = false
    if (flags.count == 1 || flags.count == 2) {
        allproj = true
    } else if (flags.count != 0) {
        print("Unrecognized number of flags \(flags.count)")
        print(usage)
        return []
    }

    var projs = [Int]()
    if (allproj) {
        let projDirs = try! FileManager.default.contentsOfDirectory(atPath: inputDir)
        projs = getIDs(projDirs, prefix: "proj", suffix: "")
    } else {
        // make sure we have an array of projectors or a single projector as the second token
        guard(params.count >= 2) else {
            print("Not enough arguments")
            print(usage)
            return []
        }
        if params[1].hasPrefix("[") {
            projs = stringToIntArray(params[1])
        } else if Int(params[1]) != nil {
            projs.append(Int(params[1])!)
        } else {
            print("Missing projector position(s)")
            print(usage)
            return []
        }
    }
    return projs
}

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
func getPosPairsFromParams(params: [String], inputDir: String, prefix: String, suffix: String) -> [(Int,Int)] {
    // make sure we have an array of projectors or a single projector as the second token
    guard (params.count >= 3) else {
        print("Not enough arguments")
        return []
    }
    var pos1 = [Int]()
    var pos2 = [Int]()
    if (params[1].hasPrefix("[") && params[2].hasPrefix("[")) {
        pos1 = stringToIntArray(params[1])
        pos2 = stringToIntArray(params[2])
    } else if (Int(params[1]) != nil && Int(params[2]) != nil) {
        pos1.append(Int(params[1])!)
        pos2.append(Int(params[2])!)
    } else {
        print("Bad input, no projector positions initialized")
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



// Takes an array of tokens, returns a tuple of arrays representing the projectors (1st array) and positions (2nd array)
//  that the flags indicate using
func getPosPairs(tokens: [String], usage: String, inputDir: String, useproj: Bool) -> ([Int],[Int]) {
    let (params, flags) = partitionTokens(tokens)

    for flag in flags {
        if(flag != "-a") {
            print("Unrecognized flag \(flag)")
            return ([],[])
        }
    }

    // determine whether/how many -a flags were used
    var allpos = false
    if (flags.count == 1 && !useproj || flags.count == 2) {
        allpos = true
    } else if (flags.count > 2) {
        print("Unrecognized number of flags \(flags.count)")
        print(usage)
        return ([],[])
    }

    var pos1 = [Int]()
    var pos2 = [Int]()
    if (allpos) {
        let posDirs = try! FileManager.default.contentsOfDirectory(atPath: inputDir)
        let allpos = getIDs(posDirs, prefix: "pos", suffix: "").sorted()
        pos1 = Array(allpos[0..<(allpos.count-1)])
        pos2 = Array(allpos[1..<(allpos.count)])
        print("pos1: \(pos1)")
        print("pos2: \(pos2)")
    } else {
        // make sure we have an array of projectors or a single projector as the second token
        guard (params.count >= 3) else {
            print("Not enough arguments")
            print(usage)
            return ([],[])
        }
        if (params[1].hasPrefix("[") && params[2].hasPrefix("[")) {
            pos1 = stringToIntArray(params[1])
            pos2 = stringToIntArray(params[2])
        } else if (Int(params[1]) != nil && Int(params[2]) != nil) {
            pos1.append(Int(params[1])!)
            pos2.append(Int(params[2])!)
        } else {
            print("Missing projector position(s)")
            print(usage)
            return ([],[])
        }
    }
    guard pos1.count == pos2.count else {
        print("Each position array must have the same length.")
        return ([],[])
    }
    return (pos1,pos2)
}

//func getProjPos(tokens: [String], useproj: Bool, usage: String) -> Bool {
//    let (params, flags) = partitionTokens(tokens)
//
//    for flag in flags {
//        if(flag != "-a") {
//            print("Unrecognized flag \(flag)")
//            return false
//        }
//    }
//
//    // determine whether/how many -a flags were used
//    var (allproj, allpos) = (false, false)
//    if(flags.count == 2 && useproj) {
//        (allproj, allpos) = (true,true)
//    } else if(flags.count == 1) {
//        if(useproj) {
//            (allproj, allpos) = (true,false)
//        } else {
//            (allproj, allpos) = (false,true)
//        }
//    } else if(flags.count == 0) {
//        (allproj, allpos) = (false,false)
//    } else {
//        print("Unrecognized number of flags \(flags.count)")
//        print(usage)
//        return false
//    }
//
//    // get the projector positions from the directory that will be used as input
//    func getprojs(inputDir: String) -> [Int] {
//        var projs = [Int]()
//        if(useproj) {
//            if(allproj) {
//                let projDirs = try! FileManager.default.contentsOfDirectory(atPath: inputDir)
//                projs = getIDs(projDirs, prefix: "proj", suffix: "")
//            } else {
//                // make sure we have an array of projectors or a single projector as the second token
//                guard(params.count >= 2) else {
//                    print("Not enough arguments")
//                    print(usage)
//                    return []
//                }
//                if params[1].hasPrefix("[") {
//                    projs = stringToIntArray(params[1])
//                } else if Int(params[1]) != nil {
//                    projs.append(Int(params[1])!)
//                } else {
//                    print("Missing projector position(s)")
//                    print(usage)
//                    return []
//                }
//            }
//        }
//        return projs
//    }
//
//    let projs = getprojs(inputDir: dirStruc.decoded(true))
//    if useproj && projs.count <= 0 {
//        print("No projectors to be processed")
//        return false
//    }
//
//    func getpos(inputDir: String) -> [Int] {
//        var pos = [Int]()
//        if(allpos) {
//            let projDirs = try! FileManager.default.contentsOfDirectory(atPath: inputDir)
//            pos = getIDs(projDirs, prefix: "pos", suffix: "")
//        } else {
//            // make sure we have an array of positions or a single position as the second token
//            print(params[0])
//            if params[0].hasPrefix("[") {
//                projs = stringToIntArray(params[0])
//            } else if Int(params[0]) != nil {
//                projs.append(Int(params[0])!)
//            } else {
//                print("Missing projector position(s)")
//                print(usage)
//                return []
//            }
//        }
//    }
    
    
//    switch tokens[0] {
//    case "processpairs":
//        break
//    default:
//        break
//    }
//

func runAllProcessing() {
    if !getintrinsics() { return }
    
    
}

// compute extrinsics (left, right)
// -a: all adjacent pairs

// rectify decoded (left, right)
// -a: all adjacent pairs for which we have extrinsics & decoded images

// rectify amb (left, right)
// -a: all adjacent

// refine (projectors, position pairs)
// -a: all projectors
// -a: all position pairs for which there are rectified decoded images

// disparity (projs, pos pairs)
// -a: all projectors
// -a: all position pairs for which there are refined decoded images

// merge (pos pairs)
// -a: all position pairs for which there are disparities

// reproject (proj, pos pairs)
// -a: all projectors
// -a: all position pairs for which there are merged images

// merge2 (pos pairs)
// -a: all position pairs for which there are reprojected images
































//MARK: disparity matching
// uses bridged C++ code from image processing pipeline
// NOTE: this decoding step is not yet automated; it must manually be executed from
//    the main command-line user input loop

// computes & saves disparity maps for images of the given image position pair taken with the given projector
// NOW: also refines disparity maps
func disparityMatch(proj: Int, leftpos: Int, rightpos: Int, rectified: Bool) {
    var refinedDirLeft: [CChar], refinedDirRight: [CChar]
    refinedDirLeft = *dirStruc.decoded(proj: proj, pos: leftpos, rectified: rectified)
    refinedDirRight = *dirStruc.decoded(proj: proj, pos: rightpos, rectified: rectified)
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
    crosscheckDisparities(&disparityDirLeft, &disparityDirRight, l, r, 0.5, 0, 0, &in_suffix, &out_suffix)
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
    crosscheckDisparities(&disparityDirLeft, &disparityDirRight, l, r, 0.5, 1, 0, &in_suffix, &out_suffix)
}


//MARK: rectification
//rectify decoded images
func rectifyDec(left: Int, right: Int, proj: Int) {
    var intr = *dirStruc.intrinsicsJSON
    var extr = *dirStruc.extrinsicsJSON(left: left, right: right)
    var settings = *dirStruc.calibrationSettingsFile
    //paths for storing output
    let rectdirleft = dirStruc.decoded(proj: proj, pos: left, rectified: true)
    let rectdirright = dirStruc.decoded(proj: proj, pos: right, rectified: true)
    //paths for retreiving input
    var result0l: [CChar]
    var result0r: [CChar]
    var result1l: [CChar]
    var result1r: [CChar]
    do {
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
//    var positionDirs: [(String, String)] = projectorDirs.map {
//        return ("\($0)/pos\(leftpos)", "\($0)/pos\(rightpos)")
//    }
    var pfmPathsLeft, pfmPathsRight: [(String, String)]
    if rectified {
        pfmPathsLeft = positionDirs.map {
            return ("\($0.0)/disp\(leftpos)\(rightpos)x-3crosscheck2.pfm", "\($0.0)/disp\(leftpos)\(rightpos)y-3crosscheck2.pfm")
        }
        pfmPathsRight = positionDirs.map {
            return ("\($0.1)/disp\(leftpos)\(rightpos)x-3crosscheck2.pfm", "\($0.1)/disp\(leftpos)\(rightpos)y-3crosscheck2.pfm")
        }
    } else {
        pfmPathsLeft = positionDirs.map {
            return ("\($0.0)/disp\(leftpos)\(rightpos)x-1crosscheck1.pfm", "\($0.0)/disp\(leftpos)\(rightpos)y-1crosscheck1.pfm")
        }
        pfmPathsRight = positionDirs.map {
            return ("\($0.1)/disp\(leftpos)\(rightpos)x-1crosscheck1.pfm", "\($0.1)/disp\(leftpos)\(rightpos)y-1crosscheck1.pfm")
        }
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
//    var leftout = dirStruc.merged(pos: leftpos, rectified: rectified).cString(using: .ascii)!
    if rectified {
        outx = (dirStruc.merged(pos: leftpos, rectified: rectified) + "/disp\(leftpos)\(rightpos)x-0initial.pfm").cString(using: .ascii)!
        outy = (dirStruc.merged(pos: leftpos, rectified: rectified) + "/disp\(leftpos)\(rightpos)y-0initial.pfm").cString(using: .ascii)!
    } else {
        outx = (dirStruc.merged(pos: leftpos, rectified: rectified) + "/disp\(leftpos)\(rightpos)x.pfm").cString(using: .ascii)!
        outy = (dirStruc.merged(pos: leftpos, rectified: rectified) + "/disp\(leftpos)\(rightpos)y.pfm").cString(using: .ascii)!
    }
    
    let mingroup: Int32 = 2
    let maxdiff: Float = 1.0
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
//    var rightout = dirStruc.merged(pos: rightpos, rectified: rectified).cString(using: .ascii)!
//    mergeDisparities(&imgsx, &imgsy, &rightout, Int32(imgsx.count), mingroup, maxdiff)
    mergeDisparities(&imgsx, &imgsy, &outx, &outy, Int32(imgsx.count), mingroup, maxdiff)
    
    if rectified {
        var posdir0 = dirStruc.merged(pos: leftpos, rectified: true).cString(using: .ascii)!
        var posdir1 = dirStruc.merged(pos: rightpos, rectified: true).cString(using: .ascii)!
        let l = Int32(leftpos)
        let r = Int32(rightpos)
        let thresh: Float = 0.5
        let xonly: Int32 = 1
        let halfocc: Int32 = 0
        var in_suffix = "0initial".cString(using: .ascii)!
        var out_suffix = "1crosscheck".cString(using: .ascii)!
        crosscheckDisparities(&posdir0, &posdir1, l, r, thresh, xonly, halfocc, &in_suffix, &out_suffix)
    }
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
