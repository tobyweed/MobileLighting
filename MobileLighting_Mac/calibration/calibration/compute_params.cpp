//
//  compute_params.cpp
//  calibration
//
//  Created by Toby Weed on 7/11/20.
//  Copyright © 2020 Toby Weed. All rights reserved.
//

#include "calib_utils.hpp"
#include "track_markers.hpp"
#include "compute_params.hpp"

#include <stdio.h>
#include <opencv2/calib3d.hpp>
#include <opencv2/core.hpp>
#include <cstdio>

using namespace cv;
using namespace std;

int computeIntrinsics ( char *trackFile, char *outputDirectory ) {
    int output = -1;
    
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
    
    cout << "\nFiltering input points";
    // at least 4 points are required by the function, but use a minimum of 10 for stability
    vector<vector<Point2f>> filteredImgPoints;
    vector<vector<Point3f>> filteredObjPoints;
    // copy each vector entry with more than 9 points
    copy_if( calibData.imgPoints[0].begin(), calibData.imgPoints[0].end(), back_inserter(filteredImgPoints), [](vector<Point2f> imgVector) { return (imgVector.size() >= 10); } );
    copy_if( calibData.objPoints[0].begin(), calibData.objPoints[0].end(), back_inserter(filteredObjPoints), [](vector<Point3f> imgVector) { return (imgVector.size() >= 10); } );
    
    cout << "\nFinding calibration matrices";
    double err = calibrateCamera( filteredObjPoints, filteredImgPoints, size, cameraMatrix, distCoeffs, rvecs, tvecs );
    
    cout << "\ncameraMatrix: " << cameraMatrix <<"\n";
    cout << "\ndistCoeffs: " << distCoeffs <<"\n";
    cout << "\nreprojection err: " << err <<"\n";
    
    // convert to string to concatenate the correct output path
    string outputDir(outputDirectory);
    string outputPath = outputDir + "/intrinsics.json";
    
    saveCameraParamsToFile(outputPath, rvecs, tvecs, cameraMatrix, distCoeffs, size);
    
    return output;
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
    if( argc != 3 ) {
        cout << "usage: " << argv[0] <<" <inputfilename> <outputfilename>\n";
    }
    computeIntrinsics( (char*)"/Users/tobyweed/workspace/sandbox_scene/orig/calibration/intrinsics/intrinsics-track.json", (char*)"/Users/tobyweed/workspace/sandbox_scene/orig/calibration/intrinsics" );
//    computeIntrinsics( argv[1], argv[2] );
}


