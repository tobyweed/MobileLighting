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

using namespace cv;
using namespace std;

// Class for storage of data extracted from calibration of images before writing to disk.
class CalibrationData {
public:
    CalibrationData(char *imgDirPath) { // constructor
        imgDir = imgDirPath;
    };
    
    // load data extracted from one image to the storage object
    void loadData(string fname, vector<int> imgSize, vector<vector<Point2f>> imgPointsVector, vector<vector<Point3f>> objPointsVector, vector<vector<int>> idsVector) {
        fnames.push_back(fname);
        size = imgSize;
        imgPoints.push_back(imgPointsVector);
        objPoints.push_back(objPointsVector);
        ids.push_back(idsVector);
    };

    char *imgDir;
    vector<string> fnames;
    vector<int> size;
    vector<vector<vector<Point2f>>> imgPoints;
    vector<vector<vector<Point3f>>> objPoints;
    vector<vector<vector<int>>> ids;
};

int trackCharucoMarkers(char *image, char **boardPaths, int numBoards, void *calibrationData);

#endif //track_markers_h
