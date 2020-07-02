//
//  track_markers.cpp
//  MobileLighting_Mac
//
//  Created by Toby Weed on 6/27/20.
//  Copyright © 2020 Nicholas Mosier. All rights reserved.
//

#include "track_markers.hpp"
#include "board_utils.hpp"
#include <opencv2/aruco/charuco.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/imgcodecs.hpp>
#include <iostream>
#include <string>

using namespace cv;
using namespace std;


// Struct to store parameters for intrinsics calibration
struct inCalParams {
    string pathName;
//    int size[2];
//    vector<string> fnames;
    vector<Point2f> imgPoints;
    vector<Point3f> objPoints;
    vector<int> ids;
};

// Detect CharUco markers & corners in an image, display a window visualizing them, and save them on user prompt.
int trackCharucoMarkers(char *imagePath, char **boardPaths)
{
    printf("0");
    // Assume all boards use the same ChArUco dict
    Ptr<aruco::Dictionary> dictionary = getPredefinedDictionary(aruco::DICT_5X5_1000);
    
    Ptr<aruco::DetectorParameters> params = aruco::DetectorParameters::create();
    params->cornerRefinementMethod = aruco::CORNER_REFINE_NONE;

    Mat image = imread(imagePath);
    Mat imageCopy;
    image.copyTo(imageCopy);
    vector<int> markerIds;
    vector<vector<Point2f> > markerCorners;
    
    detectMarkers(image, dictionary, markerCorners, markerIds, params);
    printf("1");
    vector<Point2f> charucoCorners;
    vector<int> charucoIds;
    int output = -1;
    if (markerIds.size() > 0) {
        aruco::drawDetectedMarkers(imageCopy, markerCorners, markerIds);
        
        // Loop through all provided board paths, initialize the Board objects, and interpolate corners
        int n_boards = sizeof(boardPaths);
        Ptr<aruco::CharucoBoard> boards[n_boards];
        for( int i = 0; i < n_boards; i++ ) {
            Ptr<aruco::CharucoBoard> board_n;
            readBoardFromFile(boardPaths[0], board_n);
            interpolateCornersCharuco(markerCorners, markerIds, image, board_n, charucoCorners, charucoIds);
        }
        
        // if at least one charuco corner detected
        if (charucoIds.size() > 0)
            aruco::drawDetectedCornersCharuco(imageCopy, charucoCorners, charucoIds, Scalar(255, 0, 0));
    } else {
        putText(imageCopy,
                    "No markers were detected!",
                    Point(10, imageCopy.rows/2),
                    FONT_HERSHEY_DUPLEX,
                    2.0,
                    CV_RGB(255, 0, 0),
                    2);
    }
    
    // Open a visualization window and prompt user key command
    putText(imageCopy,
                "Press any key to continue, r to retake, or q to quit.",
                Point(10, imageCopy.rows-15),
                FONT_HERSHEY_DUPLEX,
                2.0,
                CV_RGB(118, 185, 0),
                2);
    namedWindow("Marker Detection Image", WINDOW_NORMAL);
    
    // Toggle fullscreen to bring window to front
    setWindowProperty("Marker Detection Image",WND_PROP_FULLSCREEN,WINDOW_FULLSCREEN);
    setWindowProperty("Marker Detection Image",WND_PROP_FULLSCREEN,WINDOW_NORMAL);
    
    imshow("Marker Detection Image", imageCopy);
    
    output = waitKey(0); // Wait for a keystroke in the window
    destroyWindow("Marker Detection Image");
    
    // Save the necessary information if "r" was not input (we're not retaking the image)
    if( output != 114 ){
        // store data in json file:
        // imgdir, size, fnames, image points, obj points, ids
        
        // get object points
        
        
//        inCalParams imageParams = {imagePath, charucoCorners};
//        imageParams.pathName = imagePath
//        imageParams.imgPoints = charucoCorners;
//        imageParams.ids = charucoIds;
    }
    
    return output;
}

//int saveTracks(inCalParams imageParams) {
//
//}

//vector<Point3f> getObjPoints(vector<int> ids) {
//
//}
