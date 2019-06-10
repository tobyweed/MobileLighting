//
// RobotControl.h
// RobotControl
// Guanghan Pan
//


#ifndef RobotControl_
#define RobotControl_

#pragma GCC visibility push(default)

int Clinet();
int SendCommand(char *);
int GotoView(char *);
int LoadPath(char *);
int ExecutePath();
int SetVelocity(float);

#pragma GCC visibility pop
#endif
