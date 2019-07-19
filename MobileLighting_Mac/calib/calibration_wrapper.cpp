//
//  calibwrapper.cpp
//  MobileLighting_Mac
//
//  Created by Nicholas Mosier on 6/15/18.
//  Copyright © 2018 Nicholas Mosier. All rights reserved.
//

#include <stdio.h>
#include <string>
#include <vector>

int calibrateWithSettings(std::string, bool isStereoMode);  // this is the function in calibrate.cpp
extern "C" int CalibrateWithSettings(const char *inputSettingsFile, bool isStereoMode) {   // this is the wrapped function for bridging to swift
    return calibrateWithSettings(std::string(inputSettingsFile), isStereoMode);
}

std::vector<int> detectionCheck(char *inputSettingsFilepath, char *imleftpath, char *imrightpath, bool isStereoMode);
extern "C" int DetectionCheck(char *inputSettingsFile, char *imleft, char *imright, bool isStereoMode) {
    std::vector<int> result = detectionCheck(inputSettingsFile, imleft, imright, isStereoMode);
    return -1;
}

//extern "C" int DetectionCheckIntrinsics(char *inputSettingsFile, char *imleft) {
//    std::vector<int> result = detectionCheck(inputSettingsFile, imleft, imright);
//    return -1;
//}
