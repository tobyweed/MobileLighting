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


/* ========================================================================
MARKER TRACKING FUNCTIONALITY
========================================================================= */
// Find the ArUco markers and corners in a given image and interpolate the chessboard corners from that information.
//  - called by trackCharucoMarkers
int findMarkersAndCorners(Mat image, Ptr<aruco::Dictionary> dictionary, Ptr<aruco::DetectorParameters> params, Board boards[], int numBoards, vector<int> *markerIds, vector<vector<Point2f>> *markerCorners, vector<vector<int>> *charucoIds, vector<vector<Point2f>> *charucoCorners)
{
    cout << "\nDetecting ArUco markers";
    detectMarkers(image, dictionary, *markerCorners, *markerIds, params);
    
    if (markerIds->size() > 0) {
        // loop through all provided board paths, initialize the Board objects, and detect chessboard corners
        for( int i = 0; i < numBoards; i++ ) {
            Board boardN = boards[i];
            int startCode = boardN.start_code;
            Ptr<aruco::CharucoBoard> boardNCharuco = convertBoardToCharuco(boardN);
            
            // subtract the start code from each value in markerIds
            // note: this is necessary because we occasionally use boards with starting IDs higher than 0 which the OpenCV ChArUco library does not expect
            vector<int> markerIdsAdjusted = *markerIds;
            for(int k = 0; k < markerIds->size(); k++) {
                markerIdsAdjusted.at(k) = markerIds->at(k) - startCode;
            }
            
            // storage vectors for ChArUco ids and corners, specific to each board to avoid issues during interpolation
            vector<int> boardCharucoIds;
            vector<Point2f> boardCharucoCorners;
            // generate the 2D pixel locations of the chessboard corners based on the locations of the detected ArUco markerg
            cout << "\nInterpolating chessboard corners from board " << i << " based on detected ArUco markers";
            interpolateCornersCharuco(*markerCorners, markerIdsAdjusted, image, boardNCharuco, boardCharucoCorners, boardCharucoIds);
            
            if (boardCharucoCorners.size() > 0) {
                // re-adjust the IDs to ensure unique corner IDs when using multiple boards.
                // note: a board with N = sx * sy squares has N // 2 markers and M = (sx-1) * (sy-1) interior corners, so M < N, which is twice the number of markers. Thus we will have unique corner IDs if we begin counting at 2*startCode
                for(int k = 0; k < boardCharucoIds.size(); k++) {
                    boardCharucoIds.at(k) += 2*startCode;
                }
                charucoCorners->push_back(boardCharucoCorners);
                charucoIds->push_back(boardCharucoIds);
            } else {
                cout << "\nNo ChArUco corners were interpolated for board " << i;
            }
        }
    } else {
        cout << "\nNo ArUco markers were detected!\n";
        return -1;
    }
    return 0;
}



// Translates ChArUco IDs into 3D object point coordinates
vector<vector<Point3f>> getObjPoints(vector<Board> boards,vector<vector<int>> ids)
{
    vector<vector<Point3f>> objPoints;
    
    // loop through each board
    for(int i = 0; i < boards.size(); i++){
        Board b = boards.at(i);
        int nx = b.squares_x - 1;
        double ssize = b.square_size_mm;
        int start = b.start_code;
        
        // make sure we have IDs for the board under consideration
        if ( ids.size() >= (i + 1) ) {
            vector<Point3f> result;
            vector<int> boardIds = ids.at(i);
            
            // calculate an object point for each ID
            for(int k = 0; k < boardIds.size(); k++) {
                int id = boardIds.at(k) - 2*start; // subtract ID offset
                Point3f point = Point3f( id % nx + 1, floor(id / nx) + 1, 0 ); // calculate object point from ID
                result.push_back(point * ssize); // multiply point coordinates by the square size to get the final 3D location
            }
            objPoints.push_back(result);
        }
    }
    return objPoints;
}


Mat drawMarkerVis( Mat img, vector<int> markerIds, vector<vector<Point2f>> markerCorners, vector<vector<int>> charucoIds, vector<vector<Point2f>> charucoCorners ) {
    
    Mat outputImg;
    img.copyTo(outputImg);
    // If we found any ArUco markers, draw outlines around them
    if(markerCorners.size() > 0) {
        cout << "\nDrawing detected marker indicators";
        aruco::drawDetectedMarkers(outputImg, markerCorners, markerIds, Scalar(0, 0, 255));
        // If we found any chessboard corners, draw outlines around them
        if(charucoCorners.size() > 0) {
            cout << "\nDrawing chessboard corners";
            for(int i = 0; i < charucoIds.size(); i++) {
                aruco::drawDetectedCornersCharuco(outputImg, charucoCorners.at(i), charucoIds.at(i), Scalar(0, 255, 0));
            }
        }
    } else {
        putText(outputImg, "No markers were detected!", Point(10, outputImg.rows/2), FONT_HERSHEY_DUPLEX, 2.0, CV_RGB(255, 0, 0), 2);
    }
    return outputImg;
}

