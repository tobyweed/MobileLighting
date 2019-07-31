//
// LoadPath_client.h
// RobotControl
// Guanghan Pan
//
// Header file to export functions
//

int client();
int sendCommand(char *script);
int loadPath(std::string pathName);
int gotoVideoStart();
int gotoView(std::string num);
int executePath(float atV, float revert2V);
int executeHumanPath();
int setVelocity(float v);
