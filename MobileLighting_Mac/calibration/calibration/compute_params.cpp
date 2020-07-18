//
//  compute_params.cpp
//  calibration
//
//  Created by Toby Weed on 7/11/20.
//  Copyright © 2020 Toby Weed. All rights reserved.
//

#include "calib_utils.hpp"
#include "compute_params.hpp"

#include <stdio.h>
#include <opencv2/calib3d.hpp>
#include <opencv2/core.hpp>
#include <cstdio>

using namespace cv;
using namespace std;

class Intrinsics {
// Functions
public:
    Intrinsics(const FileStorage& fs) { // initialize an object from a track file
        R = extractMatVector(fs["R"]);
        T = extractMatVector(fs["T"]);
        A = extractMatrix(fs["A"]);
        dist = extractMatrix(fs["dist"]);
        size = Size(fs["size"][0],fs["size"][1]);
    };

// Instance variables
public:
    vector<Mat> R, T;
    Mat A,dist;
    Size size;
};

Intrinsics readIntrinsicsFromFile( string filePath ) {
    FileStorage fs;
    fs.open(filePath, FileStorage::READ);
    if (!fs.isOpened())
    {
        cerr << "Failed to open " << filePath << endl;
        exit (EXIT_FAILURE);
    }
    Intrinsics data(fs);
    return data;
}

int computeExtrinsics ( char *trackFile1, char *trackFile2, char *intrinsicsFile, char *outputDirectory ) {
    cout << "\nComputing extrinsics\n";
    
    CalibrationData calibData1 = readCalibDataFromFile(trackFile1);
    CalibrationData calibData2 = readCalibDataFromFile(trackFile2);
    Intrinsics intrinsics = readIntrinsicsFromFile(intrinsicsFile);
    
    cout << "\nFiltering image and object points";
    // at least 4 points are required by the function, but use a minimum of 10 for stability
    vector<vector<Point3f>> filteredObjPoints;
    vector<vector<Point2f>> filteredImgPoints1;
    vector<vector<Point2f>> filteredImgPoints2;
    // copy each vector entry with 10 or more points
    copy_if( calibData1.imgPoints[0].begin(), calibData1.imgPoints[0].end(), back_inserter(filteredImgPoints1), [](vector<Point2f> imgVector) { return (imgVector.size() >= 10); } );
    copy_if( calibData2.imgPoints[0].begin(), calibData2.imgPoints[0].end(), back_inserter(filteredImgPoints2), [](vector<Point2f> imgVector) { return (imgVector.size() >= 10); } );
    copy_if( calibData1.objPoints[0].begin(), calibData1.objPoints[0].end(), back_inserter(filteredObjPoints), [](vector<Point3f> imgVector) { return (imgVector.size() >= 10); } );
    
    Mat R, T, E, F;
    
    double err = stereoCalibrate(filteredObjPoints, filteredImgPoints1, filteredImgPoints2, intrinsics.A, intrinsics.dist, intrinsics.A, intrinsics.dist, intrinsics.size, R, T, E, F, CALIB_FIX_INTRINSIC, TermCriteria(TermCriteria::MAX_ITER+TermCriteria::EPS, 1000, 1e-10));
    
    cout << "\nStereo reprojection error: " << err << endl;
    cout << "\n R: " << R << endl;
    cout << "\n T: " << T << endl;
    
    return 0;
}

// Filter a vector of vectors s.t. each vector contained by the ouput vector has at least 10 elements
template <typename T>
vector<vector<T>> filterPointsVectorsByMinSize( vector<vector<T>> points ) {
    vector<vector<T>> filteredPoints;
    copy_if( points.begin(), points.end(), back_inserter(filteredPoints), [](vector<T> pointsVector) { return (pointsVector.size() >= 10); } );
    return filteredPoints;
}
//
//template <typename T>
//void getSharedPoints( vector<vector<int>> ids1, vector<vector<int>> ids2, vector<vector<T>> points1, vector<vector<T>> points2, vector<vector<T>> &out1, vector<vector<T>> &out2 ) {
//    // create a new list which is the intersection of ids1 & ids2
//    
//}

