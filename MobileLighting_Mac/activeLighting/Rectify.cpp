/*
 * Rectify.cpp
 *
 *  Created on: Jun 28, 2011
 *      Author: wwestlin
 *
 * DS 2/3/2014  -- added "justcopy" option if passing in '-' for matrix filenames
 * DS 3/21/2014 -- added w, h parameters to control the size of the output images
 * NM 6/2018 -- modified to run
 */

#include <iostream>
#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#include <opencv2/calib3d/calib3d.hpp>
#include <string>
#include "pfmLib/ImageIOpfm.h"
#include "assert.h"

using namespace cv;

// computemaps -- computes maps for stereo rectification based on intrinsics & extrinsics matrices
// only needs to be computed once per stereo pair

Mat mapx0, mapy0;
Mat mapx1, mapy1;
int resizing_factor;

void computemaps(int width, int height, char *intrinsics, char *extrinsics, char *settings)
{
    FileStorage calibSettings(settings, FileStorage::READ);
    calibSettings["Settings"]["Resizing_Factor"] >> resizing_factor;
    cv::Size ims(width, height);
    std::clog << "computing maps " << ims << std::endl;
    FileStorage fintr(intrinsics, FileStorage::READ);
    FileStorage fextr(extrinsics, FileStorage::READ);
    Mat k,d,rect0,rect1,proj0,proj1;
    std::clog << "reading camera matrices..." << std::endl;
    fintr["Camera_Matrix"] >> k;
    fintr["Distortion_Coefficients"] >> d;
    fextr["Rectification_Parameters"]["Rectification_Transformation_1"] >> rect0;
    fextr["Rectification_Parameters"]["Projection_Matrix_1"] >> proj0;
    fextr["Rectification_Parameters"]["Rectification_Transformation_2"] >> rect1;
    fextr["Rectification_Parameters"]["Projection_Matrix_2"] >> proj1;
    std::clog << "read camera matrices" << std::endl;
    std::clog << "undistorting first maps..." << std::endl;
    initUndistortRectifyMap(k, d, rect0, proj0, ims*resizing_factor, CV_32FC1, mapx0, mapy0);
    std::clog << "undistorting second maps..." << std::endl;
    initUndistortRectifyMap(k, d, rect1, proj1, ims*resizing_factor, CV_32FC1, mapx1, mapy1);
    std::clog << "done computing maps" << mapx0.size() << std::endl;
}

extern "C" void rectifyDecoded(int camera, char *impath, char *outpath)
{
    printf("rectifying decoded image...\n");
    Mat image, im_linear, im_nearest, image2;
    Mat mapx, mapy;
    const float maxdiff = 1.0; // changed from 0.5 to 1.0 on 6/25/19
    const int imtype = CV_32FC1;
    
    mapx = (camera == 0) ? mapx0 : mapx1;
    mapy = (camera == 0) ? mapy0 : mapy1;
    
    ReadFilePFM(image, string(impath));
    cv::Size ims = image.size() * resizing_factor;
    
    image2 = Mat(ims, imtype, 1);
    im_linear = Mat(ims, imtype, 1);
    im_nearest = Mat(ims, imtype, 1);
    remap(image, im_linear, mapx, mapy, INTER_LINEAR, BORDER_CONSTANT, INFINITY);
    remap(image, im_nearest, mapx, mapy, INTER_NEAREST, BORDER_CONSTANT, INFINITY);
    
    for (int j = 0; j < ims.height; ++j) {
        for (int i = 0; i < ims.width; ++i) {
            float val_linear = im_linear.at<float>(j,i);
            float val_nearest = im_nearest.at<float>(j,i);
            float val;
            if (val_linear != INFINITY && fabs(val_linear - val_nearest) <= maxdiff) {
                val = val_linear;
            } else {
                val = val_nearest;
            }
            image2.at<float>(j,i) = val;
        }
    }
    
    Mat image2_rotated;
    resize(image2, image2, image.size());
    WriteFilePFM(image2, outpath, 1);
}

extern "C" void rectifyAmbient(int camera, char *impath, char *outpath) {
    printf("rectifying ambient image...\n");
    Mat image = imread(impath);
    Mat mapx, mapy;
    const int imtype = CV_32FC1;
    Mat image2 = Mat(image.size() * resizing_factor, imtype, 1);

    mapx = (camera == 0) ? mapx0 : mapx1;
    mapy = (camera == 0) ? mapy0 : mapy1;
    
    remap(image, image2, mapx, mapy, INTER_LINEAR, BORDER_CONSTANT, 0);
    resize(image2, image2, image.size());
    imwrite(outpath, image2);
}
