//
//  wrapper.hpp
//  calibration
//
//  Created by Toby Weed on 6/28/20.
//  Copyright © 2020 Toby Weed. All rights reserved.
//

#ifndef wrapper_hpp
#define wrapper_hpp

#pragma GCC visibility push(default)

const void *InitializeCalibDataStorage(char *imgDirPath);
void SaveCalibDataToFile(char *filePath, void *calibrationData);
int TrackMarkers(char **imageNames, int numImgs, char **boardPaths, int numBoards, void **calibrationDataStores);
int ComputeIntrinsics(char *trackPath, char *outputDirectory );
int ComputeExtrinsics( int posid1, int posid2, char *trackFile1, char *trackFile2, char *intrinsicsFile, char *outputDirectory );

#pragma GCC visibility pop

#endif /* wrapper_hpp */
