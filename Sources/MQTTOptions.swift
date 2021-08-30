//
//  MQTTOptions.swift
//  MQTTKit
//
//  Created by Arne Christian Skarpnes on 30.03.2018.
//  Copyright © 2018 Arne Christian Skarpnes. All rights reserved.
//

import Foundation

public struct MQTTOptions {
    var host: String!
    private var _port: Int?
    var port: Int {
        get {
            return _port ?? (useTLS ? 8883 : 1883)
        }
        set {
            _port = newValue
        }
    }
    public var cleanSession = true
    var will: MQTTMessage?
    public var password: String? = nil
    public var username: String? = nil
    var keepAliveInterval: UInt16 = 10
    var clientId: String = UUID().uuidString
    public var useTLS = false
    var autoReconnect: Bool = true
    var autoReconnectTimeout: Double = 60
    var bufferSize: Int = 4096
    var readQosClass: DispatchQoS.QoSClass = .background
    
    public init(host: String, port: Int? = nil) {
        self.host = host
    }
}
