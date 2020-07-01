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
#include <opencv2/aruco/charuco.hpp>
#include <stdio.h>

extern "C" int TrackMarkers(char *impath, char **boardpaths) {
    return trackCharucoMarkers(impath, boardpaths);
}
