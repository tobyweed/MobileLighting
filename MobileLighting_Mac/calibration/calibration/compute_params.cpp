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

Mat extractMatrix( const FileNode& array ) {
    int rows = array.size();
    int cols = array[0].size();
    Mat m = Mat( rows, cols, CV_32F );
    for(int i = 0; i < rows; i++) {
        for(int j = 0; j < cols; j++) {
            m.at<float>(i,j) = array[i][j].real();
        }
    }
    return m;
}

// Extract a vector of matrices
vector<Mat> extractMatVector( const FileNode& array ) {
    vector<Mat> output;
    for( int i = 0; i < array.size(); i++ ) {
        output.push_back(extractMatrix(array[i]));
    }
    return output;
}

class Intrinsics {
public:
    vector<Mat> R, T;
    Mat A,dist;
    Size size;
public:
    Intrinsics(const FileStorage& fs) { // initialize an object from a track file
        R = extractMatVector(fs["R"]);
        T = extractMatVector(fs["T"]);
        A = extractMatrix(fs["A"]);
        dist = extractMatrix(fs["dist"]);
        size = Size(fs["size"][0],fs["size"][1]);
    };
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
    
    cout << "\nCamera matrix loaded from file: " << intrinsics.A << endl;
    
    return 0;
}


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
    
    cout << "\nFiltering input points";
    // at least 4 points are required by the function, but use a minimum of 10 for stability
    vector<vector<Point2f>> filteredImgPoints;
    vector<vector<Point3f>> filteredObjPoints;
    // copy each vector entry with 10 or more points
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


