#  MobileLighting System
* Nicholas Mosier, 07/2018
* Toby Weed, 07/2019


## Table of Contents
* [Overview](#overview)
* [Setup & Installation](#setup-and-installation)
    * [Compatibility](#compatibility)
    * [Installation](#installation)
* [Dataset Acquisition](#dataset-acquisition)
    1. [Scene Setup and Description](#scene-setup-and-description)
        1. [Scene directory creation and configuration](#scene-directory-creation-and-configuration)
        1. [Scene selection](#scene-selection)
        1. [Projector and camera positions](#projector-and-camera-positions)
        1. [Scene description, images, and robot path data.](#scene-description,-images,-and-robot-path-data)
    1. [Calibration image capture](#calibration)
        1. [Intrinsic calibration](#intrinsic-calibration)
        2. [Stereo calibration](#stereo-calibration)
    1. [Ambient data capture](#ambient)
        1. [Ambient images with mirror ball](#ambient-ball-images)
        2. [Ambient still images](#ambient-still-images)
        3. [Default images](#default-images)
        4. [Ambient video with IMU data](#ambient-videos-with-imu-data)
    1. [Structured lighting image capture](#structured-lighting)
* [Image Processing](#image-processing)
    1. [Compute intrinsics](#intrinsics)
    1. [Compute extrinsics for all stereo pairs](#extrinsics)
    1. [Rectify ambient images](#rectify-ambient-images)
    1. [Rectify decoded images](#rectify-decoded-images)
    1. [Refine rectified code images](#refine)
    1. [Disparity-match unrectified, rectified code images](#disparity)
    1. [Merge disparity maps for unrectified, rectified code images](#merge)
    1. [Reproject rectified, merged disparity maps](#reproject)
    1. [Merge reprojected disparities with original disparities and merged disparities for final result](#merge-(2))
* [General Tips](#general-tips)
    * [Communication between ML Mac and ML iOS](#communication-between-ml-mac-and-ml-ios)
    * [Communication between ML Mac and ML Robot Control](#communication-between-ml-mac-and-ml-robot-control)
        * [Loading Paths](#loading-paths)
        * [Debug Mode](#debug-mode)
    * [Bridging C++ to Swift](#bridging-cpp-to-swift)
* [Known Issues and Loose Ends](#known-issues-and-loose-ends)
   * [Robot Crashes](#robot-crashes)
   * [Image Flipping and Orientation Issues](#image-flipping-and-orientation-issues)
   * [Inflexible Commands](#inflexible-commands)
   * [Debugmode Affects Processing](#debugmode-affects-processing)
   * [iOS App Fails to Open](#ios-app-fails-to-open)

## Overview
MobileLighting (ML) performs two general tasks:
* Dataset acquisition
* Processing pipeline

ML consists of 2 different applications:
* **MobileLighting Mac:** this is the control program with which the user interacts. It compiles to an executable and features a command-line interface.
* **MobileLighting iOS:** this is the iOS app that runs on the iPhone / iPod Touch. Its main task is taking photos (and videos, IMU data) upon request from the macOS control program. It manages the camera and also processes structured light images up through the decoding step.

It also has a number of associated, but standalone, applications:
* **[ML Robot Control:](https://github.com/guanghanp/RobotControl)** server which controls a UR5 robot arm via [Rosvita](https://xamla.com/en/) and communicates with ML Mac to coordinate robot motion during dataset capture.
* **[ML SteamVR Tracking:](https://github.com/tianshengs/SteamVR_Tracking)** software which uses an HTC VIVE tracker and SteamVR software to record realistic human-held camera trajectories for simulation by ML Robot Control during dataset capture.
* **[ML Vision Website:](https://github.com/pgh245340802/vision-website)** python scripts used to generate HTML files for the display of ML datasets. 
* **[Camera Calibration:](https://github.com/tianshengs/Camera_Calibration_MobileLighting2019)** not really standalone software (everything is incorporated into ML Mac). However, the README there is useful.




## Setup and Installation
### Compatibility
MobileLighting Mac is only compatible with macOS. Furthermore, Xcode must be installed on this Mac (it is a free download from the Mac App Store). This is partly because Xcode, the IDE used to develop, compile, and install MobileLighting, is only available on macOS. ML Control has only been tested on macOS versions High Sierra (10.13) through Mojave (10.14.5).

MobileLighting iOS is compatible with all devices that run iOS 11+ and have a rear-facing camera and flashlight.

### Installation
1. Install Xcode (available through the Mac App Store).
1. Install openCV 4 with `brew install opencv@4`.
1. Install the Mac USB-to-Serial driver.
    1. Go to the website <https://www.mac-usb-serial.com/dashboard/>
    1. Download the package called **PL-2303 Driver (V3.1.5)**
    1. Login using these credentials:
    **username:** _nmosier_
    **password:** _scharsteinmobileimagematching_
    1. Open & install the driver package.
1. Clone the entire Xcode project from the GitHub repository:
`git clone https://github.com/tobyweed/MobileLighting.git`
1. Run the script called `makeLibraries`
`cd MobileLighting`
`./makeLibraries`
1. Open the Xcode project at MobileLighting/MobileLighting.xcodeproj.
`open MobileLighting.xcodeproj`
1. Try building MobileLighting Control by opening the MobileLighting_Mac build target menu in the top-left corner of the window, to the right of the play button. Select "MobileLighting_Mac" -> "My Mac". Type ⌘+B (or "Product" -> "Build") to build MobileLighting_Mac. [See picture](readme_images/build_mac.png)
1. You'll probably encounter some errors at buildtime. These can normally be fixed by changing the Xcode settings and/or re-adding the linked frameworks & libraries. Here's a full list of libraries that should be linked with the Xcode project:
    * System libraries:
        * libopencv_calib3d
        * libopencv_core
        * libopencv_features2d
        * libopencv_imgproc
        * libopencv_videoio
        * libopencv_aruco
        * libopencv_imgcodecs
        * libpng
    * MobileLighting libraries/frameworks:
        * MobileLighting_Mac/CocoaAsyncSocket.framework
        * MobileLighting_iPhone/CocoaAsyncSocket.framework
        * MobileLighting_Mac/calib/libcalib (this currently needs to be manually recompiled using "make")
        * MobileLighting_Mac/activeLighting/libImgProcessor
        
        If they appear in _red_ in the left sidebar under "MobileLighting/Frameworks", then they cannot be found. This means they need to be re-added. Instructions:
        1. Select red libraries, hit "delete". A dialog pop up — click "Remove Reference".
        1. Now, re-add the libraries. Go back to the MobileLighting.xcodeproj settings, select the MobileLighting_Mac target, and go to the "General" tab and find the "Linked Libraries" section. Click the "+". [picture](readme_images/lib_readd.png)
        1. Some of the libraries will be in /usr/lib, and others will be in /usr/local/lib. To navigate to these folders in the dialog, click "Add Other..." and then the command ⌘+Shift+G. Enter in one of those paths, hit enter, and search for the libraries you need to re-add.
        1. After re-adding, the libraries should all have reappaeared under MobileLighting/Frameworks in the left sidebar, and there should no longer be any red ones.
1. You may also encounter code signing errors — these can generally be resolved by opening the Xcode project's settings (in the left sidebar where all the files are listed, click on the blue Xcode project icon with the name <project>.xcodeproj). Select the target, and then open the "General" tab. Check the "Automatically manage signing" box under the "signing" section. [Here's a visual guide](readme_images/codesign.png)
1. Once MobileLighting Mac successfully compiles, click the "play" button in the top left corner to run it from Xcode. To run it from a non-Xcode command line, first build the project (the easiest way to do that is ⌘-b from within Xcode). This should write all necessary products into a bin/ directory within MobileLighting/. Then run "bin/MobileLighting_Mac" with any tokens (init or a path to a sceneSettings.yml file) to run the app.
    * Note that whenever running the app, it expects either "init" or an absolute path to a sceneSettings.yml file as an argument. From Xcode, these arguments can be passed by going to the build target menu in the top left and clicking "Edit Scheme...". When executing the ML Mac product from Terminal, pass the arguments as you would to any command-line tool.
1. Compiling the MobileLighting_iPhone target should be a lot easier. Just select the MobileLighting_iPhone target from the same menu as before (in the top left corner). If you have an iPhone (or iPod Touch), connect it to the computer and then select the device in the menu. Otherwise, select "Generic Build-only Device". Then, hit ⌘+B to build for the device.
1. To upload the MobileLighting iOS app onto the device, click the "Play" button in the top left corner. This builds the app, uploads it to the phone, and runs it.




## Dataset Acquisition
There are numerous steps to dataset acquisition:
1. Scene Setup and Description
    1. Scene directory creation and configuration
    1. Scene selection
    1. Projector and camera positions
    1. Scene description, images, and robot path data.
1. Calibration image capture
    1. Intrinsic calibration
    2. Multiview calibration
1. Ambient data capture
    1. Ambient images with mirror ball
    2. Ambient images at multiple exposures and lightings
    3. Default images
    4. Ambient video with IMU data
1. Structured lighting image capture
    
These steps are executed/controlled from the MobileLighting Mac command-line interface.

### Scene Setup and Description
##### Scene directory creation and configuration
First, create a directory to store scenes. Then, run MobileLighting_Mac with the "init" option. 

Directions to do this from Xcode:
1. Select MobileLighting_Mac from the build target menu in the top left corner.
1. Click "Edit Scheme" at the bottom of the same menu.
1. Under "Arguments Passed on Launch", enter (or select, if it's already there) "init" and make sure that is the only checked argument.
1. Hit close and then build MobileLighting_Mac. The program will prompt, asking for the path to the scenes directory and the new scene name. After you enter those values, the program should create the appropriately named scene directory, along with sceneSettings and calibration Yaml files. 

Next, update the Yaml files with the parameters you will use for the scene. 
Some important parameters to consider changing:
1. sceneSettings.yml:
    * minSWdataPath: enter the path to the min SW data file here. This is important for structured lighting capture, as the program will try to read the data at this path to determine what structured lighting patterns to display on the projectors.
    * struclight (exposureISOs & exposureDurations): these parameters contain lists of numbers which set the exposures taken for structured lighting. It is good for these to have a wide range, as that'll make the system do better with particularly dark or light surfaces, but it is also important to note that the larger the list of exposures, the longer the already time-consuming structured lighting capture step will take.
    * ambient (exposureISOs & exposureDurations): another pair of lists which determine the exposures of images to be taken, in this case for ambients. Since ambient image capture doesn't take long, this list can be longer. Note that ISOs may not need to vary (durations are more important to change) and that the durations should be varied on a log scale (e.g. 0.01, 0.1, 1.0 or  Or 0.01, 0.03, 0.1, 0.3, 1).
    * robotPathName: this will be used to try and automatically load the correct robot path to the Rosvita server. Once you have set the robot path on the server, make sure to enter its name here.
    * focus: this parameter, ranging from 0.0 to 1.0 where 0.0 is close and 1.0 is far, sets the camera focus when the app starts. The focus then remains fixed for the entire capture session. This should be initially established with both apps running by tapping the phone screen to focus on the scene, then using `readfocus` and pasting the focus value into the sceneSettings file. 
1. calibration.yml:
    * Alpha parameter: the free scaling factor. If -1, the focal lengths of the camera are kept fixed when computing the projection matrices. If 1, the rectified images are decimated and shifted so that all the pixels from the original image are retained in the rectified image -- focal lengths get reduced in the process. If 0, the received pictures are zoomed and shifted so that only valid pixels are visible -- focal lengths get increased in the process.
    * Resizing factor: determines how much to resize the image by on rectification. For example, "2" will zoom the image by 100%.
    * There are also a number of parameters (Num_MarkersX, Marker_Length, Num_of_Boards, Num_MarkersY, First_Marker) which the program uses to generate calibration matrices based on the positions of ArUco or chessboards in calibration images. These need to be changed whenever the board(s) being used for calibration are changed.
    
##### Scene selection
The system has a few limitations and caveats to be considered when taking a scene:
* The system will sometimes assign faulty (reflected) codes to even slightly reflective surfaces. These will usually get discarded during cross checking, causing those surfaces to appear undefined in the final images.
* The system can have trouble with particularly dark surfaces, which don't reflect the projected light well. Adding a very high exposure to struclight (listed above) can sometimes solve this, but will add time to scene capture.
* The same limitations apply to surfaces very tangential to the light source or camera, as the reflections of projected patterns will not reach the camera well.
* Structured lighting images should be captured in as dark a setting as possible, so scenes should be taken in places where outside light sources (from windows, for example) can be mostly eliminated.
* Vibration in the camera can cause problems, particularly during structured lighting capture, so the floor shouldn't be too shaky and there should be little or no movement from bystanders during struclight. This means that places with lots of foot traffic could be problematic. By the same token, nothing in the scene can move during structured lighting capture, which can be tricker than expected -- for example, even a plant wilting slightly during scene capture could cause issues.

##### Projector and camera positions
Projectors should be positioned such that there are few locations visible from the camera which don't receive light from at least one of the projectors. This may mean taking structured lighting from many projector positions. Also make sure that projects are slightly tilted relative to the camera's axes to avoid moiré patterns from an aliasing effect. A useful command is showshadows, which will add decoded unrectified images and output them to /computed/shadowvis. This shows remaining areas with no codes and help determine the next projector positions.

*Remember to take a quick picture (just using any phone camera) of the projector whenever it is re-oriented or moved to be included later in the scenePictures directory.* Note that the images should be stored in JPG format.

Robot positions will be saved onto the robot server directly, where they can be loaded from the program. Remember to change the robotPathName parameter to reflect the path, and to take pictures of the robot/camera poses to save in scenePictures.

##### Scene description and images
1. Create a text file (by convention stored in the root of the scene directory and named sceneDescription.txt) explaining briefly the contents of the scene. The keys listed should consist of:
* Scene name: the name of the scene (same as that of the scene directory)
* Scene content: a brief description of the scene (E.g.: plaster bust on grey bin against gray wall, etc.)
* Lighting conditions: add a listing in here with the lighting and the directory name whenever you take ambients with different lightings. E.g.:
Photos:
    - L0 - Lights on, windows closed
    - L1 - Lights on, windows opened
    - L2 - Lights off, windows opened
    - T0 - No lights on, windows closed, torch mode
    - T1 - No ceiling lights on, umbrella light turned on in far left (from viewer) corner, windows closed, torch mode
    - F0 - No lights on, windows closed, flash mode
    Videos: 
    - L0 - Lights on, windows closed
    - L1 - Lights on, windows opened
    - L2 - Lights off, windows opened
    Also remember to take ambientBall images with the same lighting conditions as in the other photos.
* Robot motion: Briefly describe the robot views (E.g.: Two lateral views about a foot apart. A little over 12 feet from the wall.)
* Projector configuration: Briefly describe the projector positions (E.g.: Two large viewsonic projectors from two positions each. Proj0,2 are left projector, proj 1,3 are right projector.)

2. Create a scenePictures directory and store images of the projector and robot/camera positions. Make sure the images have descriptive names and are stored in jpg or png as opposed to heic format. [This website](https://heictojpg.com/) is an easy place to do that conversion. It is important to have at least one photo of every projector position and every camera position. It is also a good idea to have a photo of the whole scene, including the projectors, robot, and still life.
3. Get a file with information on the robot poses from the Rosvita server and call it "robotPathInfo.ob."
4. Save the files and directories from steps 1-3 and save them in the sceneInfo directory.


### Calibration
In order to capture calibration images, the Mac must be connected to the robot arm (and the iPhone).
##### Intrinsic Calibration
To capture intrinsics calibration images, use the following command:
`calibrate (-a|-d)? [resolution=high]`
Flags:
* `-a`: append photos to existing ones in <scene>/orig/calibration/intrinsics
* `-d`: delete all photos in <scene>/orig/calibration/intrinsics before beginning capture
* (none): overwrite existing photos

ML Mac will automatically set the correct exposure before taking the photos. This exposure is specified in the `calibration -> exposureDuration, exposureISO` properties in the scene settings file. 

ML Mac will ask you to hit enter as soon as you are ready to take the next photo. Each photo is saved at <scene>/orig/calibration/intrinsics with the filename IMG<#>.JPG. It will continue to prompt photo capture until the user tells it to stop with "q" or "quit".

##### Stereo Calibration
To capture extrinsics calibration photos, use the following command:
`stereocalib (-a)? [resolution=high]`
Flags:
* `-a`: append photos to existing ones in <scene>/orig/calibration/stereo/pos*
* (none): delete all photos in <scene>/orig/calibration/stereo/pos* before beginning capture

ML Mac automatically sets the correct exposure before taking the photos. This exposure is specified in the `calibration -> exposureDuration, exposureISO` properties in the scene settings file.

This command will first prompt the user to hit enter to take a set or to write "q" to quit. If the user hits enter, ML Mac will move the robot arm to the 0th position. It will then take a photo. It will iterate through all positions in the path loaded on the Rosvita server, taking a picture at each one, and saving those pictures at <scene>/orig/calibration/stereo/posX/IMGn.JPG, where X is the postion number and n is the set number. Then it will prompt the user whether they want to continue taking sets, retake the last set (overwriting the IMGn.JPG photos), or stop running the command.


### Ambient
In order to capture ambient data, the Mac must be connected to the robot arm (and the iPhone).

Multiple exposures can be used for ambient images. These are specified in the `ambient -> exposureDurations, exposureISOs` lists in the scene settings file.

##### Ambient Ball Images
Remember to take ambients with the mirror ball first, and then without. This is important because it's mission critical that the scene not move between ambient (without ball) capture and struclight capture. Ambient ball images should be taken under all lighting conditions, and the nomenclature should be the same as non-ball ambient -- e.g., ambientBall/L0 should contain images taken under the same lighting conditions as ambient/L0.

##### Ambient Still Images
To capture ambient still images, use the following command:
`takeamb still (-b)? (-f|-t)? (-a|-d)? [resolution=high]`
Flags:
`-b`: save the images to the ambientBall instead of ambient directory. Used to give a rough sense of lighting conditions.
`-f`: use flash mode. This is the brightest illumination setting.
`-t`: use torch mode (i.e. turn on flashlight). This is dimmer than flash.
(none): take a normal ambient photo (with flash/torch off).
`-a`: append another lighting directory within ambient/ or ambientBall/. Otherwise, the program will simply overwrite the 0th directory of the appropriate setting (L0, T0, or F0). This is generally used to capture another lighting condition.
`-d`: delete the entire ambient/ or ambientBall/ directory and write into a new one. Use with care!

The program will move the robot arm to each position and capture ambients of all exposures, and then save them to the appropriate directory. 

##### Default Images
Put one image from each position in the ambients/defaultAmbient directory. These images should be copied from ambients with the best (most visible & high quality) exposure and lighting.

##### Ambient Videos with IMU Data
Ambient videos are taken using the trajectory specified in `<scene>/settings/trajectory.yml`.
This YML file must contain a `trajectory` key. Under this key is a list of robot poses (either joints or coordinates in space, both 6D vectors).
Joint positoin: [joint1, joint2, joint3, joint4, joint5, joint6], all in radians
Coordinates: p[x, y, z, a, b, c], where a, b, c are Euler angles

ML Mac recreates the trajectory by generating a URScript script that it then sends to the robot. Additional parameters than can be tweaked in `trajectory.yml` are
* `timestep`: directly proportional to how long the robot takes to move between positions
* `blendRadius`: increases the smoothness of the trajectory.

To capture ambient videos, use the following command:
`takeamb video (-f|-t)? [exposure#=1]`
Flags:
* `-t`: take video with torch mode (flashlight) on.
* `-f`: same as `-t` (flash can only be enabled when taking a photo)
* (none): take a normal video (w/ flashlight off)
Parameters:
* `[exposure#=1]`: the exposure number is the index of the exposure in the list of exposures specified under  `ambient -> exposureDurations, exposureISOs`. If this parameter is not provided, it defaults to 1.

ML Mac first moves the robot arm to the first position and waits for the user to hit enter. Then, it sends the trajectory script to the robot and waits for the user to hit enter once the trajectory has been completed.

After the trajectory is completed, the iPhone sends the Mac two files:
* the video (a .mp4 file)
* the IMU data, saved as a Yaml list of IMU samples (a .yml file)
Both files are saved in `orig/ambient/video/(normal|torch)/exp#`.


### Structured Lighting
In order to capture structured lighting, the Mac must be connected to the robot arm, the switcher box via the display port and a USB-to-Serial cable, and the iPhone. Furthermore, all projectors being used must be connected to the output VGA ports of the switcher box.

Before capturing structured lighting, you must open a connection with the switcher box. Make sure the Mac is connected to the switcher box in two ways: a) to the RS-232 input via a USB-to-serial adaptor and b) to the XGA input via a VGA cable (note that to connect the Mac to a VGA cable, you will need an HDMI-to-VGA adaptor).
1. Find the name of the USB-to-Serial peripheral by opening the command line and entering
    `ls /dev/tty.*`
    Find the one that looks like it would be the USB-to-Serial device. For example, it may be `/dev/tty.RepleoXXXXX` (if you use the USB-to-Serial driver I use).
    Copy it to the clipboard.
1. Use the command
    `connect switcher [dev_path]`
    You can just paste what you've copied for `[dev_path]`.

Now, the projectors need to be configured. Make sure all projectors are connected to the switcher box and turnd on, and that the switcher box video input is connected to the Mac.
Note: if the switcher box video input is connected to the Mac's display port _after_ starting MobileLighting, then you will need to run the following ML Mac command:
`connect display`

Now, with all the projectors on and the switcher box connected and listening, the projectors need to be focused. First, turn on all projector displays with the command
`proj all on`
(type `help proj` for full usage)

To focus the projectors, it is useful to project a fine checkerboard pattern. Do this with
`cb [squareSize=4]`
Focus each projector such that the checkerboards projected onto the objects in the scene are crisp.

Now, you can begin taking structured lighting. The command is
`struclight [project pos id] [projector #]  [positon #] [resolution=high]`
Parameters:
* `projector pos id`: this specifies the projector position identifier. All code images will be saved in a folder according to this identifier, e.g. at `computed/decoded/unrectified/proj[projector pos id]/pos*`.
* `projector #`: the projector number is the switcher box port to which the projector you want to use is connected. These numbers will be in the range 1–8. This value has no effect on where the images are stored. 
Note that each number (proj id, proj #, & pos #) can also be passed as an array, formatted like: `[1,2,3]`. Arrays passed to proj id and proj # must have the same number of elements.

The reason for the distinction between the projector number and id is so that one could capture structured lighting with many different projector positions, but a limited number of projectors. Thus, one could run "struclight 0 1", taking structured light with the projector connected to port 1 and save those photos to the correct robot position directory in `computed/decoded/unrectified/proj0/`, then move the projector and run "struclight 1 1" to save photos in `computed/decoded/unrectified/proj1/`.

Before starting capture, ML Mac will move the arm to the position and ask you to hit "enter" once it reaches that position.
After that, capture begins. It projects first vertical, then horizontal binary code images. After each direction, the Mac should receive 2 files: a "metadata" file that simply contains the direction of the stripes and the decoded PFM file. It saves the PFM file to "computed/decoded/projX/posA". It then refines the decoded image.





## Image Processing
Here is the approximate outline of the image processing pipeline:
1. Compute intrinsics
1. Compute extrinsics for all stereo pairs
1. Rectify all ambient images
1. Refine all rectified code images (unrectified images should already have automatically been refined during data acquisition)
1. Disparity-match unrectified, rectified code images
1. Merge disparity maps for unrectified, rectified code images
1. Reproject rectified, merged disparity maps
1. Merge reprojected disparities with original disparities and merged disparities for final result

### Intrinsics
To compute intrinsics, use the following command:
`getintrinsics [pattern=ARUCO_SINGLE]`
If no `pattern` is specified, then the default `ARUCO_SINGLE` is used.
The options for `pattern` are the following:
* CHESSBOARD
* ARUCO_SINGLE
The intrinsics file is saved at <scene>/computed/calibration/intrinsics.yml.

### Extrinsics
To compute extrinsics, use the following command:
`getextrinsics (-a | leftpos rightpos | [leftpos1,leftpos2,...] [rightpos1,rightpos2,...])`

Parameters:
* `leftpos rightpos`: the pair of positions to compute extrinsics for, e.g. `getextrinsics 0 1`
* `[leftpos1,leftpos2,...]`: a list of left positions formatted as an array, e.g. `getextrinsics [0,2,3] [1,3,4]` (results in computing extrinsics
for pairs `(0,1), (2,3), (3,4)`
Flags:
* `-a`: compute extrinsics for all adjacent stereo pairs (pos0 & pos1, pos1 & pos2, etc.)
The extrinsics files are saved at `<scene>/computed/calibration/extrinsicsAB.json`.

### Rectify Decoded Images
To rectify decoded images, use one of the following commands:
_for one position pair, one projector:_
`rectify [proj] [left] [right]`
where `[left]` and `[right]` are positions and `[proj]` is the projector position ID.

_for all projectors, one position pair_:
`rectify -a [left] [right]`
where `[left]` & `[right]` are positions

_for all projectors, all position pairs_:
`rectify -a -a`

### Rectify Ambient Images
To rectify ambient images, use the following command:
`rectifyamb`
This will rectify all ambient images. This is the only processing that ambient images need to go through.

### Refine
Use the `refine` command to refine decoded images. Like `rectify`, it can operate on one projector & one position (pair), all projectors & one position (pair), and all projectors & all position (pair)s, depending on the number of `-a` flags.

Additionally, the `-r` flag specifies that it should refine _rectified_ images. In this case, _two_ positions should be provided, constituting a stereo pair.
The absence of `-r` indicates _unrectified_ images should be refined. In this case, only _one_ position should be provided.

### Disparity
Use the `disparity` command to disparity-match refined, decoded images. The usage is
`disparity (-r) [proj] [left] [right]`
`disparity (-r) -a [left] [right]`
`disparity (-r) -a -a`
This saves the results in the directory `computed/disparity/(un)rectified/pos*`.

### Merge
Use the `merge` command to merge the disparity-matched imaged images. The usage is
`merge (-r) [left] [right]`
`merge (-r) -a`
The results are saved in the directory `computed/merged/(un)rectified/pos*`.

### Reproject
Use the `reproject` command to reproject the merged _rectified_ images from the previous step. Note that this step only operates on _rectified_ images. The usage is
`reproject [proj] [left] [right]`
`reproject -a [left] [right]`
`reproject -a -a`
The results are saved in the directory `computed/reprojected/pos*`.

### Merge (2)
Use the `merge2` command to merge the reprojected & disparity results for the rectified images. The usage is
`merge2 [left] [right]`
`merge2 -a`
The final results are saved in `computed/merged2/pos*`.




## General Tips
Use the `help` command to list all possible commands. If you are unsure how to use the `help` command, type `help help`.

### Communication Between ML Mac and ML iOS
The two apps of the ML system communicate wirelessly using Bonjour / async sockets. ML Mac issues _CameraInstructions_ to ML iOS via _CameraInstructionPackets_, and ML iOS sends _PhotoDataPackets_ back to ML Mac.

**Tip**: when _not_ debugging ML iOS, I've found this setup to be the best: host a local WiFi network on the Mac and have the iPhone connect to that.

1. **Initialization:**
    * ML iOS publishes a _CameraService_ on the local domain (visibile over most Wifi, Bluetooth, etc.)
    * ML Mac publishes a _PhotoReceiver_ on the local domain (visibile over most Wifi, Bluetooth, etc.)
1. **Connection**
    * ML Mac searches for the iPhone's _CameraService_ using a _CameraServiceBrowser_
    * ML iOS searches for the Mac's _PhotoReceiver_ using a _PhotoSender_
    If and only if both services are found will communication between the Mac and iPhone be successful.
1. **Communication**
    * ML Mac always initiates communication with the iPhone by sending a _CameraInstructionPacket_, which necessarily contains a _CameraInstruction_ and optionally contains camera settings, such as exposure and focus.
    * For some _CameraInstructions_, ML iOS will send back data within a _PhotoData_ packet. Note that _not all data sent back to the Mac is photo data_: depending on the instruction to which it is responding, it may be a video, the current focus (as a lens position), or a structured light metadata file.
    * For some _CameraInstructions_, ML iOS will send back multiple _PhotoDataPackets_.
    * For some _CameraInstructions_, ML iOS will send back no _PhotoDataPackets_.
    * ML Mac will _always_ be expecting an exact number of _PhotoDataPackets_ for each _CameraInstruction_ it issues. For example, the _CameraInstruction.StartStructuredLighting_ sends back no packets, which the _CameraInstruction.StopVideoCapture_ sends back two packets.
1. **Caveats**
    * Something about the **MiddleburyCollege** WiFi network prevents ML Mac and ML iOS from discovering each other when connected. If ML iOS needs to be connected to MiddleburyCollege, then consider connecting the Mac and iPhone over Bluetooth.
    * In order to view **stdout** for ML iOS, it needs to be run through Xcode. When run through Xcode, the app is reinstalled before launch. Upon reinstallation, the iPhone needs an internet connection to verify the app. Therefore, when debugging ML iOS, it has worked best for me to connect the device to **MiddleburyCollege** and to the Mac over **Bluetooth**.
    * Connection over Bluetooth is at least _10x_ slower than connection over WiFi.
1. **Errors**
    * Sometimes, ML Mac and iOS have trouble finding each other's services. I'm not sure if this is due to poor WiFi/Bluetooth connection, or if it's a bug. In this case, try the following:
    * Make sure ML Mac and ML iOS are connected to the same WiFi network or connected 
    * Try restarting the ML Mac app / ML iOS app while keeping the other running.
    * Try restarting both apps, but launching ML iOS _before_ ML Mac.
    * Sometimes, the connection between ML Mac and ML iOS drops unexpectedly. The "solution" is to try the same steps listed directly above.
    
    **Update:** As of June 2019, the two apps have been communicating by connecting to local wifi network **RobotLab** in the robot lab. This works fine. The trouble with the **MiddleburyCollege** network appears to have been some authorization caveat.

### Communication Between ML Mac and ML Robot Control
The main program, ML Mac, communicates with the robot via a server running Rosvita (robot control software). This is necessarily on a different machine, as Rosvita only runs on Ubuntu. 

They communicate via a wireless socket. Note that the socket is re-created with every command ML Mac sends to the server, and that **ML Mac requires the IP address of the server, which is currently hardcoded in LoadPath_client.cpp**. If it doesn't have the correct IP address (and the robot's IP address occasionally changes), it will try to establish connection indefinitely.

The server replies with a "0" or "-1" string status code ("-1" indicating failure), except in the special case of loadPath(), which returns "-1" indicating failure or "x", where x is the number of positions in the loaded path.

##### Loading Paths
The server stores robot positions in sets called "paths," which are initialized on the server without any input from or output to ML Mac. Each path has a string name and contains positions with IDs from 0 to n-1, n being the number of positions in the set. ML Mac can load paths to the server via the LoadPath function, supplying the string name of the path. If successful, the server will reply with a string (eg "1","2"...) indicating the number of positions in the path, which ML Mac will store. Then, ML Mac can use the GotoView function with a position number as a parameter to tell the server to move the robot to that position.

ML Mac automatically tries to load the path specified in the sceneSettings.yml file whenever the program is started.

##### Debug Mode
There is a variable hard-coded in main.swift called debugMode. When this is set to true, the app will not try to connect to the robot server at all, and will automatically skip robot motion. This is recommended when testing the app without the robot, as otherwise the program will try to connect to the robot server indefinitely on program initialization (with the message **trying to connect to robot server**). Note that this will load a simulated path with 3 viewpoints, and the number of viewpoints is used to compute, for example, extrinsics, so **some processing steps might be affected in debugmode**.

### Bridging cpp to Swift
Here's a link that describes the process: <http://www.swiftprogrammer.info/swift_call_cpp.html>
Some specific notes:
* all the bridging headers are already created/configured for MobileLighting (for both iOS and macOS targets)
* oftentimes, if a C++-only object is _not_ being passed in or out of a function (i.e. it appears in the function's signature), it can be directly compiled as a "C" function by adding `extern "C"` to the beginning of the function declaration. For example, `float example(int n)` would become `extern "C" float example(int n)`. You would then have to add `float example(int n);` to the bridging header. The function `example(Int32)` should then be accessible from Swift.

## Known Issues and Loose Ends
There are a few bugs present in the system, along with a few features in need of revision. Last updated July 2019.

#### Robot Crashes
Occasionally, when ML Mac and ML iOS are sending back and forth high amounts of data (e.g., PFMs or videos), the connection between ML Robot Control and the UR5 robot will timeout (marked by a "heartbeat failure" in the Rosvita IDE). This will cause ML Mac to stop executing, after which it will need to be restarted. This is possibly due to an over-taxing of the wifi router's resources, and perhaps could be fixed by using a higher-performance router. However, it's relatively uncommon. When it happens, just retake whatever was being captured.

#### Image Flipping and Orientation Issues
The system has trouble handling portrait orientation. When capturing a scene in portrait mode, the decoded images will usually get flipped over the y-axis. Also, when the phone has been in portrait mode, sometimes it doesn't register getting switched back to landscape mode. In this case, all of the images will be saved in the wrong orientation.

For ambient and calibration images, orientation can be easily adjusted using [ImageMagick](https://imagemagick.org/)'s mogrify command. 

To remedy orientation problems for decoded images, use the **transform** command in ML Mac. This can flip images over the Y axis or rotate them 90 degrees CW, depending on the arguments supplied. DO NOT use mogrify for PFMs, as it can change them in strange ways (e.g., descreasing the depth range dramatically).

A good place to look for someone trying to fix this is the getPFMData() function in MobileLighting_iPhone/ImageProcessor.swift. I think the transformation for portrait mode there is just buggy.

#### Inflexible Commands
There are a few commands, including showshadows, rectifyamb, and transform, which automatically run on all of a particular set of images, e.g.: all decoded images. These need to be updated to allow more flexible usage.

In addition, during takeamb video, the program automatically adjusts the robot velocity so that when not filming, the robot moves quickly, and when filming, it moves slowly. This is currently hardcoded; it should be adjusted to be set programmatically.

#### Debugmode Affects Processing
Processing depends on the number of positions. As of July 2019, this depends on the path ML Mac thinks is loaded on the server. Debug mode assumes a particular number of positions on the server (currently 3). This means that running processing in debugmode for a scene with more or less than 3 viewpoints could cause issues. This should be updated to be more robust.

#### iOS App Fails to Open
Occasionally, ML iOS will not open. It's not clear why this happens - usually, it's after the app hasn't been used in a while. In this case, delete the app and redownload it via Xcode (just by connecting the device and running it on the device from Xcode).
