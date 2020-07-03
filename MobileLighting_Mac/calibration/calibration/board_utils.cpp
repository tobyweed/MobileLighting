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
Board readBoardFromFile(string filePath)
{
    FileStorage fs;
    fs.open(filePath, FileStorage::READ);
    if (!fs.isOpened())
    {
        cerr << "Failed to open " << filePath << endl;
        exit (EXIT_FAILURE);
    }
    Board b;
    fs["Board"] >> b;
    return b;
}

// Convert an object of class Board to a ChArUco board object
Ptr<aruco::CharucoBoard> convertBoardToCharuco(Board b) {
    Ptr<aruco::Dictionary> dict = b.chDict(b.dict);
    Ptr<aruco::CharucoBoard> board = aruco::CharucoBoard::create(b.squares_x, b.squares_y, b.square_size_mm, b.marker_size_mm, dict);
    return board;
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
