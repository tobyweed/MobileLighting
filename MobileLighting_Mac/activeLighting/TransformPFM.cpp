//
//  TransformPFM.cpp
//  activeLighting
//
//  Created by Toby Weed on 8/1/19.
//  Copyright © 2019 Nicholas Mosier. All rights reserved.
//

#include <stdio.h>
#include <stdlib.h>
#include <opencv2/core/mat.hpp>
#include "TransformPFM.hpp"
//#include "imageLib.h"
#include "pfmLib/ImageIOpfm.h"

void rotate90CW( Mat &inIm, Mat &outIm );
void flipY( Mat &inIm, Mat &outIm );

int transformpfm( char *pfmPath, char *transformation ) {
    Mat pfm;
    ReadFilePFM(pfm, pfmPath);
    Mat transformedIm;
    if (strcmp(transformation,"rotate90cw") == 0) {
        rotate90CW(pfm,transformedIm);
    } else if (strcmp(transformation,"flipY") == 0) {
        flipY(pfm,transformedIm);
    } else {
        printf("transformation unrecognized.");
        return -1;
    }
    WriteFilePFM(transformedIm,pfmPath,1/255.0);

    //  - get proper position for pixel in new image
    //  - store pixel at that position in new array
    // convert new array to pfm:
    //  - start with "Pf"
    //  - switch width and height
    //  - add endianess
    //  - add array
    
    return 0;
}

// flips the image over the y axis
void flipY( Mat &inIm, Mat &outIm ) {
    int width = inIm.cols;
    int height = inIm.rows;
    Mat flippedIm = Mat::zeros(height, width, CV_32FC1); // initialize new image with width and height swapped

    int maxY = height-1;
    int maxX = width-1;
    for(int i=maxY; i >= 0; --i) {
        for(int j=maxX; j >= 0; --j){
            float pixVal = inIm.at<float>(i,j);
            int x = maxX - j;
            flippedIm.at<float>(i,x) = pixVal;
        }
    }

    outIm = flippedIm;
}

// rotates the images 90 degrees clockwise
void rotate90CW( Mat &inIm, Mat &outIm ) {
    int width = inIm.cols;
    int height = inIm.rows;
    Mat rotatedIm = Mat::zeros(width, height, CV_32FC1); // initialize new image with width and height swapped

    int maxY = height-1;
    int maxX = width-1;
    for(int i=maxY; i >= 0; --i) {
        int x = maxY - i;
        for(int j=maxX; j >= 0; --j){
            float pixVal = inIm.at<float>(i,j);
            int y = j;
            rotatedIm.at<float>(y,x) = pixVal;
        }
    }
    
    outIm = rotatedIm;
}
