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

#include <map>

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

// Stereo calibration requires both images to have the same # of image and object points, but
// ArUco detections can include an arbitrary subset of all markers.
// This function limits the points lists to only those points shared between each image.
//  - this function is recycled from the old calibration code
void getSharedPoints(CalibrationData &inCal, CalibrationData &inCal2)
{
    // pointers to make code more legible
    vector<Point3f> *oPoints, *oPoints2;
    vector<Point2f> *iPoints, *iPoints2;
    int shared;     //index of a shared object point
    bool paddingPoints = false;
    
    //for each objPoints vector in overall objPoints vector of vectors
    for (int i  = 0; i < (int)inCal.objPoints[0].size(); i++)
    {
        map<string,int> countMap;
        vector<Point3f> sharedObjPoints;
        vector<Point2f> sharedImgPoints, sharedImgPoints2; //shared image points for each inCal
        
        oPoints = &inCal.objPoints[0].at(i);
        oPoints2 = &inCal2.objPoints[0].at(i);
        iPoints  = &inCal.imgPoints[0].at(i);
        iPoints2 = &inCal2.imgPoints[0].at(i);
        
        if ((int)oPoints->size() >= (int)oPoints2->size()){
            for (int j=0; j<(int)oPoints->size(); j++)
            {
                if (oPoints->at(0) == Point3f(-1,-1,0)) {
                    
                    paddingPoints = true;
                    break;
                }
                for (shared=0; shared<(int)oPoints2->size(); shared++)
                    if (oPoints->at(j) == oPoints2->at(shared)) break;
                if (shared != (int)oPoints2->size())       //object point is shared
                {
                    stringstream temp;
                    temp << "(" << oPoints->at(j).x
                    << "," << oPoints->at(j).y
                    << "," << oPoints->at(j).z << ")";
                    auto result = countMap.insert(std::pair< string, int>(temp.str() , 1));
                    if (result.second == false)
                        result.first->second++;
                    if (result. second != 1)
                        continue;
                    
                    sharedObjPoints.push_back(oPoints->at(j));
                    sharedImgPoints.push_back(iPoints->at(j));
                    sharedImgPoints2.push_back(iPoints2->at(shared));
                    
                }
                paddingPoints = false;
            }
        }
        else {
            for (int j=0; j<(int)oPoints2->size(); j++) {
                if (oPoints2->at(0) == Point3f(-1,-1,0)) {
                    paddingPoints = true;
                    break;
                }
                
                for (shared=0; shared<(int)oPoints->size(); shared++)
                    if (oPoints2->at(j) == oPoints->at(shared)) break;
                if (shared != (int)oPoints->size())       //object point is shared
                {
                    stringstream temp;
                    temp << "(" << oPoints2->at(j).x
                    << "," << oPoints2->at(j).y
                    << "," << oPoints2->at(j).z << ")";
                    auto result = countMap.insert(std::pair< string, int>(temp.str() , 1));
                    if (result.second == false)
                        result.first->second++;
                    if (result. second != 1)
                        continue;
                    
                    sharedObjPoints.push_back(oPoints2->at(j));
                    sharedImgPoints2.push_back(iPoints2->at(j));
                    sharedImgPoints.push_back(iPoints->at(shared));
                    
                }
                paddingPoints = false;
            }
        }
        
        if ((int) sharedObjPoints.size() >= 10){
            *oPoints = sharedObjPoints;
            *oPoints2 = sharedObjPoints;
            *iPoints = sharedImgPoints;
            *iPoints2 = sharedImgPoints2;
        }
        
        else if ((int) sharedObjPoints.size() < 10 || paddingPoints) {
            inCal.objPoints[0].erase(inCal.objPoints[0].begin()+i);
            inCal2.objPoints[0].erase(inCal2.objPoints[0].begin()+i);
            inCal.imgPoints[0].erase(inCal.imgPoints[0].begin()+i);
            inCal2.imgPoints[0].erase(inCal2.imgPoints[0].begin()+i);
            
            // temp: if no objPoints left, then break from loop already
            if (inCal.objPoints[0].size() <= 0){
                inCal.objPoints[0][0].clear();
                inCal2.objPoints[0][0].clear();
                break;
            }
            
            // decrement i because we removed one element
            //  from the beginning of the vector, inCal.objPoints.
            i--;
        }
    }
}

