//
//  MobileLighting_Mac-Bridging-Header.h
// 
//
//  Created by Nicholas Mosier on 6/28/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

#ifndef MobileLighting_Mac_Bridging_Header_h
#define MobileLighting_Mac_Bridging_Header_h

#include "Parameters.h"
#include <stdbool.h>

#include "activeLighting/activeLighting.h"
int calibrateWithSettings(char *settingspath);
void createSettingsIntrinsitcsChessboard(char *outputpath, char *imglistpath, char *templatepath);

#include "RobotControl/RobotControl/RobotControl.h"

int CalibrateWithSettings(const char *inputSettingsFile);
int DetectionCheck(char *inputSettingsFile, char *imleft, char *imright);

#include "calibration/calibration/wrapper.hpp"

#endif
