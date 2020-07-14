//
//  board_utils.cpp
//  calibration
//
//  Created by Toby Weed on 7/2/20.
//  Copyright © 2020 Toby Weed. All rights reserved.
//
//  Functions to assist with loading ChArUco boards to and from Yaml files

#include "calib_utils.hpp"
#include "track_markers.hpp"

#include <opencv2/aruco/charuco.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/imgcodecs.hpp>
#include <iostream>
#include <string>

using namespace cv;
using namespace std;

/* ========================================================================
FILE STORAGE, READING AND WRITING
========================================================================= */
// Read and write function implementation necessary for FileStorage to work.
static void read(const FileNode& node, Board& b, const Board& default_value = Board()){
    if(node.empty())
        b = default_value;
    else
        b.read(node);
}

// << operator overloads for object points and image points. Convert openCV points to vectors of floats so that FileStorage can write them to disk. Also flatten 3D imgpoints vectors to 2D, so that each board no longer has its own array
FileStorage& operator<<(FileStorage& out, const vector<vector<vector<Point3f>> >& points)
{
    out << "[";
    for(int i = 0; i < points.size(); i++) { // loop through images
//        out << "[";
        for(int j = 0; j < points.at(i).size(); j++) { // loop through boards
            out << "[";
            for(int k = 0; k < points.at(i).at(j).size(); k++) { // loop through points
                vector<float> point;
                point = { points.at(i).at(j).at(k).x, points.at(i).at(j).at(k).y, points.at(i).at(j).at(k).z };
                out << point;
            }
            out << "]";
        }
//        out << "]";
    }
    return out << "]";
}
FileStorage& operator<<(FileStorage& out, const vector<vector<vector<Point2f>> >& points)
{
    out << "[";
    for(int i = 0; i < points.size(); i++) { // loop through images
//        out << "[";
        for(int j = 0; j < points.at(i).size(); j++) { // loop through boards
            out << "[";
            for(int k = 0; k < points.at(i).at(j).size(); k++) { // loop through points
                vector<float> point;
                point = { (points.at(i).at(j).at(k).x), (points.at(i).at(j).at(k).y) };
                out << point;
            }
            out << "]";
        }
//        out << "]";
    }
    return out << "]";
}
FileStorage& operator<<(FileStorage& out, const vector<vector<vector<int > >>& ids)
{
    vector<vector<int>> output; // will consist of arrays of image outputs
    for(int i = 0; i < ids.size(); i++) { // loop through images
        vector<int> imgOutput; // output for one image
        for(int j = 0; j < ids.at(i).size(); j++) { // loop through boards
            for(int k = 0; k < ids.at(i).at(j).size(); k++) { // loop through points
                imgOutput.push_back( ids.at(i).at(j).at(k) );
            }
        }
        output.push_back( imgOutput );
    }
    return out << output;
}


/* ========================================================================
CALIBRATIONDATA MANAGEMENT
========================================================================= */
// Initialize a CalibrationData object and return a pointer to it
const void *initializeCalibDataStorage(char *imgDirPath)
{
    CalibrationData *data = new CalibrationData(imgDirPath);
    return (void *)data;
}

// Write a file containing the important calibration data from each image
void saveCalibDataToFile(char *filePath, void *calibrationData) {
    CalibrationData *data = (CalibrationData *)calibrationData; // convert the given pointer from type void to CalibrationData
    FileStorage fs(filePath, FileStorage::WRITE);
    
    fs << "imgdir" << data->imgDir;
    fs << "fnames" << data->fnames;
    fs << "size" << data->size;
    fs << "img_points" << data->imgPoints;
    fs << "obj_points" << data->objPoints;
    fs << "ids" << data->ids;
    
    fs.release();
    cout << "Write Done." << endl;
}

// Reads a CalibrationData object from a track file
CalibrationData readCalibDataFromFile(string filePath)
{
    FileStorage fs;
    fs.open(filePath, FileStorage::READ);
    if (!fs.isOpened())
    {
        cerr << "Failed to open " << filePath << endl;
        exit (EXIT_FAILURE);
    }
    CalibrationData data(fs);
    return data;
}


/* ========================================================================
BOARDS
========================================================================= */
void Board::write(FileStorage& fs) const // write serialization for this class. Incomplete & unused.
{
    fs << "{" << "description" << description << "}";
}
void Board::read(const FileNode& node) // read serialization for this class
{
    description = (string)node["description"];
    squares_x = (int)node["squares_x"];
    squares_y = (int)node["squares_y"];
    square_size_mm = (double)node["square_size_mm"];
    marker_size_mm = (double)node["marker_size_mm"];
    board_width_mm = (double)node["board_width_mm"];
    board_height_mm = (double)node["board_height_mm"];
    dict = (string)node["dict"];
    start_code = (int)node["start_code"];
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
    Ptr<aruco::Dictionary> dict = chDict(b.dict);
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


