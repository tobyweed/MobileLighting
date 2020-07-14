//
//  compute_params.hpp
//  calibration
//
//  Created by Toby Weed on 7/11/20.
//  Copyright © 2020 Toby Weed. All rights reserved.
//

#ifndef compute_params_hpp
#define compute_params_hpp

#include <stdio.h>

int computeIntrinsics ( char *trackFile, char *outputDirectory );
void saveCameraParamsToFile(string filePath, vector<Mat> R, vector<Mat> T, Mat A, Mat dist, Size size);

#endif /* compute_params_hpp */
