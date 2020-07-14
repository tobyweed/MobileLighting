//
//  calib_utils.hpp
//  calibration
//
//  Created by Toby Weed on 7/2/20.
//  Copyright © 2020 Toby Weed. All rights reserved.
//

#ifndef calib_utils_hpp
#define calib_utils_hpp

#include "track_markers.hpp"
#include <opencv2/aruco/charuco.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/imgcodecs.hpp>
#include <iostream>
#include <string>

using namespace cv;
using namespace std;

// Intermediary class for managing ChArUco boards, especially loading their information from Yaml files
class Board {
public: // Functions
    void write(FileStorage& fs) const;
    void read(const FileNode& node);
public: // Parameters
    string description;
    int squares_x;
    int squares_y;
    double square_size_mm;
    double marker_size_mm;
    double board_width_mm;
    double board_height_mm;
    string dict;
    int start_code;
};


Ptr<aruco::Dictionary> chDict(string dictString);
Ptr<aruco::CharucoBoard> convertBoardToCharuco(Board b);
Board readBoardFromFile(string filePath);
CalibrationData readCalibDataFromFile(string filePath);
const void *initializeCalibDataStorage(char *imgDirPath);
void saveCalibDataToFile(char *filePath, void *calibrationData);

#endif /* calib_utils_hpp */
