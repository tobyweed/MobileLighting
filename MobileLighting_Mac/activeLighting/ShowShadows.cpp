//
//  ShowShadows.cpp
//  activeLighting
//
//  Created by Toby Weed on 7/12/19.
//  Copyright © 2019 Nicholas Mosier. All rights reserved.
//

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <getopt.h>
#include "imageLib.h"

void concatenateImg(CByteImage &destImg, CByteImage imgToAdd);
CByteImage pfm2png(char *pfmPath);
void float2color(CFloatImage fimg, CByteImage &img, float dmin, float scale, int usejet);
void jet(float x, int& r, int& g, int& b);

int writeshadowimgs(char *decodedDir, char *outDir, int projs[], int nProjs, int pos) {
    CByteImage finalImg;
    char outPath[1000];
    sprintf(outPath, "%s/shadows-proj", outDir);
    
    // loop through all provided projectors
    for(int i = 0; i < nProjs; i++) {
        int proj = projs[i];
        char path[1000];
        sprintf(path, "%s/proj%i/pos%i/result%iu-0initial.pfm", decodedDir, proj, pos, pos);
        
        // convert the decoded image to a png
        CByteImage nextImg = pfm2png(path);
        
        // if it's not the first image, add it to the previous images. otherwise initialize finalImg, avoiding undefined behavior
        if( i != 0 ) concatenateImg(finalImg, nextImg);
        else finalImg = nextImg;
        
        // add the projector # to the output path
        sprintf(outPath, "%s%i", outPath, proj);
    }
    
    // write the final image
    sprintf(outPath, "%spos%i.png", outPath, pos);
    printf("writing shadow visualization...");
    WriteImageVerb(finalImg, outPath, 1);
    printf("done.\n");
    
    return 0;
}


// concatenates the rbg values of imgToAdd to those of destImg
void concatenateImg(CByteImage &destImg, CByteImage imgToAdd) {
    printf("concatenating images...\n");
    CShape sh = imgToAdd.Shape();
    int width = sh.width, height = sh.height;
    sh.nBands = 3;
    destImg.ReAllocate(sh);
    
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // get RGB values of pixels from each image
            int addValB = imgToAdd.Pixel(x, y, 0);
            int addValG = imgToAdd.Pixel(x, y, 1);
            int addValR = imgToAdd.Pixel(x, y, 2);
            int destValB = destImg.Pixel(x, y, 0);
            int destValG = destImg.Pixel(x, y, 1);
            int destValR = destImg.Pixel(x, y, 2);
            
            // add them
            int b = addValB + destValB;
            int g = addValG + destValG;
            int r = addValR + destValR;
            
            // assign the new pixel values to the destination image
            destImg.Pixel(x, y, 0) = b;
            destImg.Pixel(x, y, 1) = g;
            destImg.Pixel(x, y, 2) = r;
        }
    }
}


// pfm2png, float2color, and jet adapted from code by Daniel Scharstein on 7/12/19

// takes a path to a decoded pfm image and outputs a CByteImage
CByteImage pfm2png(char *pfmPath) {
    printf("converting pfm %s to CByteImage...\n", pfmPath);
    CByteImage disp;
    int verbose = 1;
    float scale = 1.0 / (1023);

    CFloatImage fdisp;
    ReadImageVerb(fdisp, pfmPath, verbose);
    float2color(fdisp, disp, 0, scale, 1);
    
    return disp;
}

// convert float disparity image into a color image using Matlab jet colormap
// subtract dmin, scale by scale into range [0..1] and convert INFs (unk values) into black
// note 6/12/19: dmin, usejet are relics from old program, could later be used to customize functionality
void float2color(CFloatImage fimg, CByteImage &img, float dmin, float scale, int usejet)
{
    CShape sh = fimg.Shape();
    int width = sh.width, height = sh.height;
    sh.nBands = 3;
    img.ReAllocate(sh);
    
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            float f = fimg.Pixel(x, y, 0);
            int r = 0;
            int g = 0;
            int b = 0;
            
            // this seems to always evaluate to false? this may be a relic
            if (0 && (y < 100 || y > height-100)) { // visualize range at top and bottom of image
                f = 1.2 * (float)x / (float)width - .1;
                if (usejet)
                    jet(f, r, g, b);
                if ((r<2) + (r>253) + (g<2) + (g>253) + (b<2) + (b>253) >= 3 && (y%3 == 0)) {
                    r = g = b = 0; // show locations of pure colors
                }
            } else {
                if (f != INFINITY) {
                    float val = scale * (f - dmin);
                    if (usejet)
                        jet(val, r, g, b);
                }
            }
            
            img.Pixel(x, y, 0) = b;
            img.Pixel(x, y, 1) = g;
            img.Pixel(x, y, 2) = r;
        }
    }
}

// translate value x in [0..1] into color triplet using "jet" color map
// if out of range, use darker colors
// variation of an idea by http://www.metastine.com/?p=7
void jet(float x, int& r, int& g, int& b)
{
    if (x < 0) x = -0.05;
    if (x > 1) x =  1.05;
    x = x / 1.15 + 0.1; // use slightly asymmetric range to avoid darkest shades of blue.
    r = __max(0, __min(255, (int)(round(255 * (1.5 - 4*fabs(x - .75))))));
    g = __max(0, __min(255, (int)(round(255 * (1.5 - 4*fabs(x - .5))))));
    b = __max(0, __min(255, (int)(round(255 * (1.5 - 4*fabs(x - .25))))));
}
