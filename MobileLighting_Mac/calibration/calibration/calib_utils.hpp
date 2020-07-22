//
//  calib_utils.hpp
//  calibration
//
//  Created by Toby Weed on 7/2/20.
//  Copyright © 2020 Toby Weed. All rights reserved.
//

#ifndef calib_utils_hpp
#define calib_utils_hpp

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
    Board();
    Board(const FileNode& node);
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

// Class for storage of data extracted from calibration images before writing to disk.
//  - each object represents the data from several images.
//  - in practice, each object is used to store data from a set of images taken from a single pose.
class CalibrationData {
// Functions
public:
    // constructors
    CalibrationData(char *imgDirPath);
    CalibrationData(const FileStorage& fs);
    
    // load data extracted from one image to the storage object
    void loadData(string fname, vector<int> imgSize, vector<vector<Point2f>> imgPointsVector, vector<vector<Point3f>> objPointsVector, vector<vector<int>> idsVector);
    
// Instance variables
public:
    string imgDir;
    vector<string> fnames;
    vector<int> size;
    vector<vector<vector<Point2f>>> imgPoints;
    vector<vector<vector<Point3f>>> objPoints;
    vector<vector<vector<int>>> ids;
};

Ptr<aruco::Dictionary> chDict(string dictString);
Ptr<aruco::CharucoBoard> convertBoardToCharuco(Board b);
Board readBoardFromFile(string filePath);
CalibrationData readCalibDataFromFile(string filePath);
const void *initializeCalibDataStorage(char *imgDirPath);
void saveCalibDataToFile(char *filePath, void *calibrationData);


template <typename T> // templates need to be defined in the header file to be portable
vector<T> extractVector( const FileNode& array ) {
    vector<T> output;
    for( int i = 0; i < array.size(); i++ ) {
        output.push_back( array[i] );
    }
    return output;
};
vector<vector<Point2f>> extractImgPoints( const FileNode& array );
vector<vector<Point3f>> extractObjPoints( const FileNode& array );
vector<vector<int>> extractIds( const FileNode& array );
Mat extractMatrix( const FileNode& array );
vector<Mat> extractMatVector( const FileNode& array );

void saveCameraParamsToFile(string filePath, vector<Mat> R, vector<Mat> T, Mat A, Mat dist, Size size, double err);
void saveExtrinsicsToFile(string filePath, Mat R, Mat T, Mat E, Mat F, double err);


#endif /* calib_utils_hpp */
