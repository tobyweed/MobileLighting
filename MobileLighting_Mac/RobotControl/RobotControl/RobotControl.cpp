//
// RobotControl.cpp
// RobotControl
// Guanghan Pan
//
// Export functions as C functions so they can be bridged to Swift
//

#include <iostream>
#include "LoadPath_client.h"

extern "C" int Client() {
  return client();
}

extern "C" int SendCommand(char *script) {
  return sendCommand(script);
}

extern "C" int LoadPath(char *pathName){
  return loadPath(std::string(pathName));
}

extern "C" int GotoView(char *num){
    return gotoView(std::string(num));
}

extern "C" int GotoVideoStart(){
    return gotoVideoStart();
}

extern "C" int ExecutePath(){
  return executePath();
}

extern "C" int ExecuteHumanPath(){
    return executeHumanPath();
}

extern "C" int SetVelocity(float v){
  return setVelocity(v);
}

