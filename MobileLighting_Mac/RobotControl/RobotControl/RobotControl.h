//
// RobotControl.h
// RobotControl
// Guanghan Pan
//
// Header file to export functions
//


#ifndef RobotControl_
#define RobotControl_

#pragma GCC visibility push(default)

int Clinet();
int SendCommand(char *);
int GotoView(char *);
int LoadPath(char *);
int GotoVideoStart();
int ExecutePath(float, float);
int ExecuteHumanPath();
int SetVelocity(float);

#pragma GCC visibility pop
#endif
