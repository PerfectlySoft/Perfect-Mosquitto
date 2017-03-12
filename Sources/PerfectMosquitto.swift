//
//  PerfectMosquitto.swift
//  Perfect-Mosquitto
//
//  Created by Rockford Wei on 2017-03-09.
//  Copyright © 2017 PerfectlySoft. All rights reserved.
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2017 - 2018 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//
#if os(Linux)
  import SwiftGlibc
  import LinuxBridge

var errno: Int32 {
  return linux_errno()
}//end errno

#else
  import Darwin
#endif

import cmosquitto

extension String {
  public init(utf8: [Int8]) {
    self = utf8.withUnsafeBufferPointer { ptr -> String in
      guard let p = ptr.baseAddress else { return "" }
      return String(validatingUTF8: p) ?? ""
    }//end init
  }//end public
  public var UTF8: [Int8] {
    get {
      return self.withCString { ptr -> [Int8] in
        let p = UnsafeBufferPointer(start: ptr, count: self.utf8.count)
        return Array(p)
      }//end with
    }//end get
  }//end var
}//end extension

public class Mosquitto {

  /// Log Type / Level of Mosquitto Library
  public enum LogType : Int {
    case NONE = 0x00
    case INFO = 0x01
    case NOTICE = 0x02
    case WARNING = 0x04
    case ERR = 0x08
    case DEBUG = 0x10
    case SUBSCRIBE = 0x20
    case UNSUBSCRIBE = 0x40
    case WEBSOCKETS = 0x80
    case ALL = 0xFFFF
  }//end enum LogType

  public enum Exception: Int32, Error {
    case
    CONN_PENDING = -1,
    SUCCESS = 0,
    NOMEM = 1,
    PROTOCOL = 2,
    INVAL = 3,
    NO_CONN = 4,
    CONN_REFUSED = 5,
    NOT_FOUND = 6,
    CONN_LOST = 7,
    TLS = 8,
    PAYLOAD_SIZE = 9,
    NOT_SUPPORTED = 10,
    AUTH = 11,
    ACL_DENIED = 12,
    UNKNOWN = 13,
    ERRNO = 14,
    EAI = 15,
    PROXY = 16
  }//end enum

  public enum LogLevel: Int32 {
    case NONE = 0x00,
    INFO = 0x01,
    NOTICE = 0x02,
    WARNING = 0x04,
    ERR = 0x08,
    DEBUG = 0x10,
    SUBSCRIBE = 0x20,
    UNSUBSCRIBE = 0x40,
    WEBSOCKETS = 0x80,
    ALL = 0xFFFF
  }//LogLevel

  public enum MQTTVersion: UInt32 {
    case V31 = 3, V311 = 4
  }//end enum

  /// Message content
  public struct Message {

    /// message id
    public var id = Int32(0)

    /// the topic on which to publish / subscribe
    public var topic = ""

    /// data body
    public var payload = [Int8]()

    /// integer value 0, 1 or 2 indicating the Quality of Service to be used for the will.
    public var qos = Int32(0)

    /// determin if the message should be retained on broker
    public var retain = false

    public init(message: mosquitto_message) {
      id = message.mid
      topic = String(cString: message.topic)
      let p = unsafeBitCast(message.payload, to: UnsafePointer<Int8>.self)
      let pbuf = UnsafeBufferPointer(start: p, count: Int(message.payloadlen))
      payload = Array(pbuf)
      qos = message.qos
      retain = message.retain
    }//init

    /// payload can also be set or get by a string
    public var string: String? {
      get {
        let str = String(utf8: payload)
        if str.isEmpty { return nil }
        return str
      }//end get
      set {
        guard let str = string else {
          payload = []
          return
        }//end guard
        payload = str.UTF8
      }//end set
    }//end string

  }//end Message

  public enum ConnectionStatus : Int32 {
    case SUCCESS = 0, BAD_PROTOCAL_VERSION = 1, ID_REJECTED = 2, BROKER_UNAVAILABLE = 3, ELSE
  }//end ConnectionStatus

  public typealias EventConnect = (ConnectionStatus) -> Void
  public var OnConnect: EventConnect = { _ in }
  public var OnDisconnect: EventConnect = { _ in }

  public typealias EventMessageID = (Int32) -> Void
  public var OnPublish: EventMessageID = { _ in }

  public typealias EventMessage = (Message) -> Void
  public var OnMessage: EventMessage = { _ in }

  public typealias EventSubscribe = (Int32, [Int32]) -> Void
  public var OnSubscribe: EventSubscribe = { _, _ in }
  public var OnUnsubscribe: EventMessageID = { _ in }

