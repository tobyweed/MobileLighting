//
//  CropVideo.cpp
//  activeLighting
//
//  Created by Toby Weed on 7/11/19.
//  Copyright © 2019 Nicholas Mosier. All rights reserved.
//

#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#include <iostream>
#include <string>
#include <sstream>

using namespace cv;
using namespace std;
vector<Mat> extractFrames(char *videoPath);

int cropvideo() {
//    char *videoPath = "/Users/tobyweed/Desktop/exp1video.mp4";
//    vector<Mat> frames = extractFrames(videoPath);
    return 0;
}

//vector<Mat> extractFrames(char *videoPath) {
//    VideoCapture cap(videoPath); // video
//    if (!cap.isOpened())
//    {
//        cout << "Cannot open the video file/n" << endl;
////        return ;
//    }
//
//    vector<Mat> allFrames;
//    int length = int(cap.get(CAP_PROP_FRAME_COUNT));
//    print("Extracting video file frames.../n");
//    for( int i = 0; i < length; i++ )
//    {
//        Mat frame;
//        Mat Gray_frame;
//        bool bSuccess = cap.read(frame); // read a new frame from video
//
//        if (!bSuccess)
//        {
//            printf("Couldn't read from video file at frame %i\n",i);
//            break;
//        }
//
//        allFrames.push_back(frame);
////        imwrite("/Users/tobyweed/Desktop/frames_/ig" + s + ".jpg", frame);
//        // add the frame to return value
//    }
//
//    return allFrames;
//}
//