// Filter the image and object points of given CalibrationData objects to contain only points which are shared and lists of points with at least 10 elements
//void filterPoints( CalibrationData &calibrationData1, CalibrationData &data2) {
//    CalibrationData *data1 = (CalibrationData *)calibrationData1;
//
//}

//void filterPoints( vector<vector<int>> ids1, vector<vector<int>> ids2, vector<vector<Point2f>> imgPoints1, vector<vector<Point2f>> imgPoints2, vector<vector<Point3f>> objPoints1, vector<vector<Point3f>> objPoints2,)

// Intrinsics
int computeIntrinsics ( char *trackFile, char *outputDirectory ) {
    cout << "\nComputing intrinsics\n";
    
    CalibrationData calibData = readCalibDataFromFile(trackFile);
    
    if (calibData.objPoints.size() <= 0) { // check how many arrays of object points we have
        cout << "\nThe number of detected images is " << calibData.objPoints.size() << "\n";
        cout << "\nUnable to calibrate due to invalid number of object points. Exiting.";
        return -1;
    }
    
    Mat cameraMatrix, distCoeffs;
    vector<Mat> rvecs, tvecs;
    Size size(calibData.size[0],calibData.size[1]);
    
    cout << "\nFiltering image and object points";
    vector<vector<Point2f>> filteredImgPoints = filterPointsVectorsByMinSize<Point2f>(calibData.imgPoints[0]);
    vector<vector<Point3f>> filteredObjPoints = filterPointsVectorsByMinSize<Point3f>(calibData.objPoints[0]);;
    
    cout << "\nFinding calibration matrices";
    double err = calibrateCamera( filteredObjPoints, filteredImgPoints, size, cameraMatrix, distCoeffs, rvecs, tvecs );
    
    cout << "\ncameraMatrix: " << cameraMatrix <<"\n";
    cout << "\ndistCoeffs: " << distCoeffs <<"\n";
    cout << "\nreprojection err: " << err <<"\n";
    
    // convert to string to concatenate the correct output path
    string outputDir(outputDirectory);
    string outputPath = outputDir + "/intrinsics.json";
    
    saveCameraParamsToFile(outputPath, rvecs, tvecs, cameraMatrix, distCoeffs, size);
    
    return 0;
}

// Write a file from the CalibrationData objects generated from calibration images
void saveCameraParamsToFile(string filePath, vector<Mat> R, vector<Mat> T, Mat A, Mat dist, Size size) {
    FileStorage fs(filePath, FileStorage::WRITE);
    if (!fs.isOpened())
    {
        cerr << "Failed to open " << filePath << endl;
        exit (EXIT_FAILURE);
    }
    cout << "Writing to file " << filePath << endl;
    
    fs << "R" << R;
    fs << "T" << T;
    fs << "A" << A;
    fs << "dist" << dist;
    fs << "size" << size;

    fs.release();
    cout << "Write Done." << endl;
}

int main( int argc, const char* argv[] )
{
    if( argc != 3 ) { // update this when final usage is figured out
        cout << "usage: " << argv[0] <<" <inputfilename> <outputfilename>\n";
    }
    computeIntrinsics( (char*)"/Users/tobyweed/workspace/sandbox_dir/intrinsics-track.json", (char*)"/Users/tobyweed/workspace/sandbox_dir" );
    
    cout << "\nEXTRINSICS: " << endl;
    
    computeExtrinsics((char*)"/Users/tobyweed/workspace/sandbox_dir/intrinsics-track.json", (char*)"/Users/tobyweed/workspace/sandbox_dir/intrinsics-track.json", (char*)"/Users/tobyweed/workspace/sandbox_dir/intrinsics.json", (char*)"/Users/tobyweed/workspace/sandbox_dir/");
//    computeIntrinsics( argv[1], argv[2] );
}


