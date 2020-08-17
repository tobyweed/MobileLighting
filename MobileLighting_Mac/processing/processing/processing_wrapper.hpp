#ifndef processing_wrapper_hpp
#define processing_wrapper_hpp

#pragma GCC visibility push(default)

void transformPfm(char *pfmPath, char *transformation);
void writeShadowImgs(char *decodedDir, char *outDir, int projs[], int nProjs, int pos);
void refineDecodedIm(char *outdir, int direction, char* decodedIm, double angle, char *posID);
void disparitiesOfRefinedImgs(char *posdir0, char *posdir1, char *outdir0, char *outdir1, int pos0, int pos1, int rectified, int dXmin, int dXmax, int dYmin, int dYmax);
void computeMaps(char *impath, char *intr, char *extr, char *settings);
void rectifyDecoded(int camera, char *impath, char *outpath);
void rectifyAmbient(int camera, char *impath, char *outpath);
void crosscheckDisparities(char *posdir0, char *posdir1, int pos0, int pos1, float thresh, int xonly, int halfocc, char *in_suffix, char *out_suffix);
void filterDisparities(char *dispx, char *dispy, char *outx, char *outy, int pos0, int pos1, float ythresh, int kx, int ky, int mincompsize, int maxholesize);
void mergeDisparities(char *imgsx[], char *imgsy[], char *outx, char *outy, int count, int mingroup, float maxdiff);
void reprojectDisparities(char *dispx_file, char *dispy_file, char *codex_file, char *codey_file, char *outx_file, char *outy_file, char *err_file, char *mat_file, char *log_file);
void mergeDisparityMaps2(float maxdiff, int nV, int nR, char* outdfile, char* outsdfile, char* outnfile, char *inmdfile, char **invdfiles, char **inrdfiles);

// Calibration
const void *InitializeCalibDataStorage(char *imgDirPath);
void SaveCalibDataToFile(char *filePath, void *calibrationData);
int TrackMarkers(char **imageNames, int numImgs, char **boardPaths, int numBoards, void **calibrationDataStores);
int ComputeIntrinsics(char *trackPath, char *outputDirectory );
int ComputeExtrinsics( int posid1, int posid2, char *trackFile1, char *trackFile2, char *intrinsicsFile, char *outputDirectory );

#pragma GCC visibility pop

#endif /* processing_wrapper_hpp */
 // end