  public typealias EventLog = (LogLevel, String) -> Void
  public var OnLog: EventLog = { _, _ in }

  /// Initialize the libray, must call prior to all instances initialization.
  public static func OpenLibrary() {
    let _ = mosquitto_lib_init()
  }//end func

  /// Initialize the libray, must call once all instances stopped.
  public static func CloseLibrary() {
    let _ = mosquitto_lib_cleanup()
  }//end func

  /// Get the version of library
  public static var Version: (major:Int, minor: Int, revision: Int) { get {
    var mj = Int32(0)
    var mi = Int32(0)
    var re = Int32(0)
    // simply ignore the unique version number as returned.
    let _ = mosquitto_lib_version(&mj, &mi, &re)
    return (Int(mj), Int(mi), Int(re))
    } //end get
  }//end version


  public func setOption(_ version: MQTTVersion = .V31, value: UnsafeMutableRawPointer) throws {
    guard let h = _handle else {
      throw Mosquitto.Panic
    }//end guard
    let r = mosquitto_opts_set(h, mosq_opt_t(version.rawValue), value)
    guard r == Exception.SUCCESS.rawValue else {
      throw Mosquitto.Panic
    }//end guard
  }//end setOption
  
  internal var _handle: OpaquePointer? = nil

  internal func setupCallbacks(_ h: OpaquePointer) {
    mosquitto_connect_callback_set(h) { _, me, code in
      guard let myself = me else {
        return
      }//end guard
      let mosquitto = Unmanaged<Mosquitto>.fromOpaque(myself).takeUnretainedValue()
      guard let ret = ConnectionStatus(rawValue: code) else {
        mosquitto.OnConnect(.ELSE)
        return
      }//end ret
      mosquitto.OnConnect(ret)
    }//end set
    mosquitto_disconnect_callback_set(h) { _, me, code in
      guard let myself = me else {
        return
      }//end guard
      let mosquitto = Unmanaged<Mosquitto>.fromOpaque(myself).takeUnretainedValue()
      guard code == ConnectionStatus.SUCCESS.rawValue else {
        mosquitto.OnDisconnect(.ELSE)
        return
      }//end ret
      mosquitto.OnDisconnect(.SUCCESS)
    }//end set
    mosquitto_publish_callback_set(h) { _, me, code in
      guard let myself = me else {
        return
      }//end guard
      let mosquitto = Unmanaged<Mosquitto>.fromOpaque(myself).takeUnretainedValue()
      mosquitto.OnPublish(code)
    }//end set
    mosquitto_message_callback_set(h) { _, me, pMsg in
      guard let myself = me, let msg = pMsg else {
        return
      }//end guard
      let mosquitto = Unmanaged<Mosquitto>.fromOpaque(myself).takeUnretainedValue()
      mosquitto.OnMessage(Message(message: msg.pointee))
      // necessary?
      // mosquitto_message_free(&pMsg)
    }//end set
    mosquitto_subscribe_callback_set(h) { _, me, mid, count, granted_qos in
      guard let myself = me, let pQos = granted_qos else {
        return
      }//end guard
      let mosquitto = Unmanaged<Mosquitto>.fromOpaque(myself).takeUnretainedValue()
      let qos = UnsafeBufferPointer(start: pQos, count: Int(count))
      mosquitto.OnSubscribe(mid, Array(qos))
    }//end set
    mosquitto_unsubscribe_callback_set(h) { _, me, mid in
      guard let myself = me else {
        return
      }//end guard
      let mosquitto = Unmanaged<Mosquitto>.fromOpaque(myself).takeUnretainedValue()
      mosquitto.OnUnsubscribe(mid)
    }//end set
    mosquitto_log_callback_set(h) { _, me, level, pstr in
      guard let myself = me, let str = pstr else {
        return
      }//end guard
      let mosquitto = Unmanaged<Mosquitto>.fromOpaque(myself).takeUnretainedValue()
      let string = String(cString: str)
      guard let lvl = LogLevel(rawValue: level) else {
        mosquitto.OnLog(.ALL, string)
        return
      }//end guard
      mosquitto.OnLog(lvl, string)
    }//end set
  }//end func

  public static var Panic: Exception {
    get {
      switch errno {
      case ENOMEM: return Exception.NOMEM
      case EINVAL: return Exception.INVAL
      default: return Exception.UNKNOWN
      }//end case
    }//end get
  }//end Panic

