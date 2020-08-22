//
// CameraServiceBrowser.swift
// MobileLighting_Mac
//
// Contains the CameraServicBrowser class, which communicates with the iPhone's CameraService.
//  It is used for finding and connecting to the iPhone's CameraService as well as sending
//  directives to the camera in the form of instruction packets (defined in the .swift file
//  "CameraInstructionPackets.swift").
//


import Foundation
import CocoaAsyncSocket

class CameraServiceBrowser: NSObject, NetServiceDelegate, NetServiceBrowserDelegate, GCDAsyncSocketDelegate {
    
    //MARK: Properties
    var socket: GCDAsyncSocket!
    var serviceBrowser: NetServiceBrowser!
    var service: NetService!
    var readyToSendPacket = false
    var packetsToSend = [CameraInstructionPacket]()
    
    var readyToSendObserver: (()->Void)?
    
    //MARK: Public functions
    
    // startBrowsing
    // -begins browsing for iPhone's Bonjour service "CameraService"
    public func startBrowsing() {
        serviceBrowser = NetServiceBrowser()
        serviceBrowser.delegate = self
        serviceBrowser.searchForServices(ofType: "_cameraService._tcp", inDomain: "local.")     // will call "netServiceBrowserDidFindService" (NetServiceBrowserDelegate function) when camera service found
    }
    
    // sendPacket
    // -PARAMETERS:
    //   -packet: CameraInstructionPacket to send to device
    public func sendPacket(_ packet: CameraInstructionPacket) {
        // add packet to sending queue
        packetsToSend.append(packet)
        
        if (verboseConnection) { print(" -- CameraServiceBrowser: Attempting to send packet") }
        if(self.serviceBrowser == nil) {
            print(" -- CameraServiceBrowser: No service found")
            startBrowsing()
        } else if(self.socket == nil || !self.socket.isConnected) {
            print(" -- CameraServiceBrowser: No socket connected")
            serviceBrowser.stop()
            serviceBrowser.searchForServices(ofType: "_cameraService._tcp", inDomain: "local.")
        } else if readyToSendPacket {
            writeNextPacket()
        }
    }
    
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
                    if (verboseConnection) { print(" -- CameraServiceBrowser: Attempting to connect to socket.") }
                    try socket.connect(toAddress: address, withTimeout: 5)
                    return
                } catch {
                    if (verboseConnection) { print(" -- CameraServiceBrowser: Failed to connect to socket.") }
                }
            }
        }
    }
    
    // socketDidWriteData: GCDAsyncSocketDelegate function
    // -called when CameraInstructionPacket successfully delivered
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        guard tag == 0 else {
            return
        }
        if (verboseConnection) { print(" -- CameraServiceBrowser: Wrote data with tag \(tag)") }
        self.readyToSendPacket = socket.isConnected // ready to send next packet if socket still connected
                
        // remove sent packet from queue
        self.packetsToSend.removeFirst()
        writeNextPacket()
    }
    
    // Called when the sockets are successfully connected
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        self.readyToSendPacket = true
        print(" -- CameraServiceBrowser: Connected with service on port \(port)")
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
        print(" -- CameraServiceBrowser: Sending packet #\(packet.hashValue) with timestamp \(timestampToString(date: Date()))")
        
        let packetData = NSKeyedArchiver.archivedData(withRootObject: packet)   // archive packet for sending
        let packetDataLength = UInt16(packetData.count)
        
        var dataToSend = Data(bytes: [UInt8(packetDataLength/256), UInt8(packetDataLength%256)])    // first two bytes (packet head) indicate size of packet body
        dataToSend.append(packetData)   // append packet body
        
        // send data
        socket.write(dataToSend, withTimeout: -1, tag: 0)   // send packet to device
        self.readyToSendPacket = false
    }
    
}
