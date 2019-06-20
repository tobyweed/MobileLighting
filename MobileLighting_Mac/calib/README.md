## Calibration

calibration.cpp contains code for intrinsic and extrinsic calibration of the views based on image input.

detection_check.cpp is used to check whether objectPoints are detected in an image. This is only currently used by the stereocalib command to print helpful messages when capturing stereo calibration photos.

.h files are used for making functions publicly available and for bridging c++ to c for use in Swift. 

Currently, all calibration code needs to be compiled with the make command to be run.
Thus, after making changes to any files in this directory, run "make" from inside the calib/ directory. 
