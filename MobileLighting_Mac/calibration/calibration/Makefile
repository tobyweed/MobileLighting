# USAGE:
# 	'make all' to create an executable called 'main'
# 	'make clean' to remove all .o object files and .a libraries

# All our source cpp files
SRC = track_markers.cpp calib_utils.cpp compute_params.cpp

# For writing a library instead of an executable. Currently unused
ARCH := $(shell arch)
CALLIB = libcalib.$(ARCH).a

# Flags
CC = g++
DBG= -g
WARN= -W -Wall 
CPPFLAGS = -O2 $(WARN) $(DBG) -I/usr/local/Cellar/opencv/4.3.0_5/include/opencv4 --std=c++17
LDLIBS = -I/usr/local/Cellar/opencv/4.3.0_5/include/opencv4 -I/usr/local/Cellar/opencv/4.3.0_5/include/opencv4/lib -L/usr/local/Cellar/opencv/4.3.0_5/lib -lopencv_dnn -lopencv_ml -lopencv_objdetect -lopencv_shape -lopencv_stitching -lopencv_superres -lopencv_videostab -lopencv_calib3d -lopencv_features2d -lopencv_highgui -lopencv_videoio -lopencv_imgcodecs -lopencv_video -lopencv_photo -lopencv_imgproc -lopencv_flann -lopencv_core -lopencv_aruco

OBJ = $(SRC:.cpp=.o)

# Build targets
all: main
main: $(OBJ)
	$(CC) -c $(CPPFLAGS) $(SRC) # Compiles .cpp source files into .o object files
	$(CC) -o main $(OBJ) $(CPPFLAGS) $(LDLIBS) # Links .o object files with dependencies to make an executable

clean:
	rm -f *.o *.a
