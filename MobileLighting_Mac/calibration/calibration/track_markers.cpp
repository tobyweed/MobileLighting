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
int trackCharucoMarkers(char *imagePath, char **boardPaths, int numBoards)
{
    // Assume all boards use the same ChArUco dict
    Ptr<aruco::Dictionary> dictionary = getPredefinedDictionary(aruco::DICT_5X5_1000);
    
    Ptr<aruco::DetectorParameters> params = aruco::DetectorParameters::create();
    params->cornerRefinementMethod = aruco::CORNER_REFINE_NONE;

    // Read the provided image and create a copy to draw indicators where we detect markers and corners
    Mat image = imread(imagePath);
    Mat imageCopy;
    image.copyTo(imageCopy);
    vector<int> markerIds;
    vector<vector<Point2f> > markerCorners;
    
    cout << "\nDetecting ArUco markers";
    detectMarkers(image, dictionary, markerCorners, markerIds, params);
    vector<Point2f> charucoCorners;
    vector<int> charucoIds;
    int output = -1;
    if (markerIds.size() > 0) {
        // Draw an outline around the detected ArUco markers
        cout << "\nDrawing detected marker indicators";
        aruco::drawDetectedMarkers(imageCopy, markerCorners, markerIds,Scalar(0, 0, 255));
        
        // Loop through all provided board paths, initialize the Board objects, and detect/draw chessboard corners
        Ptr<aruco::CharucoBoard> boards[numBoards];
        for( int i = 0; i < numBoards; i++ ) {
            cout << "\nReading board " << i << " from file " << boardPaths[i];
            Board boardN = readBoardFromFile(boardPaths[i]);
            int startCode = boardN.startcode;
            Ptr<aruco::CharucoBoard> boardNCharuco = convertBoardToCharuco(boardN);
            
            // Subtract the start code from each value in markerIds
            // Note: this is necessary because we occasionally use boards with starting IDs higher than 0 which the OpenCV ChArUco library does not expect
            vector<int> markerIdsAdjusted = markerIds;
            for(int i = 0; i < markerIds.size(); i++) {
                markerIdsAdjusted.at(i) = markerIds.at(i) - startCode;
            }
            
            // Generate the 2D pixel locations of the chessboard corners based on the locations of the detected ArUco markers
            cout << "\nInterpolating chessboard corners from board " << i << " based on detected ArUco markers";
            interpolateCornersCharuco(markerCorners, markerIdsAdjusted, image, boardNCharuco, charucoCorners, charucoIds);
            
            // If we have at least one charuco corner, draw indicators of each found corner on the output image
            if (charucoCorners.size() > 0) {
                // Re-adjust the IDs to ensure unique corner IDs when using multiple boards.
                // Note: a board with N = sx * sy squares has N // 2 markers and M = (sx-1) * (sy-1) interior corners, so M < N, which is twice the number of markers. Thus we will have unique corner IDs if we begin counting at 2*startCode
                vector<int> charucoIdsAdjusted = charucoIds;
                for(int i = 0; i < charucoIds.size(); i++) {
                    charucoIdsAdjusted.at(i) = charucoIds.at(i) + 2*startCode;
                }
                cout << "\nDrawing chessboard corner markers for board " << i;
                aruco::drawDetectedCornersCharuco(imageCopy, charucoCorners, charucoIdsAdjusted, Scalar(0, 255, 0));
            }
        }
    } else {
        printf("\nNo markers were detected\n");
        putText(imageCopy,
                    "No markers were detected!",
                    Point(10, imageCopy.rows/2),
                    FONT_HERSHEY_DUPLEX,
                    2.0,
                    CV_RGB(255, 0, 0),
                    2);
    }
    
    // Open a visualization window and prompt user key command
    printf("\nPress any key to continue, r to retake, or q to quit.\n");
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
    
    output = waitKey(0); // Wait for a keystroke in the window. Note that the window must be open and active for the key command to be processed.
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