  /// Constructor: create a new mosquitto client instance.
  /// - parameters:
  ///   - id: String to use as the client id. If nil, a random client id will be generated and cleanSession will be automatically overrudde to true.
  ///   - cleanSession: Bool, set to true to instruct the broker to clean all messages and subscriptions on disconnect, false to instruct it to keep them.
  /// - throws:
  ///   Exception
  public init(id: String? = nil, cleanSession: Bool = true) throws {
    let this = Unmanaged.passRetained(self).toOpaque()
    if let name = id {
      _handle = mosquitto_new(name, cleanSession, this)
    }else {
      _handle = mosquitto_new(nil, true, this)
    }//end if
    guard let h = _handle else {
      throw Mosquitto.Panic
    }//end guard
    setupCallbacks(h)
  }//end init

  /// This function allows an existing mosquitto client to be reused. Call on a mosquitto instance to close any open network connections, free memory and reinitialise the client with the new parameters.
  /// - parameters:
  ///   - id: String to use as the client id. If nil, a random client id will be generated and cleanSession will be automatically overrudde to true.
  ///   - cleanSession: Bool, set to true to instruct the broker to clean all messages and subscriptions on disconnect, false to instruct it to keep them.
  /// - throws:
  ///   Exception
  public func reset(id: String? = nil, cleanSession: Bool = true) throws {
    guard let h = _handle else {
      throw Mosquitto.Panic
    }//end guard
    let this = Unmanaged.passRetained(self).toOpaque()
    var ret: Int32
    if let name = id {
      ret = mosquitto_reinitialise(h, name, cleanSession, this)
    }else {
      ret = mosquitto_reinitialise(h, nil, true, this)
    }//end if
    guard ret == Exception.SUCCESS.rawValue else {
      throw Mosquitto.Panic
    }//end guard
    setupCallbacks(h)
  }//end init

  /// Connect to an MQTT broker.
  /// - parameters:
  ///   - host:String, the hostname or ip address of the broker to connect to.
  ///   - port:Int32, the network port to connect to. Usually 1883.
  ///   - keepalive: Int32 - the number of seconds after which the broker should send a PING message to the client if no other messages have been exchanged in that time.
  ///   - binding: String, optional, bind socket to a specific address
  /// - throws:
  ///   Exception
  public func connect(host:String, port: Int32 = 1883, keepAlive: Int32 = 10, binding: String? = nil, asynchronous: Bool = true) throws {
    guard let h = _handle else {
      throw Mosquitto.Panic
    }//end guard
    var r = Int32(0)
    if let b = binding {
      r = asynchronous ? mosquitto_connect_bind_async(h, host, port, keepAlive, b)
        : mosquitto_connect_bind(h, host, port, keepAlive, b)
    }else{
      r = asynchronous ? mosquitto_connect_async(h, host, port, keepAlive)
        : mosquitto_connect(h, host, port, keepAlive)
    }//end if
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
  }//end connect

  public func reconnect(_ asynchronous: Bool = true) throws {
    guard let h = _handle else {
      throw Mosquitto.Panic
    }//end guard
    let r = asynchronous ? mosquitto_reconnect_async(h) : mosquitto_reconnect(h)
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
  }//end reconnect

  ///  Control the behaviour of the client when it has unexpectedly disconnected
  /// in <mosquitto_loop_forever> or after <mosquitto_loop_start>. 
  /// The default behaviour if this function is not used is to repeatedly 
  /// attempt to reconnect with a delay of 1 second until the connection succeeds.
  /// Use reconnect_delay parameter to change the delay between successive 
  /// reconnection attempts. You may also enable exponential backoff of the time
  /// between reconnections by setting reconnect_exponential_backoff to true and
  /// set an upper bound on the delay with reconnect_delay_max.
  /// Example 1:
  ///	delay=2, delay_max=10, exponential_backoff=False
  ///	Delays would be: 2, 4, 6, 8, 10, 10, ...
  /// Example 2:
  ///	delay=3, delay_max=30, exponential_backoff=True
  ///	Delays would be: 3, 6, 12, 24, 30, 30, ...
  /// - parameters:
  ///   - delay:UInt32, the number of seconds to wait between reconnects.
  ///   - delayMax:UInt32, the maximum number of seconds to wait between reconnects.
  ///   - backoff:Bool, use exponential backoff between reconnect attempts. True to enable exponential backoff.
  /// - throws:
  ///   Exception
  public func reconnectSetDelay(delay: UInt32 = 2, delayMax: UInt32 = 10, backOff: Bool = false) throws {
    guard let h = _handle else {
      throw Mosquitto.Panic
    }//end guard
    let r = mosquitto_reconnect_delay_set(h, delay, delayMax, backOff)
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
  }//end setdelay