// Detect ChArUco markers & corners in an image, display a window visualizing them, and save them on user prompt.
//  - main function, called by ProgramControl.swift
//  - returns -1 on failure or the input keycode on success
//  - saves a pointer to a calibration data structure to be passed back to swift
int trackCharucoMarkersStereo(char **imageNames, int numImgs, char **boardPaths, int numBoards, void **calibrationDataStores)
{
    int output = -1;
    
    // Intitialize necessary parameters
    Ptr<aruco::Dictionary> dictionary = getPredefinedDictionary(aruco::DICT_5X5_1000); // assume all boards use the same ChArUco dict
    Ptr<aruco::DetectorParameters> params = aruco::DetectorParameters::create();
    params->cornerRefinementMethod = aruco::CORNER_REFINE_NONE;
    
    // Load all boards
    Board boards[numBoards];
    for( int i = 0; i < numBoards; i++ ) {
        cout << "\nReading board " << i << " from file " << boardPaths[i];
        boards[i] = readBoardFromFile(boardPaths[i]);
    }
    
    ImgMarkers imgsMarkers[numImgs];
    Mat imgsToAdd[numImgs];
    for( int i = 0; i < numImgs; i++ ) {
        ImgMarkers imgMarkers = imgsMarkers[i];
        CalibrationData *data = (CalibrationData *)calibrationDataStores[i]; // convert the given pointer from type void to CalibrationData
        
        // Generate the path to the file and read the image
        string imgDir(data->imgDir), imgName(imageNames[i]);
        string imagePath = imgDir + "/" + imgName;
        cout << "\nReading image from file " << imagePath;
        Mat image = imread(imagePath);
        if(image.data == NULL) { // make sure we loaded an image successfully
            cout << "\nImage could not be read from path: " << imagePath << "\n";
            return -1;
        }
        
        // Find markers and corners in the image and write them to our storage vectors
        findMarkersAndCorners(image,dictionary,params,boards,numBoards,&imgMarkers.markerIds,&imgMarkers.markerCorners,&imgMarkers.charucoIds,&imgMarkers.charucoCorners);
        
        // If we found markers, create a copy of the image and draw indicators of all found markers and corners on it
        Mat markerVis = drawMarkerVis(image, imgMarkers.markerIds, imgMarkers.markerCorners, imgMarkers.charucoIds, imgMarkers.charucoCorners);

        imgsToAdd[i] = markerVis;
    }
    
    // Concatenate images from each position
    Mat finalImg;
    int imageWidth = imgsToAdd[0].cols, imageHeight = imgsToAdd[0].rows; // assume all images are the same size
    if(imageHeight >= imageWidth) { // if we're in portrait mode, concatenate images horizontally
        hconcat(imgsToAdd, numImgs, finalImg);
    } else { // if we're in landscape mode, concatenate images vertically
        vconcat(imgsToAdd, numImgs, finalImg);
    }
    
    // Open a visualization window containing the concatenated images and prompt user input
    printf("\nWith image display window open, press any key to continue, r to retake, or q to quit.\n");
    putText(finalImg, "Press any key to continue, r to retake, or q to quit.", Point(10, finalImg.rows-15), FONT_HERSHEY_DUPLEX, 2.0, CV_RGB(118, 185, 0), 2);
    namedWindow("Marker Detection Image", WINDOW_NORMAL);
    setWindowProperty("Marker Detection Image",WND_PROP_FULLSCREEN,WINDOW_FULLSCREEN); // it is necessary to toggle fullscreen to bring the display window to the front
    setWindowProperty("Marker Detection Image",WND_PROP_FULLSCREEN,WINDOW_NORMAL);
    imshow("Marker Detection Image", finalImg);
    output = waitKey(0); // wait for a keystroke in the window. Note that the window must be open and active for the key command to be processed.
    destroyWindow("Marker Detection Image");
    
    if( output != 114 ){ // save the necessary information to our struct if "r" was not input (we're not retaking the image)
        vector<int> size = { imageWidth, imageHeight };
        
        // Loop through each image and save the obtained markers
        for( int i = 0; i < numImgs; i++ ) {
            
            char *imageName = imageNames[i];
            void *calibrationData = calibrationDataStores[i];
            CalibrationData *data = (CalibrationData *)calibrationData;
            ImgMarkers imgMarkers = imgsMarkers[i];
            vector<vector<int>> ids = imgMarkers.charucoIds;
            vector<vector<Point2f>> imgPoints = imgMarkers.charucoCorners;
            vector<vector<Point3f>> objPoints;
            
            if(ids.size() > 0) { // safety check
                vector<Board> boardsVector(boards, boards + sizeof(boards)/sizeof(boards[0])); // convert boards array to vector so it can be passed by value
                objPoints = getObjPoints(boardsVector, ids);
            }
            
            data->loadData( imageName, size, imgPoints, objPoints, ids );
        }
    }
    return output;
}


