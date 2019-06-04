//
// BinaryCodes.swift
// MobileLighting
//
// Contains functions for loading, manipulating, and interpreting binary codes for structured
//  lighting
//

import Foundation

enum BinaryCodeSystem: Int {
    case GrayCode, MinStripeWidthCode
}

func grayCodeArray(forBit bit: Int, size: Int) -> [Bool] {
    var array = [Bool]()
    array.reserveCapacity(Int(size))
    
    for i in 0..<size {
        array.append(getBit(encodeGrayCode(of: i), bit: bit))
    }
    return array
}

func encodeGrayCode(of pos: Int) -> Int {
    return pos ^ (pos >> 1)
}

// algorithm from http://www.cs.brandeis.edu/~storer/JimPuzzles/MANIP/ChineseRings/READING/GrayCodesWikipedia.pdf, pg. 6
func decodeGrayCode(of code: UInt32) -> UInt32 {
    var pos: UInt32 = code
    var ish: UInt32 = 1
    var idiv: UInt32
    
    while true {
        idiv = pos >> ish
        pos ^= idiv
        if idiv <= 1 || ish == 32 {
            return pos
        }
        ish <<= 1
    }
    
}

func getBit(_ n: Int, bit: Int) -> Bool {
    return (n & (1 << bit)) != 0
}


/* =================================================================================================
 * Functions to load Min Stripe Width Binary Codes from minSW.dat
 =================================================================================================*/
// VARIABLES
var minSWcodeBitDisplayArrays: [[Bool]]? // contains minstripewidth code bit arrays from minsSWcode.dat
var minSW_ncodes: UInt32? // The number of 4-byte minSW codes
var minSW_posToCode: [UInt32]? = nil // Each UInt32 entry represents an array of bits, which represent minstripewidth codes
var minSW_codeToPos: [UInt32]? = nil // What is this for??


// FUNCTIONS
// Convert UInt32 min stripe width binary codes to bit array min stripe width binary codes for display
func loadMinStripeWidthCodesForDisplay(filepath: String, bitCount: Int = 10) throws {
    try loadMinSWCodesConversionArrays(filepath: filepath)
    
    minSWcodeBitDisplayArrays = [[Bool]]()
    minSWcodeBitDisplayArrays!.reserveCapacity(bitCount)
    
    // Convert array of UInt32's to array of arrays of bits
    for bit in 0..<bitCount {
        var codeArray = [Bool]()
        codeArray.reserveCapacity(Int(minSW_ncodes!))
        for i in 0..<Int(minSW_ncodes!) {
            let codeBool = (minSW_posToCode![i] & (1<<UInt32(bit)) != 0)
            codeArray.append(codeBool)
        }
        minSWcodeBitDisplayArrays!.append(codeArray)
    }
}

// Populate an array of UInt32's representing  min stripe width binary codes from minSW.dat
func loadMinSWCodesConversionArrays(filepath: String) throws {
    let fileURL = URL(fileURLWithPath: filepath) // Get the URL (Foundation struct) of minSW.dat, which contains the binary codes
    let codeData = try Data(contentsOf: fileURL) // Convert the contents of minSW.dat to a byte buffer of struct Data
    print("BinaryCodes: successfully loaded min strip width code data.")
    
    minSW_ncodes = codeData.withUnsafeBytes { // Call the closure and return its value
        UnsafePointer<UInt32>($0).pointee // Returns the number of uint32s stored in the byte buffer of codeData
    }
    
    guard minSW_ncodes == 1024 else { // Make sure we have the right number of codes
        fatalError("BinaryCodes: fatal error — read # of min sw codes incorrectly.")
    }
    
    minSW_posToCode = codeData.advanced(by: 4).withUnsafeBytes { // Skip the first 4 bytes, which specify the number of codes
        [UInt32](UnsafeBufferPointer(start: $0, count: Int(minSW_ncodes!))) // Read the byte buffer and convert it to an array of UInt32
    }
    
    
    // What is this?
    minSW_codeToPos = codeData.advanced(by: 4 + Int(minSW_ncodes!)*4).withUnsafeBytes {
        [UInt32](UnsafeBufferPointer(start: $0, count: Int(minSW_ncodes!))) // Read the byte buffer and convert it to an array of UInt32
    }
}
