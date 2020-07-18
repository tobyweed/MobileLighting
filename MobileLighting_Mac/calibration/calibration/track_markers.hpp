//
//  track_markers.hpp
//  MobileLighting_Mac
//
//  Created by Toby Weed on 6/27/20.
//  Copyright © 2020 Nicholas Mosier. All rights reserved.
//

#ifndef track_markers_hpp
#define track_markers_hpp

#include <opencv2/imgproc.hpp>
#include <string>
#include <iostream>

using namespace cv;
using namespace std;

// Class for temporary storage of data extracted from calibration images. Eventually gets written to CalibrationData.
//  - each object represents the data from a single image
class ImgMarkers {
// Instance variables
public:
    vector<int> markerIds;
    vector<vector<Point2f>> markerCorners;
    vector<vector<int>> charucoIds;
    vector<vector<Point2f>> charucoCorners;
};

int trackCharucoMarkers(char **imageNames, int numImgs, char **boardPaths, int numBoards, void **calibrationDataStores);

#endif //track_markers_h
