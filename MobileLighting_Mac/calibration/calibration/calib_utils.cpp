//
//  board_utils.cpp
//  calibration
//
//  Created by Toby Weed on 7/2/20.
//  Copyright © 2020 Toby Weed. All rights reserved.
//
//  Functions to assist with loading ChArUco boards to and from Yaml files

#include "calib_utils.hpp"

#include <opencv2/aruco/charuco.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/imgcodecs.hpp>
#include <iostream>
#include <string>

using namespace cv;
using namespace std;

// Read and write function implementation necessary for FileStorage to work.
static void write(FileStorage& fs, const string&, const Board& b)
{
    b.write(fs);
}
static void read(const FileNode& node, Board& b, const Board& default_value = Board()){
    if(node.empty())
        b = default_value;
    else
        b.read(node);
}

// << operator overloads for object points and image points. Convert openCV points to vectors of floats so that FileStorage can write them to disk. Also flatten 2- or 3D imgpoints vectors to 1D, so that each board no longer has its own array
FileStorage& operator<<(FileStorage& out, const vector<vector<Point2f>>& imgPoints)
{
    vector<vector<float>> output;
    for(int i = 0; i < imgPoints.size(); i++) {
        for(int k = 0; k < imgPoints.at(i).size(); k++) {
            vector<float> point{ (imgPoints.at(i).at(k).x), (imgPoints.at(i).at(k).y) };
            output.push_back( point );
        }
    }
    return out << output;
}

FileStorage& operator<<(FileStorage& out, const vector<vector<Point3f>>& objPoints)
{
    vector<vector<float>> output;
    for(int i = 0; i < objPoints.size(); i++) {
        for(int k = 0; k < objPoints.at(i).size(); k++) {
            vector<float> point{ (objPoints.at(i).at(k).x), (objPoints.at(i).at(k).y), (objPoints.at(i).at(k).z) };
            output.push_back( point );
        }
    }
    return out << output;
}

int writeMarkersToFile(string filePath, string imgPath, int size[], vector<vector<Point2f>> imgPoints, vector<vector<Point3f>> objPoints, vector<vector<int>> ids) {
    FileStorage fs(filePath, FileStorage::WRITE);
    
    fs << "imgPath" << imgPath;
    fs << "imgPoints" << imgPoints;
    fs << "objPoints" << objPoints;
    
    // "flatten" the IDs 2D vector to a 1D vector that doesn't differentiate between boards
    vector<int> flattenedIds;
    for(int i = 0; i < ids.size(); i++) {
        for(int k = 0; k < ids.at(i).size(); k++) {
            flattenedIds.push_back( ids.at(i).at(k) );
        }
    }
    fs << "ids" << ids;
    
    fs.release();                                       // explicit close
    cout << "Write Done." << endl;
    return 0;
}


/* ========================================================================
BOARDS
========================================================================= */

// Reads a Board object from a file
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
