//
//  board_utils.hpp
//  calibration
//
//  Created by Toby Weed on 7/2/20.
//  Copyright © 2020 Toby Weed. All rights reserved.
//

#ifndef board_utils_hpp
#define board_utils_hpp

#include <stdio.h>
#include <string>
#include <opencv2/aruco/charuco.hpp>
#include <opencv2/imgcodecs.hpp>
#include <iostream>
#include <string>

int readBoardFromFile(std::string filePath, cv::Ptr<cv::aruco::CharucoBoard> board);

#endif /* board_utils_hpp */
