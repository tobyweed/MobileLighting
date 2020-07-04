//
//  track_markers.cpp
//  MobileLighting_Mac
//
//  Created by Toby Weed on 6/27/20.
//  Copyright © 2020 Nicholas Mosier. All rights reserved.
//

#include "track_markers.hpp"
#include "calib_utils.hpp"
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



// Find the ArUco markers and corners in a given image and interpolate the chessboard corners from that information.
//  - called by trackCharucoMarkers
int findMarkersAndCorners(Mat image, Ptr<aruco::Dictionary> dictionary, Ptr<aruco::DetectorParameters> params, Board boards[], int numBoards, vector<int>* markerIds, vector<vector<Point2f>>* markerCorners, vector<int>* charucoIds, vector<Point2f>* charucoCorners) {
    
    cout << "\nDetecting ArUco markers";
    detectMarkers(image, dictionary, *markerCorners, *markerIds, params);
    
    if (markerIds->size() > 0) {
        // Loop through all provided board paths, initialize the Board objects, and detect/draw chessboard corners
        for( int i = 0; i < numBoards; i++ ) {
            Board boardN = boards[i];
            int startCode = boardN.startcode;
            Ptr<aruco::CharucoBoard> boardNCharuco = convertBoardToCharuco(boardN);
            
            // Subtract the start code from each value in markerIds
            // Note: this is necessary because we occasionally use boards with starting IDs higher than 0 which the OpenCV ChArUco library does not expect
            vector<int> markerIdsAdjusted = *markerIds;
            for(int k = 0; k < markerIds->size(); k++) {
                markerIdsAdjusted.at(k) = markerIds->at(k) - startCode;
            }
            
            // Storage vectors for ChArUco ids and corners, specific to each board to avoid issues during interpolation
            vector<int> boardCharucoIds;
            vector<Point2f> boardCharucoCorners;
            // Generate the 2D pixel locations of the chessboard corners based on the locations of the detected ArUco markers
            cout << "\nInterpolating chessboard corners from board " << i << " based on detected ArUco markers";
            interpolateCornersCharuco(*markerCorners, markerIdsAdjusted, image, boardNCharuco, boardCharucoCorners, boardCharucoIds);
            
            if (boardCharucoCorners.size() > 0) {
                // Re-adjust the IDs to ensure unique corner IDs when using multiple boards.
                // Note: a board with N = sx * sy squares has N // 2 markers and M = (sx-1) * (sy-1) interior corners, so M < N, which is twice the number of markers. Thus we will have unique corner IDs if we begin counting at 2*startCode
                for(int k = 0; k < boardCharucoIds.size(); k++) {
                    boardCharucoIds.at(k) += 2*startCode;
                }
                charucoCorners->insert(charucoCorners->begin(), boardCharucoCorners.begin(), boardCharucoCorners.end());
                charucoIds->insert(charucoIds->begin(), boardCharucoIds.begin(), boardCharucoIds.end());
            } else {
                cout << "\nNo ChArUco corners were interpolated for board " << i;
            }
        }
    } else {
        cout << "\nNo ArUco markers were detected!\n";
        return -1;
    }
    return 1;
}


// Detect ChArUco markers & corners in an image, display a window visualizing them, and save them on user prompt.
//  - main function, called by ProgramControl.swift
int trackCharucoMarkers(char *imagePath, char **boardPaths, int numBoards)
{
    int output = -1;
    
    // Initialize the storage vectors, image, and necessary parameters
    Mat image = imread(imagePath);
    Ptr<aruco::Dictionary> dictionary = getPredefinedDictionary(aruco::DICT_5X5_1000); // assume all boards use the same ChArUco dict
    Ptr<aruco::DetectorParameters> params = aruco::DetectorParameters::create();
    params->cornerRefinementMethod = aruco::CORNER_REFINE_NONE;
    vector<int> markerIds;
    vector<vector<Point2f>> markerCorners;
    vector<int> charucoIds;
    vector<Point2f> charucoCorners;
    
    // Load all boards
    Board boards[numBoards];
    for( int i = 0; i < numBoards; i++ ) {
        cout << "\nReading board " << i << " from file " << boardPaths[i];
        boards[i] = readBoardFromFile(boardPaths[i]);
    }
    
    // Find markers and corners in the image and write them to our storage vectors
    findMarkersAndCorners(image,dictionary,params,boards,numBoards,&markerIds,&markerCorners,&charucoIds,&charucoCorners);
    
    // If we found markers, create a copy of the image and draw indicators of all found markers and corners on it
    Mat imageCopy;
    image.copyTo(imageCopy);
    // If we found any ArUco markers, draw outlines around them
    if(markerCorners.size() > 0) {
        cout << "\nDrawing detected marker indicators";
        aruco::drawDetectedMarkers(imageCopy, markerCorners, markerIds, Scalar(0, 0, 255));
        // If we found any chessboard corners, draw outlines around them
        if(charucoCorners.size() > 0) {
            cout << "\nDrawing chessboard corners";
            aruco::drawDetectedCornersCharuco(imageCopy, charucoCorners, charucoIds, Scalar(0, 255, 0));
        }
    } else {
        putText(imageCopy, "No markers were detected!", Point(10, imageCopy.rows/2), FONT_HERSHEY_DUPLEX, 2.0, CV_RGB(255, 0, 0), 2);
    }
    
    // Open a visualization window and prompt user input
    printf("\nPress any key to continue, r to retake, or q to quit.\n");
    putText(imageCopy, "Press any key to continue, r to retake, or q to quit.", Point(10, imageCopy.rows-15), FONT_HERSHEY_DUPLEX, 2.0, CV_RGB(118, 185, 0), 2);
    namedWindow("Marker Detection Image", WINDOW_NORMAL);
    setWindowProperty("Marker Detection Image",WND_PROP_FULLSCREEN,WINDOW_FULLSCREEN); // it is necessary to toggle fullscreen to bring the display window to the front
    setWindowProperty("Marker Detection Image",WND_PROP_FULLSCREEN,WINDOW_NORMAL);
    imshow("Marker Detection Image", imageCopy);
    output = waitKey(0); // wait for a keystroke in the window. Note that the window must be open and active for the key command to be processed.
    destroyWindow("Marker Detection Image");
    
    // Save the necessary information if "r" was not input (we're not retaking the image)
    if( output != 114 ){
        // store data in json file:
        // imgdir, size, fnames, image points, obj points, ids
        
        int width = image.cols;
        int height = image.rows;
        int size[2] = { width, height };
        vector<int> ids = charucoIds;
        vector<Point2f> imgPoints = charucoCorners;
        // get object points (parameters: boards, ids)
        // get image points (imgpoints = charuco corners)
        // det ids (ids = charuco ids)
        
        writeMarkersToFile("/Users/tobyweed/workspace/sandbox_scene/track.json", imagePath, size, imgPoints, ids);
        
//        inCalParams imageParams = {imagePath, charucoCorners};
//        imageParams.pathName = imagePath
//        imageParams.imgPoints = charucoCorners;
//        imageParams.ids = charucoIds;
    }
    
    return output;
}


//int saveTracks(inCalParams imageParams) {
// Needed: imgdir, size, fnames, imgpoints, objpoints, ids
//}
//
//vector<Point3f> getObjPoints(Board boards[],vector<int> ids) {
//
//}


