#Variables
CC= g++
CPPFLAGS= -O2 -W -c -Wall -I/usr/local/Cellar/opencv/4.3.0_5/include/opencv4 -std=c++11
LDLIBS = -I/usr/local/Cellar/opencv/4.3.0_5/include/opencv4

pfmLib.a: ImageIOpfm.o
	ar rcs libpfm.a ImageIOpfm.o

ImageIOpfm.o: ImageIOpfm.cpp 
	$(CC) $(CPPFLAGS) $(LDLIBS) ImageIOpfm.cpp

# -I/usr/local/Cellar/opencv/4.3.0_5/include/opencv4

clean:
	rm -f $(BIN) *.o core* *.a
