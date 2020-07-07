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

// << operator overloads for object points and image points. Convert openCV points to vectors of floats so that FileStorage can write them to disk. Also flatten 3D imgpoints vectors to 2D, so that each board no longer has its own array
FileStorage& operator<<(FileStorage& out, const vector<vector<vector<Point3f>>>& points)
{
    out << "[";
    for(int i = 0; i < points.size(); i++) {
        out << "[";
        for(int j = 0; j < points.at(i).size(); j++) {
            out << "[";
            for(int k = 0; k < points.at(i).at(j).size(); k++) {
                vector<float> point;
                point = { points.at(i).at(j).at(k).x, points.at(i).at(j).at(k).y, points.at(i).at(j).at(k).z };
//                point = { (points.at(i).at(j).at(k).x), (points.at(i).at(j).at(k).y) };
                out << point;
            }
            out << "]";
        }
        out << "]";
    }
    return out << "]";
}
FileStorage& operator<<(FileStorage& out, const vector<vector<vector<Point2f>>>& points)
{
    out << "[";
    for(int i = 0; i < points.size(); i++) {
        out << "[";
        for(int j = 0; j < points.at(i).size(); j++) {
            out << "[";
            for(int k = 0; k < points.at(i).at(j).size(); k++) {
                vector<float> point;
                point = { (points.at(i).at(j).at(k).x), (points.at(i).at(j).at(k).y) };
                out << point;
            }
            out << "]";
        }
        out << "]";
    }
    return out << "]";
}
//
//FileStorage& operator<<(FileStorage& out, const vector<vector<vector<Point2f>>>& imgPoints)
//{
////    vector<vector<vector<float>>> output; // will consist of arrays of image outputs
//    out << "[";
//    for(int i = 0; i < imgPoints.size(); i++) {
//        out << "[";
////        vector<vector<float>> imgOutput; // output for one image
//
//        for(int j = 0; j < imgPoints.at(i).size(); j++) {
//
//            for(int k = 0; k < imgPoints.at(i).at(j).size(); k++) {
//                vector<float> point{ (imgPoints.at(i).at(j).at(k).x), (imgPoints.at(i).at(j).at(k).y) };
//
//                out << "[" << point << "]";
////                imgOutput.push_back( point );
//            }
//        }
//        out << "]";
////        output.push_back( imgOutput );
//    }
//    return out << "]";
////    return out << output;
//}
//FileStorage& operator<<(FileStorage& out, const vector<vector<vector<Point3f>>>& objPoints)
//{
//    vector<vector<vector<float>>> output; // will consist of arrays of image outputs
//    for(int i = 0; i < objPoints.size(); i++) {
//        vector<vector<float>> imgOutput; // output for one image
//        for(int j = 0; j < objPoints.at(i).size(); j++) {
//            for(int k = 0; k < objPoints.at(i).at(j).size(); k++) {
//                vector<float> point{ (objPoints.at(i).at(j).at(k).x), (objPoints.at(i).at(j).at(k).y), (objPoints.at(i).at(j).at(k).z)  };
//                imgOutput.push_back( point );
//            }
//        }
//        output.push_back( imgOutput );
//    }
//    return out << output;
//}
FileStorage& operator<<(FileStorage& out, const vector<vector<vector<int>>>& ids)
{
    vector<vector<int>> output; // will consist of arrays of image outputs
    for(int i = 0; i < ids.size(); i++) {
        vector<int> imgOutput; // output for one image
        for(int j = 0; j < ids.at(i).size(); j++) {
            for(int k = 0; k < ids.at(i).at(j).size(); k++) {
                imgOutput.push_back( ids.at(i).at(j).at(k) );
            }
        }
        output.push_back( imgOutput );
    }
    return out << output;
}


// Write a file containing the important calibration data from each image
//int writeMarkersToFile(string filePath, string imgPath, vector<int> size, vector<vector<Point2f>> imgPoints, vector<vector<Point3f>> objPoints, vector<vector<int>> ids) {
//    FileStorage fs(filePath, FileStorage::APPEND);
//
//    fs << "imgPath" << imgPath;
//    fs << "size" << size;
//    fs << "imgPoints" << imgPoints;
//    fs << "objPoints" << objPoints;
//
//    // "flatten" the IDs 2D vector to a 1D vector that doesn't differentiate between boards
//    vector<int> flattenedIds;
//    for(int i = 0; i < ids.size(); i++) {
//        for(int k = 0; k < ids.at(i).size(); k++) {
//            flattenedIds.push_back( ids.at(i).at(k) );
//        }
//    }
//    fs << "ids" << flattenedIds;
//
//    fs.release();                                       // explicit close
//    cout << "Write Done." << endl;
//    return 0;
//}


/* ========================================================================
CALIBRATIONDATA MANAGEMENT
========================================================================= */
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
    fs << "imgPoints" << data->imgPoints;
    fs << "objPoints" << data->objPoints;
    fs << "ids" << data->ids;
    
    fs.release();                                       // explicit close
    cout << "Write Done." << endl;
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
