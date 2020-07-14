//
//  wrapper.cpp
//  calibration
//
//  Created by Toby Weed on 6/28/20.
//  Copyright © 2020 Toby Weed. All rights reserved.
//
// Export functions as C functions so they can be bridged to Swift
//

#include "track_markers.hpp"
#include "calib_utils.hpp"
#include "compute_params.hpp"
#include <opencv2/aruco/charuco.hpp>
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

    int TrackMarkers(char **imageNames, int numImgs, char **boardPaths, int numBoards, void **calibrationDataStores) {
        return trackCharucoMarkers(imageNames, numImgs, boardPaths, numBoards, calibrationDataStores);
    }

    const void *InitializeCalibDataStorage(char *imgDirPath) {
        return initializeCalibDataStorage(imgDirPath);
    }

    void SaveCalibDataToFile(char *filePath, void *calibrationData) {
        return saveCalibDataToFile(filePath, calibrationData);
    }

//    int ComputeIntrinsics(char *trackPath) {
//        return computeIntrinsics(trackPath);
//    }

#ifdef __cplusplus
}
#endif

