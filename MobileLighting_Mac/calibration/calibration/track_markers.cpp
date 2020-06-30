//
//  track_markers.cpp
//  MobileLighting_Mac
//
//  Created by Toby Weed on 6/27/20.
//  Copyright © 2020 Nicholas Mosier. All rights reserved.
//

#include "track_markers.hpp"
#include <opencv2/aruco/charuco.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/imgcodecs.hpp>
#include <iostream>
#include <string>

// imgdir, size, fnames, image points, obj points, ids


// Struct to store parameters for intrinsics calibration
struct inCalParams {
    std::string pathName;
//    int size[2];
//    std::vector<std::string> fnames;
    std::vector<cv::Point2f> imgPoints;
    std::vector<cv::Point3f> objPoints;
    std::vector<int> ids;
};

void createBoard();

// Create a charuco board and write it to BoardImage.jpg
void createBoard()
{
    cv::Ptr<cv::aruco::Dictionary> dictionary = cv::aruco::getPredefinedDictionary(cv::aruco::DICT_5X5_1000);
    cv::Ptr<cv::aruco::CharucoBoard> board = cv::aruco::CharucoBoard::create(12, 9, 0.06f, 0.045f, dictionary);
    cv::Mat boardImage;
    board->draw(cv::Size(800, 600), boardImage, 10, 1);
    cv::imwrite("BoardImage.jpg", boardImage);
}

// Detect CharUco markers & corners in an image, display a window visualizing them, and save them on user prompt.
int trackCharucoMarkers(char *imagePath)
{
    cv::Ptr<cv::aruco::Dictionary> dictionary = cv::aruco::getPredefinedDictionary(cv::aruco::DICT_5X5_1000);
    cv::Ptr<cv::aruco::CharucoBoard> board = cv::aruco::CharucoBoard::create(12, 9, 0.06f, 0.045f, dictionary);

    cv::Ptr<cv::aruco::DetectorParameters> params = cv::aruco::DetectorParameters::create();
    params->cornerRefinementMethod = cv::aruco::CORNER_REFINE_NONE;

    cv::Mat image = cv::imread(imagePath);
    cv::Mat imageCopy;
    image.copyTo(imageCopy);
    std::vector<int> markerIds;
    std::vector<std::vector<cv::Point2f> > markerCorners;
    cv::aruco::detectMarkers(image, board->dictionary, markerCorners, markerIds, params);
    
    std::vector<cv::Point2f> charucoCorners;
    std::vector<int> charucoIds;
    int output = -1;
    if (markerIds.size() > 0) {
        cv::aruco::drawDetectedMarkers(imageCopy, markerCorners, markerIds);
        cv::aruco::interpolateCornersCharuco(markerCorners, markerIds, image, board, charucoCorners, charucoIds);
        // if at least one charuco corner detected
        if (charucoIds.size() > 0)
            cv::aruco::drawDetectedCornersCharuco(imageCopy, charucoCorners, charucoIds, cv::Scalar(255, 0, 0));
    } else {
        cv::putText(imageCopy,
                    "No markers were detected!",
                    cv::Point(10, imageCopy.rows/2),
                    cv::FONT_HERSHEY_DUPLEX,
                    2.0,
                    CV_RGB(255, 0, 0),
                    2);
    }
    
    // Open a visualization window and prompt user key command
    cv::putText(imageCopy,
                "Press any key to continue, r to retake, or q to quit.",
                cv::Point(10, imageCopy.rows-15),
                cv::FONT_HERSHEY_DUPLEX,
                2.0,
                CV_RGB(118, 185, 0),
                2);
    cv::namedWindow("Marker Detection Image", cv::WINDOW_NORMAL);
    
    // Toggle fullscreen to bring window to front
    cv::setWindowProperty("Marker Detection Image",cv::WND_PROP_FULLSCREEN,cv::WINDOW_FULLSCREEN);
    cv::setWindowProperty("Marker Detection Image",cv::WND_PROP_FULLSCREEN,cv::WINDOW_NORMAL);
    
    cv::imshow("Marker Detection Image", imageCopy);
    
    output = cv::waitKey(0); // Wait for a keystroke in the window
    cv::destroyWindow("Marker Detection Image");
    
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

//std::vector<cv::Point3f> getObjPoints(std::vector<int> ids) {
//    
//}
