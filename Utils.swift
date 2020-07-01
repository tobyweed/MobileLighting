//
// Utils.swift
// MobileLighting
//
// Utility functions
//

import Foundation
import CoreVideo
import CoreMedia
import Yaml


/*=====================================================================================
 String operators & extensions to support passing of [CChar]s to C
 ======================================================================================*/
 
// properly add C strings together (removes null byte from first)
func +(left: [CChar], right: [CChar]) -> [CChar] {
    var result = [CChar](left.dropLast())
    result.append(contentsOf: right)
    return result
}

extension Collection {
    // Convert an array to an <UnsafeMutablePointer<Int8>? (note the '?' denoting Optional value)
    public func unsafeCopy() -> UnsafeMutablePointer<Self.Element>? {
        let copy = UnsafeMutablePointer<Self.Element>.allocate(capacity: self.underestimatedCount)
        _ = copy.initialize(from: self)
        return copy
    }
}

// Convert String to [CChar]
prefix operator *
extension String {
    static prefix func * (swiftString: String) -> [CChar] {
        return swiftString.cString(using: .ascii)!
    }
}

// Convert [String] to [[CChar]]
prefix func * (swiftStringArray: [String]) -> [[CChar]] {
    return swiftStringArray.map {
        return *$0
    }
}

// Convert [[CChar]] to [UnsafeMutablePointer<Int8>?]
prefix operator **
prefix func ** (cStringArray: inout [[CChar]]) -> [UnsafeMutablePointer<CChar>?] {
    var ptrs = [UnsafeMutablePointer<CChar>?]()
    for i in 0..<cStringArray.count { ptrs.append(getptr(&cStringArray[i])) }
    return ptrs
}

func pathExists(_ path: String) -> Bool {
    return FileManager.default.fileExists(atPath: path);
}

enum PathError: Error {
    case invalidPath
}

func safePath(_ path: String) throws -> [CChar] {
    if(!pathExists(path)) {
        print( "path \(path) does not exist." )
        throw PathError.invalidPath
    }
    return *path
}


/*=====================================================================================
 Misc
 ======================================================================================*/

func makeDir(_ str: String) -> Void {
    do {
        try FileManager.default.createDirectory(atPath: str, withIntermediateDirectories: true, attributes: nil)
    } catch {
        print("make dir - error - could not make directory.")
    }
}

func getptr<T>(_ obj: inout [T]) -> UnsafeMutablePointer<T>? {
    return UnsafeMutablePointer<T>(&obj)
}

// get an array of Integers from an array of paths "strs" to files or directories with the format [prefix]x[suffix]
func getIDs(_ strs: [String], prefix: String, suffix: String) -> [Int] {
    return strs.map { // convert the array to contain only the filenames (not whole paths)
        return String($0.split(separator: "/").last!)
        }.map { // collect all the IDs, returning nil for all files not in the format [prefix]x[suffix]
            guard $0.hasPrefix(prefix), $0.hasSuffix(suffix) else {
                return nil
            }
            let base = $0.dropFirst(prefix.count).dropLast(suffix.count)
            return Int(base)
        }.filter{ // remove nil values from array
            return $0 != nil
        }.map{ return $0!}
}

let lockFlags = CVPixelBufferLockFlags(rawValue: 0) // read & write

// because the Swift standard library doesn't have a built-in linked list class,
// I wrote a minimalistic one. i'll add to it as needed
class List<T> {
    private class ListNode<T> {
        var head: T
        var tail: ListNode<T>?
        var parent: ListNode<T>?
        
        init(head: T, tail: ListNode<T>? = nil, parent: ListNode<T>? = nil) {
            self.head = head
            self.tail = tail
            self.parent = parent
            
            tail?.parent = self
            parent?.tail = self
        }
    }
    
    var count: Int = 0
    private var _first: ListNode<T>? = nil
    private weak var _last: ListNode<T>? = nil
    
    var first: T? {
        get {
            return _first?.head
        }
        set {
            guard let newValue = newValue else {
                return
            }
            _first?.head = newValue
        }
    }
    var last: T? {
        get {
            return _last?.head
        }
        set {
            guard let newValue = newValue else {
                return
            }
            _last?.head = newValue
        }
    }
    
    func insertFirst(_ obj: T) {
        _first = ListNode<T>(head: obj, tail: _first)
        _last = _last ?? _first
    }
    
    func popLast() -> T? {
        let value = _last?.head
        if _first === _last {
            _first = nil
            _last = nil
        } else {
            _last = _last?.parent
            _last?.tail = nil
        }
        return value
    }
    
    func removeAll() {
        self._first = nil
        self._last = nil
    }
}

// empty directory
func removeFiles(dir: String) -> Void {
    guard let paths = try? FileManager.default.contentsOfDirectory(atPath: dir) else {
        print("Could not remove files at directory \(dir).")
        return
    }
    for path in paths {
        do { try FileManager.default.removeItem(atPath: "\(dir)/\(path)") }
        catch let error { print(error.localizedDescription) }
    }
}

// divide command tokens into params and flags
func partitionTokens(_ tokens: [String]) -> ([String], [String]) {
    let params = tokens.filter { return !$0.starts(with: "-") }
    let flags = tokens.filter { return $0.starts(with: "-") }
    return (params, flags)
}

// expects string in format [1,2,3,4
// converts to array of integers
// used for supporting arrays as command line arguments
func stringToIntArray(_ string: String ) -> [Int] {
    // initialize an array of the connected ports on the switcher.
    let startlist = string.index(string.startIndex, offsetBy: 1)
    var liststr = string.dropFirst()// cut off the first character
    // if last character is ], cut it off too
    // this isn't a requirement because Xcode will sometimes automatically appear to add "]" without actially doing so
    if( string.hasSuffix("]") ) {
        liststr = liststr.dropLast()
    }
    let strArray = liststr.components(separatedBy: ",") // divide string into array by ","
    let intArray = strArray.map { Int($0) } // convert [String] to [Int?]
    // convert [Int?] to [Int], filtering nil values
    var filteredArray: [Int] = []
    for int in intArray {
        int != nil ? filteredArray.append(int!) : ()
    }
    return filteredArray
}

extension CMTime {
    init(exposureDuration: Double) {
        let prefferedExposureDurationTimescale: CMTimeScale = 1000000
        self.init(seconds: exposureDuration, preferredTimescale: prefferedExposureDurationTimescale)
    }
}

// from https://stackoverflow.com/questions/32952248/get-all-enum-values-as-an-array
// temporary implementation of getting all cases of an Enum
// this can be replaced by CaseIterable protocol once Swift 4.2 and Xcode 10 are released (this summer 2018, I think)
protocol EnumCollection : Hashable {}
extension EnumCollection {
    static func cases() -> AnySequence<Self> {
        typealias S = Self
        return AnySequence { () -> AnyIterator<S> in
            var raw = 0
            return AnyIterator {
                let current : Self = withUnsafePointer(to: &raw) { $0.withMemoryRebound(to: S.self, capacity: 1) { $0.pointee }
                }
                guard current.hashValue == raw else { return nil }
                raw += 1
                return current
            }
        }
    }
}
extension String {
    subscript (i: Int) -> Character {
        return self[index(startIndex, offsetBy: i)]
    }
}

extension Dictionary where Key == Yaml, Value == Yaml {
    subscript (_ string: String) -> Yaml? {
        let key = Yaml.string(string)
        return self[key]
    }
}
