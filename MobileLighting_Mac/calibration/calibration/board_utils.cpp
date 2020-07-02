//
//  board_utils.cpp
//  calibration
//
//  Created by Toby Weed on 7/2/20.
//  Copyright © 2020 Toby Weed. All rights reserved.
//
//  Functions to assist with loading ChArUco boards to and from Yaml files

#include "board_utils.hpp"

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
        squares_x = (int)node["squares_y"];
        square_size_mm = (double)node["square_size_mm"];
        marker_size_mm = (double)node["marker_size_mm"];
        board_width_mm = (double)node["board_width_mm"];
        board_height_mm = (double)node["board_height_mm"];
        dict = (string)node["dict"];
        startcode = (int)node["startcode"];
    }
    // Convert a string to a supported predefined ChArUco dictionary
    aruco::PREDEFINED_DICTIONARY_NAME chDict(string dictString) {
        if (dictString == "DICT_4x4") {
            return aruco::DICT_4X4_1000;
        } else if (dictString == "DICT_5x5") {
            return aruco::DICT_5X5_1000;
        } else if (dictString == "DICT_6x6") {
            return aruco::DICT_6X6_1000;
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


// Read and write function implementation necessary for FileStorage to work.
static void write(FileStorage& fs, const std::string&, const Board& b)
{
    b.write(fs);
}
static void read(const FileNode& node, Board& b, const Board& default_value = Board()){
    if(node.empty())
        b = default_value;
    else
        b.read(node);
}


// Reads a Board object from a file, then convert it to a CharucoBoard
int readBoardFromFile(string filePath, Ptr<aruco::CharucoBoard> board)
{
    FileStorage fs;
    fs.open(filePath, FileStorage::READ);
    if (!fs.isOpened())
    {
        cerr << "Failed to open " << filePath << endl;
        return -1;
    }
    Board b;
    fs["Board"] >> b;
    Ptr<aruco::Dictionary> dict = getPredefinedDictionary(b.chDict(b.dict));
    board = aruco::CharucoBoard::create(b.squares_x, b.squares_y, b.square_size_mm, b.marker_size_mm, dict);
    return 0;
}


// Create a charuco board and write it to BoardImage.jpg
void createBoard()
{
    Ptr<aruco::Dictionary> dictionary = getPredefinedDictionary(aruco::DICT_5X5_1000);
    Ptr<aruco::CharucoBoard> board = aruco::CharucoBoard::create(12, 9, 0.06f, 0.045f, dictionary);
    Mat boardImage;
    board->draw(Size(800, 600), boardImage, 10, 1);
    imwrite("BoardImage.jpg", boardImage);
}