// Filter a vector of vectors s.t. each vector contained by the ouput vector has at least 10 elements
template <typename T>
vector<vector<T>> filterPointsVectorsByMinSize( vector<vector<T>> points ) {
    vector<vector<T>> filteredPoints;
    copy_if( points.begin(), points.end(), back_inserter(filteredPoints), [](vector<T> pointsVector) { return (pointsVector.size() >= 10); } );
    return filteredPoints;
}

int computeExtrinsics( int posid1, int posid2, char *trackFile1, char *trackFile2, char *intrinsicsFile, char *outputDirectory ) {
    cout << "\nComputing extrinsics\n";
    
    CalibrationData calibData1 = readCalibDataFromFile(trackFile1);
    CalibrationData calibData2 = readCalibDataFromFile(trackFile2);
    cout << "\n\nin file: " << intrinsicsFile << endl;
    Intrinsics intrinsics = readIntrinsicsFromFile(intrinsicsFile);
    
    cout << "\nFiltering image and object points";
    getSharedPoints(calibData1, calibData2);
    
    // at least 4 points are required by the function, but use a minimum of 10 for stability
    vector<vector<Point3f>> filteredObjPoints = filterPointsVectorsByMinSize<Point3f>(calibData1.objPoints[0]);
    vector<vector<Point2f>> filteredImgPoints1 = filterPointsVectorsByMinSize<Point2f>(calibData1.imgPoints[0]);
    vector<vector<Point2f>> filteredImgPoints2 = filterPointsVectorsByMinSize<Point2f>(calibData2.imgPoints[0]);
    
    // Compute the extrinsics parameters
    Mat R, T, E, F;
    
    if( intrinsics.A.empty() || intrinsics.dist.empty() ) {
        cout << "Empty intrinsics parameter.\n" << endl;
        cout << "Operation could not be completed.\n" << endl;
        return -1;
    }
        
    double err = stereoCalibrate(filteredObjPoints, filteredImgPoints1, filteredImgPoints2, intrinsics.A, intrinsics.dist, intrinsics.A, intrinsics.dist, intrinsics.size, R, T, E, F, CALIB_FIX_INTRINSIC, TermCriteria(TermCriteria::MAX_ITER+TermCriteria::EPS, 1000, 1e-10));
    
    // Compute the rectification transforms
    Mat R1, R2, P1, P2, Q;
    stereoRectify(intrinsics.A, intrinsics.dist, intrinsics.A, intrinsics.dist, intrinsics.size, R, T, R1, R2, P1, P2, Q);
    
    cout << "\nReprojection err: " << err <<"\n";
    
    // convert to string to concatenate the correct output path
    string outputDir(outputDirectory);
    string outputPath = outputDir + "/extrinsics" + to_string(posid1) + to_string(posid2) + ".json";
    
    saveExtrinsicsToFile(outputPath, R, T, E, F, R1, R2, P1, P2, Q, err);
    
    return 0;
}

// Intrinsics
int computeIntrinsics ( char *trackFile, char *outputDirectory ) {
    cout << "\nComputing intrinsics\n";
    
    CalibrationData calibData = readCalibDataFromFile(trackFile);
    
    if (calibData.objPoints.size() <= 0) { // check how many arrays of object points we have
        cout << "\nThe number of detected images is " << calibData.objPoints.size() << "\n";
        cout << "\nERROR: Unable to calibrate due to invalid number of object points.";
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
    
    saveCameraParamsToFile(outputPath, rvecs, tvecs, cameraMatrix, distCoeffs, size, err);
    
    return 0;
}
