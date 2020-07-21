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

/* ========================================================================
FILE STORAGE, READING AND WRITING
========================================================================= */
// Return a FileStorage object, opened for either reading or writing
FileStorage openFile( string filePath, bool reading ) {
    FileStorage::Mode mode = FileStorage::WRITE;
    if( reading ) {
        mode = FileStorage::READ;
    }
    FileStorage fs(filePath, mode);
    if (!fs.isOpened())
    {
        cerr << "Failed to open " << filePath << endl;
        exit (EXIT_FAILURE);
    }
    if( reading ) {
        cout << "Reading from file " << filePath << endl;
    } else {
        cout << "Writing to file " << filePath << endl;
    }
    return fs;
}

// Write a file from the camera parameters obtained via intrinsics calibration
void saveCameraParamsToFile(string filePath, vector<Mat> R, vector<Mat> T, Mat A, Mat dist, Size size) {
    string fileStr = filePath;
    FileStorage fs = openFile(fileStr,false);
    
    fs << "R" << R;
    fs << "T" << T;
    fs << "A" << A;
    fs << "dist" << dist;
    fs << "size" << size;

    fs.release();
    cout << "Write Done." << endl;
}

// Write a file containing the matrices obtained via extrinsics calibration
void saveExtrinsicsToFile(string filePath, Mat R, Mat T, Mat E, Mat F) {
    string fileStr = filePath;
    FileStorage fs = openFile(fileStr,false);
    
    fs << "R" << R;
    fs << "T" << T;
    fs << "E" << E;
    fs << "F" << F;

    fs.release();
    cout << "Write Done." << endl;
}

// Write a file from the CalibrationData objects generated from calibration images
void saveCalibDataToFile(char *filePath, void *calibrationData) {
    CalibrationData *data = (CalibrationData *)calibrationData; // convert the given pointer from type void to CalibrationData
    string fileStr = filePath;
    FileStorage fs = openFile(fileStr,false);
    
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
    FileStorage fs = openFile(filePath,true);
    CalibrationData data(fs);
    return data;
}

// Reads a Board object from a file
Board readBoardFromFile(string filePath)
{
    FileStorage fs = openFile(filePath,true);
    Board b(fs["Board"]);
//    fs["Board"] >> b;
    return b;
}

// << operator overloads for writing various datatypes to FileStorage objects
FileStorage& operator<<(FileStorage& out, const vector<vector<vector<Point3f>>>& points)
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
FileStorage& operator<<(FileStorage& out, const vector<vector<vector<Point2f>>>& points)
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
FileStorage& operator<<(FileStorage& out, const vector<vector<vector<int>>>& ids)
{
    vector<vector<int>> output; // will consist of arrays of image outputs
    for(int i = 0; i < ids.size(); i++) { // loop through images
        for(int j = 0; j < ids.at(i).size(); j++) { // loop through boards
            vector<int> boardOutput; // output for one board
            for(int k = 0; k < ids.at(i).at(j).size(); k++) { // loop through points
                boardOutput.push_back( ids.at(i).at(j).at(k) );
            }
            output.push_back( boardOutput );
        }
    }
    return out << output;
}
FileStorage& operator<<(FileStorage& out, const Mat& matrix)
{
    out << "[";
    for(int i = 0; i < matrix.rows; i++)
    {
        out << "[";
        for(int j = 0; j < matrix.cols; j++)
        {
            out << matrix.at<double>(i,j);
        }
        out << "]";
    }
    return out << "]";
}
FileStorage& operator<<(FileStorage& out, const vector<Mat>& matrices)
{
    out << "[";
    for(int n = 0; n < matrices.size(); n++) {
        out << matrices[n];
    }
    return out << "]";
}

// extraction utilities for reading from FileNodes to various datatypes
vector<vector<Point2f>> extractImgPoints( const FileNode& array ) {
    vector<vector<Point2f>> output;
    for( int i = 0; i < array.size(); i++ ) {
        vector< Point2f> row;
        for( int j = 0; j < array[i].size(); j++ ) {
            Point2f point(array[i][j][0].real(), array[i][j][1].real());
            row.push_back( point );
        }
        output.push_back( row );
    }
    return output;
}
vector<vector<Point3f>> extractObjPoints( const FileNode& array ) {
    vector<vector<Point3f>> output;
    for( int i = 0; i < array.size(); i++ ) {
        vector< Point3f> row;
        for( int j = 0; j < array[i].size(); j++ ) {
            Point3f point(array[i][j][0].real(), array[i][j][1].real(), array[i][j][2].real());
            row.push_back( point );
        }
        output.push_back( row );
    }
    return output;
}
vector<vector<int>> extractIds( const FileNode& array ) {
    vector<vector<int>> output;
    for( int i = 0; i < array.size(); i++ ) {
        vector<int> row;
        for( int j = 0; j < array[i].size(); j++ ) {
            int id = array[i][j];
            row.push_back( id );
        }
        output.push_back( row );
    }
    return output;
}
Mat extractMatrix( const FileNode& array ) {
    int rows = (int)array.size();
    int cols = (int)array[0].size();
    Mat m = Mat( rows, cols, CV_32F );
    for(int i = 0; i < rows; i++) {
        for(int j = 0; j < cols; j++) {
            m.at<float>(i,j) = array[i][j].real();
        }
    }
    return m;
}
vector<Mat> extractMatVector( const FileNode& array ) {
    vector<Mat> output;
    for( int i = 0; i < array.size(); i++ ) {
        output.push_back(extractMatrix(array[i]));
    }
    return output;
}

/* ========================================================================
CALIBRATIONDATA IMPLEMENTATION AND MANAGEMENT
========================================================================= */

// CONSTRUCTORS
CalibrationData::CalibrationData(char *imgDirPath) {
    imgDir = string(imgDirPath);
};
CalibrationData::CalibrationData(const FileStorage& fs) { // initialize an object from a track file
    imgDir = (string)fs["imgdir"];
    fnames = extractVector<string>(fs["fnames"]);
    size = extractVector<int>(fs["size"]);
    imgPoints = { extractImgPoints( fs["img_points"] ) }; // wrap extractImgPoints in another vector since imgPoints is 3D
    objPoints = { extractObjPoints( fs["obj_points"] ) }; // ''
    ids = { extractIds( fs["ids"] ) }; // ''
};

// MISC
// load data extracted from one image to the storage object
void CalibrationData::loadData(string fname, vector<int> imgSize, vector<vector<Point2f>> imgPointsVector, vector<vector<Point3f>> objPointsVector, vector<vector<int>> idsVector) {
    fnames.push_back( string(fname) );
    size = imgSize;
    imgPoints.push_back(imgPointsVector);
    objPoints.push_back(objPointsVector);
    ids.push_back(idsVector);
};

// HELPERS
// Initialize a CalibrationData object and return a pointer to it
const void *initializeCalibDataStorage(char *imgDirPath)
{
    CalibrationData *data = new CalibrationData(imgDirPath);
    return (void *)data;
}


/* ========================================================================
BOARDS
========================================================================= */
// Constructors
Board::Board(){}
Board::Board(const FileNode& node) // read serialization for this class
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


