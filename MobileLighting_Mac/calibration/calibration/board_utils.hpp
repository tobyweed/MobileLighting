//
//  board_utils.hpp
//  calibration
//
//  Created by Toby Weed on 7/2/20.
//  Copyright © 2020 Toby Weed. All rights reserved.
//

#ifndef board_utils_hpp
#define board_utils_hpp

#include <opencv2/aruco/charuco.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/imgcodecs.hpp>
#include <iostream>
#include <string>

using namespace cv;
using namespace std;

// Intermediary class for managing ChArUco boards, especially loading their information from Yaml files
class Board {
public:
    void write(FileStorage& fs) const                        //Write serialization for this class
    {
        fs << "{" << "description" << description << "}";
    }
    void read(const FileNode& node)                          //Read serialization for this class
    {
        description = (string)node["description"];
        squares_x = (int)node["squares_x"];
        squares_y = (int)node["squares_y"];
        square_size_mm = (double)node["square_size_mm"];
        marker_size_mm = (double)node["marker_size_mm"];
        board_width_mm = (double)node["board_width_mm"];
        board_height_mm = (double)node["board_height_mm"];
        dict = (string)node["dict"];
        startcode = (int)node["start_code"];
    }
    // Convert a string to a supported predefined ChArUco dictionary
    Ptr<aruco::Dictionary> chDict(string dictString) {
        if (dictString == "DICT_4x4") {
            return getPredefinedDictionary(aruco::DICT_4X4_1000);
        } else if (dictString == "DICT_5x5") {
            return getPredefinedDictionary(aruco::DICT_5X5_1000);
        } else if (dictString == "DICT_6x6") {
            return getPredefinedDictionary(aruco::DICT_6X6_1000);
        }
        cout << "Unknown ChArUco dictionary: " << dictString;
        exit (EXIT_FAILURE);
    }
public: // Parameters
    string description;
    int squares_x;
    int squares_y;
    double square_size_mm;
    double marker_size_mm;
    double board_width_mm;
    double board_height_mm;
    string dict;
    int startcode;
};

cv::Ptr<cv::aruco::CharucoBoard> convertBoardToCharuco(Board b);
Board readBoardFromFile(std::string filePath);

#endif /* board_utils_hpp */
