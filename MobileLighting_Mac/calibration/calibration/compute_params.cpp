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


using namespace cv;
using namespace std;

int computeIntrinsics ( char *trackFile ) {
    int output = -1;
    
    CalibrationData calibData = readCalibDataFromFile(trackFile);
    
    if (calibData.objPoints.size() <= 0) { // check how many arrays of object points we have
        cout << "\nThe number of detected images is " << calibData.objPoints.size() << "\n";
        cout << "\nUnable to calibrate due to invalid number of object points. Exiting.";
        return -1;
    }
    
    Mat cameraMatrix, distCoeffs;
    vector<Mat> rvecs, tvecs;
    Size size(calibData.size[0],calibData.size[1]);
    
    calibrateCamera( calibData.objPoints[0], calibData.imgPoints[0], size, cameraMatrix, distCoeffs, rvecs, tvecs );
    
//    printf("%s. Avg reprojection error = %.4f\n",
//           ok ? "\nIntrinsic calibration succeeded" : "\nIntrinsic calibration failed",
//           inCal.totalAvgErr);
    
    return output;
}

int main( int argc, const char* argv[] )
{
    printf( "\nHello World\n\n" );
}


