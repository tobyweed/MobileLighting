//
// LoadPath_client.h
// RobotControl
// Guanghan Pan
//

int client();
int sendCommand(char *script);
int gotoView(std::string num);
int loadPath(std::string pathName);
int executePath();
int setVelocity(float v);
