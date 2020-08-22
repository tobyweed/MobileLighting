//
//  PhotoSender.swift
//
//  Created by Nicholas Mosier on 5/30/17.
//  Copyright © 2017 Nicholas Mosier. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

class PhotoSender: NSObject, NetServiceDelegate, NetServiceBrowserDelegate, GCDAsyncSocketDelegate {
    //MARK: Properties
    var socket: GCDAsyncSocket!
    var serviceBrowser: NetServiceBrowser!
    var service: NetService!
    var readyToSendPacket = false
    var packetsToSend = [PhotoDataPacket]()    
    
    
    //MARK: Public functions
    
    // startBrowsing
    // -begins browsing for Mac's Bonjour service "PhotoReceiver"
    public func startBrowsing() {
        print(" -- PhotoSender: Browsing services")
        serviceBrowser = NetServiceBrowser()
        serviceBrowser.delegate = self
        serviceBrowser.searchForServices(ofType: "_photoReceiver._tcp", inDomain: "local.")     // will call "netServiceBrowserDidFindService" (NetServiceBrowserDelegate function) when photo receiver found
    }
    
    // sendPacket
    // -PARAMETERS:
    //   -packet: PhotoDataPacket to send to Mac
    public func sendPacket(_ packet: PhotoDataPacket) {
        // add packet to sending queue
        packetsToSend.append(packet)
        
        print(" -- PhotoSender: Attempting to send packet")
        if(self.serviceBrowser == nil) {
            print(" -- PhotoSender: No service found")
            startBrowsing()
        } else if(self.socket == nil || !self.socket.isConnected) {
            print(" -- PhotoSender: No socket connected")
            serviceBrowser.stop()
            serviceBrowser.searchForServices(ofType: "_photoReceiver._tcp", inDomain: "local.")
        } else if readyToSendPacket {
            writeNextPacket()
        }
    }
    
    //MARK: Internal functions
    
    // netServiceBrowserDidFindService: NetServiceBrowserDelegate function
    // -sets this CameraServiceBrowser as delegate, intiates attempt to connect to service
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        self.service = service              // add service to this camera service browser
        self.service.delegate = self        // this camera service browser will be responder to service's delegate
        service.resolve(withTimeout: -1)  // if service resolved, delegate method "netServiceDidResolveAddress" will be called (below)
    }
    
    // netServiceDidResolveAddress: NetServiceDelegate function
    // -if service address is successfully resolved, connects with service
    func netServiceDidResolveAddress(_ sender: NetService) {
        connectWithService(service: sender)
    }
    
    // netServiceDidNotResolveAddress: NetServiceDelegate function
    // -removes service as delegate on failure to resolve address
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        service.delegate = nil  // service failed to resolve
        service = nil
    }
    
    // connectWithService
    // -attempts to connect with socket indicated by found service
    // (precondition: service must have resolved address(es))
    func  connectWithService(service: NetService) {
        let addresses = service.addresses!
        if (self.socket == nil || !self.socket.isConnected) {
            // need to create new socket & connect it to Mac's photo receiver service
            socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
            
            // iterate through addresses until successful connection established
            for address in addresses {
                do {
                    print(" -- PhotoSender: Attempting to connect to socket at address \(address)")
                    try socket.connect(toAddress: address, withTimeout: 5)
                    return
                } catch {
                    print(" -- PhotoSender: Failed to connect to socket at address \(address).")
                }
            }
        }
    }
    
    // socketDidWriteData: GCDAsyncSocketDelegate function
    // -called when PhotoDataPacket successfully delivered
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        guard tag == 0 else {
            return
        }
        print(" -- PhotoSender: Wrote data with tag \(tag)")
        self.readyToSendPacket = socket.isConnected // ready to send next packet if socket still connected
        
        // remove sent packet from queue
        self.packetsToSend.removeFirst()
        writeNextPacket()
    }
    
    // Called when the sockets are successfully connected
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        self.readyToSendPacket = true
        print(" -- PhotoSender: Connected with service on port \(port)")
        writeNextPacket()   // write next packet if any packets pending
    }
    
    // Called when the sockets are disconnected or a connection attempt times out.
    // Retries address resolution from the beginning.
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        self.service.stop()
        self.service.resolve(withTimeout: -1)
    }
    

    // writeNextPacket: writes next packet in queue
    func writeNextPacket() {
        guard !packetsToSend.isEmpty else {
            return
        }
        let packet = packetsToSend.first!
        print(" -- PhotoSender:  Sending packet #\(packet.hashValue)")
        
        let packetData = NSKeyedArchiver.archivedData(withRootObject: packet)   // archive packet for sending
        
        var packetDataLength = UInt32(packetData.count)
        print(" -- PhotoSender:  packetDataLength: \(packetDataLength)")
        var dataToSend = Data()
        for _ in 0..<4 {
            dataToSend.append(UInt8(packetDataLength % UInt32(256)))
            packetDataLength /= 256
        }
        
        //var dataToSend = Data(bytes: [UInt8(packetDataLength/256), UInt8(packetDataLength%256)])    // first two bytes (packet head) indicate size of packet body
        dataToSend.append(packetData)   // append packet body
        
        // send data
        socket.write(dataToSend, withTimeout: -1, tag: 0)   // send packet to Mac
        self.readyToSendPacket = false
    }
}
