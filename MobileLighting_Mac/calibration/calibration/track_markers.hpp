//
//  track_markers.hpp
//  MobileLighting_Mac
//
//  Created by Toby Weed on 6/27/20.
//  Copyright © 2020 Nicholas Mosier. All rights reserved.
//

#ifndef track_markers_hpp
#define track_markers_hpp

#include <opencv2/imgproc.hpp>
#include <string>
#include <iostream>

using namespace cv;
using namespace std;

// Class for storage of data extracted from calibration images before writing to disk.
class CalibrationData {
private:
    // Extract a 1D vector or generic type from a FileNode
    template <typename T>
    vector<T> extractVector( const FileNode& array ) {
        vector<T> output;
        for( int i = 0; i < array.size(); i++ ) {
            output.push_back( array[i] );
        }
        return output;
    };
    
    // Extract a 2D vector of point2f from a FileNode
    vector<vector<Point2f>> extractImgPoints( const FileNode& array ) {
        vector<vector<Point2f>> output;
        for( int i = 0; i < array.size(); i++ ) {
            vector<Point2f> row;
            for( int j = 0; j < array[i].size(); j++ ) {
                Point2f point(array[i][j][0].real(), array[i][j][1].real());
                row.push_back( point );
            }
            output.push_back( row );
        }
        return output;
    }
    
    // Extract a 2D vector of point3f from a FileNode
    vector<vector<Point3f>> extractObjPoints( const FileNode& array ) {
        vector<vector<Point3f>> output;
        for( int i = 0; i < array.size(); i++ ) {
            vector<Point3f> row;
            for( int j = 0; j < array[i].size(); j++ ) {
                Point3f point(array[i][j][0].real(), array[i][j][1].real(), array[i][j][2].real());
                row.push_back( point );
            }
            output.push_back( row );
        }
        return output;
    }
    
    // Extract a 2D vector of ids from a FileNode
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
    
public: // Methods
    CalibrationData(char *imgDirPath) { // constructor
        imgDir = string(imgDirPath);
    };
    
    CalibrationData(const FileStorage& fs) { // initialize an object from a track file
        imgDir = (string)fs["imgdir"];
        fnames = extractVector<string>(fs["fnames"]);
        size = extractVector<int>(fs["size"]);
        imgPoints = { extractImgPoints( fs["img_points"] ) }; // wrap extractImgPoints in another vector since imgPoints is 3D
        objPoints = { extractObjPoints( fs["obj_points"] ) }; // ''
        ids = { extractIds( fs["ids"] ) }; // ''
    };
    
    // load data extracted from one image to the storage object
    void loadData(string fname, vector<int> imgSize, vector<vector<Point2f>> imgPointsVector, vector<vector<Point3f>> objPointsVector, vector<vector<int>> idsVector) {
        fnames.push_back( string(fname) );
        size = imgSize;
        imgPoints.push_back(imgPointsVector);
        objPoints.push_back(objPointsVector);
        ids.push_back(idsVector);
    };
public: // Parameters
    string imgDir;
    vector<string> fnames;
    vector<int> size;
    vector<vector<vector<Point2f>>> imgPoints;
    vector<vector<vector<Point3f>>> objPoints;
    vector<vector<vector<int>>> ids;
};

// Class for more temporary storage of data extracted from calibration images, eventually gets written to CalibrationData
class ImgMarkers {
public:
    vector<int> markerIds;
    vector<vector<Point2f>> markerCorners;
    vector<vector<int>> charucoIds;
    vector<vector<Point2f>> charucoCorners;
};

int trackCharucoMarkers(char **imageNames, int numImgs, char **boardPaths, int numBoards, void **calibrationDataStores);

#endif //track_markers_h
