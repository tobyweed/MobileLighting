// 
// LoadPath_client.cpp
// 2019 Middlebury College Summer Research with professor Scharstein
// Guanghan Pan
//
// Communicates with the Rosvita server which controls the robot arm.
//

#include <unistd.h>
#include <stdio.h> 
#include <sys/socket.h> 
#include <arpa/inet.h> 
#include <unistd.h>  
#include <string.h>
#include <string>
#include <iostream>

#include <stdexcept>

#define PORT 65001
using namespace std;

int setVelocity(float v);

int client() 
{ 
    int sock = 0;
    struct sockaddr_in serv_addr;
    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0)
    {
        printf("Socket creation error.\n");
        return -1;
    }
    
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(PORT);
    
    // Convert IPv4 and IPv6 addresses from text to binary form
    if(inet_pton(AF_INET, "10.0.0.179", &serv_addr.sin_addr)<=0)
    {
        printf("Invalid address/ Address not supported\n");
        return -1;
    }
    
    printf("Trying to connect to robot server...\n");
    
    // Try to connect to robot server. If the connection fails, check the IP address above.
    if (connect(sock, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0)
    {
        printf("Connection to robot server failed.\n");
        return -1;
    } else {
        printf("Connection to robot server successful.\n");
    }
    return sock;
}

int sendCommand(char *script){
    int client_sock = client();
    ssize_t result;
    char buffer[1024] = {0};
    if(client_sock<1)
        return -1;
    result = send(client_sock, script, strlen(script),0);
    if (result<0){
        printf("Sending to Rosvita server failed.\n");
        return -1;
    }
    read(client_sock, buffer, 1024);
    cout << buffer << "\n";
    close(client_sock);
    usleep(1000000);
    return 0;
}

// Load the path to the Rosvita server. Return -1 if unsuccessful, number of positions if successful
int loadPath(string pathName, char *output){
    string script = "load " + pathName + ".obj";
    ssize_t n = script.length();
    char command[n+1];
    strcpy(command, script.c_str());

    // Send command
    int client_sock = client();
    ssize_t result;
    char buffer[1024] = {0};
    
    if(client_sock<1) {
        printf("Issue establishing connection with Rosvita server.\n");
        return -1;
    }

    cout << "Sending command to load path " << pathName << " to Rosvita server...\n";
    result = send(client_sock,command,strlen(command),0);
    if (result<0){
        printf("Sending to Rosvita server failed.\n");
        return -1;
    }

    read(client_sock, buffer, 3072);
    close(client_sock);

    usleep(1000000);
    
    strcpy(output, buffer);
    return 0;
}

int gotoVideoStart(){
    string script = "s";
    ssize_t n = script.length();
    char command[n+1];
    strcpy(command, script.c_str());
    if(sendCommand(command)<0)
        return -1;
    return 0;
}


int gotoView(string num){
    string script = num;
    ssize_t n = script.length();
    char command[n+1];
    strcpy(command, script.c_str());
    if(sendCommand(command)<0)
        return -1;
    return 0;
}

// move smoothly through the main viewpoints at velocity atV, then revert to velocity revert2V
int executePath(float atV, float revert2V){
    string script = "e";
    ssize_t n = script.length();
    char command[n+1];
    strcpy(command, script.c_str());
    
    if(setVelocity(atV)<0) // set the velocity to atV
        return -1;
    if(sendCommand(command)<0) // execute the path
        return -1;
    if(setVelocity(revert2V)<0) // set the velocity to revert2V
        return -1;
    
    return 0; // return success
}

// go through the motion recorded by the VIVE motion tracker
int executeHumanPath(){
    string script = "t";
    ssize_t n = script.length();
    char command[n+1];
    strcpy(command, script.c_str());
    if(sendCommand(command)<0)
        return -1;
    return 0;
}


int setVelocity(float v){
    string script = "v " +  std::to_string(v);
    ssize_t n = script.length();
    char command[n+1];
    strcpy(command, script.c_str());
    if(sendCommand(command)<0)
        return -1;
    return 0;
}