// Detect ChArUco markers & corners in an image, display a window visualizing them, and save them on user prompt.
//  - main function, called by ProgramControl.swift
//  - returns -1 on failure or the input keycode on success
//  - saves a pointer to a calibration data structure to be passed back to swift
int trackCharucoMarkers(char *imageName, char **boardPaths, int numBoards, void *calibrationData)
{
    int output = -1;
    CalibrationData *data = (CalibrationData *)calibrationData; // convert the given pointer from type void to CalibrationData

    // Generate the path to the file and read the image
    string imgDir(data->imgDir), imgName(imageName);
    string imagePath = imgDir + "/" + imgName;
    Mat image = imread(imagePath);
    if(image.data == NULL) { // make sure we loaded an image successfully
        cout << "Image could not be read from path: " << imagePath;
        return -1;
    }

    // Intitialize necessary parameters
    Ptr<aruco::Dictionary> dictionary = getPredefinedDictionary(aruco::DICT_5X5_1000); // assume all boards use the same ChArUco dict
    Ptr<aruco::DetectorParameters> params = aruco::DetectorParameters::create();
    params->cornerRefinementMethod = aruco::CORNER_REFINE_NONE;
    vector<int> markerIds;
    vector<vector<Point2f>> markerCorners;
    vector<vector<int>> charucoIds;
    vector<vector<Point2f>> charucoCorners;

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
            for(int i = 0; i < charucoIds.size(); i++) {
                aruco::drawDetectedCornersCharuco(imageCopy, charucoCorners.at(i), charucoIds.at(i), Scalar(0, 255, 0));
            }
        }
    } else {
        putText(imageCopy, "No markers were detected!", Point(10, imageCopy.rows/2), FONT_HERSHEY_DUPLEX, 2.0, CV_RGB(255, 0, 0), 2);
    }

    // Open a visualization window and prompt user input
    printf("\nWith image display window open, press any key to continue, r to retake, or q to quit.\n");
    putText(imageCopy, "Press any key to continue, r to retake, or q to quit.", Point(10, imageCopy.rows-15), FONT_HERSHEY_DUPLEX, 2.0, CV_RGB(118, 185, 0), 2);
    namedWindow("Marker Detection Image", WINDOW_NORMAL);
    setWindowProperty("Marker Detection Image",WND_PROP_FULLSCREEN,WINDOW_FULLSCREEN); // it is necessary to toggle fullscreen to bring the display window to the front
    setWindowProperty("Marker Detection Image",WND_PROP_FULLSCREEN,WINDOW_NORMAL);
    imshow("Marker Detection Image", imageCopy);
    output = waitKey(0); // wait for a keystroke in the window. Note that the window must be open and active for the key command to be processed.
    destroyWindow("Marker Detection Image");

    if( output != 114 ){ // save the necessary information to our struct if "r" was not input (we're not retaking the image)
        int width = image.cols;
        int height = image.rows;
        vector<int> size = { width, height };
        vector<vector<int>> ids = charucoIds;
        vector<vector<Point2f>> imgPoints = charucoCorners;
        vector<vector<Point3f>> objPoints;
        if(ids.size() > 0) { // safety check
            vector<Board> boardsVector(boards, boards + sizeof(boards)/sizeof(boards[0])); // convert boards array to vector so it can be passed by value
            objPoints = getObjPoints(boardsVector, ids);
        }
        data->loadData( imageName, size, imgPoints, objPoints, ids );
    }
    return output;
}