  public func disconnect() throws {
    guard let h = _handle else {
      throw Mosquitto.Panic
    }//end guard
    let r = mosquitto_disconnect(h)
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
  }//end disconnect

  public var socket: Int32? {
    get {
      guard let h = _handle else { return nil }
      let s = mosquitto_socket(h)
      guard s > -1 else { return nil }
      return s
    }//end get
  }//end socket

  /// Returns true if there is data ready to be written on the socket.
  public var writeReady: Bool? {
    get {
      guard let h = _handle else { return nil }
      return mosquitto_want_write(h)
    }//end get
  }//end

  public func login(username: String, password: String) throws {
    guard let h = _handle else {
      throw Mosquitto.Panic
    }//end guard
    let r = mosquitto_username_pw_set(h, username, password)
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
  }//end login

  /// Configure will information for a mosquitto instance. By default, clients do not have a will.
  /// - parameters:
  ///   - message: Message, which id will be ignored; would be cleared if nil.
  /// - throws:
  ///   Exception
  public func setConfigWill(message: Message?) throws {
    guard let h = _handle else {
      throw Mosquitto.Panic
    }//end guard
    var r = Int32(0)
    if let m = message {
      r = m.payload.withUnsafeBufferPointer { ptr -> Int32 in
        return mosquitto_will_set(h, m.topic, Int32(m.payload.count), ptr.baseAddress, m.qos, m.retain)
      }//end r
    }else {
      r = mosquitto_will_clear(h)
    }//end if
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
  }//end setConfigWill

  /// Publish a message on a given topic.
  /// - parameters:
  ///   - message: Message, which id will be ignored and a new id will return instead
  /// - returns: 
  ///   message id
  /// - throws:
  ///   Exception
  public func publish(message: Message) throws ->Int32 {
    guard let h = _handle else {
      throw Mosquitto.Panic
    }//end guard
    var mid = Int32(0)
    let r = message.payload.withUnsafeBufferPointer { ptr -> Int32 in
        return mosquitto_publish(h, &mid, message.topic, Int32(message.payload.count), ptr.baseAddress, message.qos, message.retain)
    }//end r
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
    return mid
  }//end setConfigWill

  /// Subscribe to a topic
  /// - parameters:
  ///   - id: Int32?, if not nil, the function will set it to the message id of this particular message. This can be then used with the subscribe callback to determine when the message has been sent.
  ///   - topic: the topic to subscribe
  ///   - qos: Int32, quality of service for this subscription can be 0, 1, or 2
  /// - throws:
  ///   Exception
  public func subscribe(messageId: Int32? = nil, topic: String, qos: Int32 = 0) throws {
    guard let h = _handle else {
      throw Mosquitto.Panic
    }//end guard
    var r = Int32(0)
    if let msgId = messageId {
      var mid = msgId
      r = mosquitto_subscribe(h, &mid, topic, qos)
    } else {
      r = mosquitto_subscribe(h, nil, topic, qos)
    }//end if
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
  }//end subscribe

  /// Unsubscribe to a topic
  /// - parameters:
  ///   - id: Int32?, if not nil, the function will set it to the message id of this particular message, This can be then used with the unsubscribe callback to determine when the message has beensent.
  ///   - topic: the topic to unsubscribe
  /// - throws:
  ///   Exception
  public func unsubscribe(messageId: Int32? = nil, topic: String) throws {
    guard let h = _handle else {
      throw Mosquitto.Panic
    }//end guard
    var r = Int32(0)
    if let msgId = messageId {
      var mid = msgId
      r = mosquitto_unsubscribe(h, &mid, topic)
    } else {
      r = mosquitto_unsubscribe(h, nil, topic)
    }//end if
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
  }//end unsubscribe

  /// start network traffic
  /// - throws:
  ///   - Exception
  public func start() throws {
    guard let h = _handle else {
      throw Mosquitto.Panic
    }//end guard
    let r = mosquitto_loop_start(h)
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
  }//end start

  /// stop network traffic
  /// - throws:
  ///   - Exception
  public func stop(force: Bool = false) throws {
    guard let h = _handle else {
      throw Mosquitto.Panic
    }//end guard
    let r = mosquitto_loop_stop(h, force)
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
  }//end start

  /// Deconstructor
  deinit {
    guard let h = _handle else {
      return
    }//end guard
    let _ = mosquitto_loop_stop(h, true)
    mosquitto_destroy(h)
  }//end deinit
}//end class
