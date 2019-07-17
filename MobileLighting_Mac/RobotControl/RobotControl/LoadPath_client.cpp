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
#define PORT 50001
using namespace std;

int client() 
{ 
    int sock = 0;
    struct sockaddr_in serv_addr;
    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0)
    {
        printf("Socket creation error \n");
        return -1;
    }
    
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(PORT);
    
    // Convert IPv4 and IPv6 addresses from text to binary form
    if(inet_pton(AF_INET, "140.233.20.227", &serv_addr.sin_addr)<=0)
    {
        printf("Invalid address/ Address not supported \n");
        return -1;
    }
    
    printf("Trying to connect to robot server... \n");
    
    // Try to connect to robot server. If the connection fails, check the IP address above.
    if (connect(sock, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0)
    {
        printf("Connection to robot server failed. \n");
        return -1;
    }
    return sock;
} 

int sendCommand(char *script){
    int client_sock = client(), result;
    char buffer[1024] = {0};
    if(client_sock<1)
        return -1;
    result = send(client_sock, script, strlen(script),0);
    if (result<0){
        printf("\nSending Failed\n");
        return -1;
    }
    read(client_sock, buffer, 1024);
    cout << buffer << "\n";
    close(client_sock);
    usleep(1000000);
    return 0;
    
}

int gotoView(string num){
    string script = num;
    int n = script.length();
    char command[n+1];
    strcpy(command, script.c_str());
    if(sendCommand(command)<0)
        return -1;
    return 0;
}

// Load the path to the Rosvita server. Return -1 if unsuccessful, number of positions if successful
int loadPath(string pathName){
    string script = "load " + pathName + ".obj";
    int n = script.length();
    char command[n+1];
    strcpy(command, script.c_str());
    
    // Send command
    int client_sock = client(), result;
    char buffer[1024] = {0};
    if(client_sock<1)
        return -1;
    send(client_sock,command,strlen(command),0);
    if (result<0){
        printf("Sending Failed\n");
        return -1;
    }
    read(client_sock, buffer, 1024);
    close(client_sock);
    usleep(1000000);
    int numViews = std::stoi(buffer);

    return numViews;
}

int executePath(){
    string script = "e";
    int n = script.length();
    char command[n+1];
    strcpy(command, script.c_str());
    if(sendCommand(command)<0)
        return -1;
    return 0;
}

int setVelocity(float v){
    string script = "v " +  std::to_string(v);
    int n = script.length();
    char command[n+1];
    strcpy(command, script.c_str());
    if(sendCommand(command)<0)
        return -1;
    return 0;
}
