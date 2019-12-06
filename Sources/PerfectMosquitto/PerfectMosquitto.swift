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
  import Glibc
#else
  import Darwin
#endif

import cmosquitto

extension String {
  public var UTF8: [Int8] {
    get {
      return self.withCString { ptr -> [Int8] in
        let p = UnsafeBufferPointer<Int8>(start: ptr, count: self.utf8.count)
        return Array(p)
      }
    }//end get
  }//end var
  /// fix some non-zero ending of buffer issue
  public init(buffer: [Int8]) {
    var buf = buffer
    buf.append(0)
    self = String(cString: buf)
  }//end init
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

  /// Explain an exception
  /// - parameters:
  ///   - fault: Exception to explain
  public static func Explain(_ fault: Exception) -> String {
    return String(cString: mosquitto_strerror(fault.rawValue))
  }//end Explain

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

    /// constructor for receiving a message
    public init(message: mosquitto_message) {
      id = message.mid
      topic = String(cString: message.topic)
      let p = unsafeBitCast(message.payload, to: UnsafePointer<Int8>.self)
      let pbuf = UnsafeBufferPointer(start: p, count: Int(message.payloadlen))
      payload = Array(pbuf)
      qos = message.qos
      retain = message.retain
    }//init

    /// constructor for sending a message
    public init(id: Int32 = 0, topic: String = "", qos: Int32 = 0, retain: Bool = false) {
      self.id = id
      self.topic = topic
      self.qos = qos
      self.retain = retain
    }//end init

    /// payload can also be set or get by a string
    public var string: String? {
      get {
        let str = String(buffer: payload)
        if str.isEmpty { return nil }
        return str
      }//end get
      set {
        guard let str = newValue else {
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

  public var tlsPassword = ""

  // singleton to avoid multiple switching on; not thread safe
  private static var LibrarySwitch = false

  /// Initialize the libray, must call prior to all instances initialization.
  /// NOTE: Not Thread Safe
  public static func OpenLibrary() {
    if LibrarySwitch == false {
      LibrarySwitch = true
      let _ = mosquitto_lib_init()
    }//end if
  }//end func

  /// Initialize the libray, must call once all instances stopped.
  /// NOTE: Not Thread Safe
  public static func CloseLibrary() {
    if LibrarySwitch {
      LibrarySwitch = false
      let _ = mosquitto_lib_cleanup()
    }//end if
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

  /// Used to set options for the client.
  /// - parameters:
  ///   - version: MQTTVersion, default is .V31
  /// - throws:
  ///   Exception
  public func setClientOption(_ version: MQTTVersion = .V31) throws {
		var value = version.rawValue
		let r = mosquitto_opts_set(_handle, MOSQ_OPT_PROTOCOL_VERSION, &value)
    guard r == Exception.SUCCESS.rawValue else {
      throw Mosquitto.Panic
    }//end guard
  }//end setOption
  
  internal var _handle: OpaquePointer

  /// Callback Pointer Manager, because Unmanaged is not applicable for mosquitto, such as 
  /// call in the Swift:
  /// let this = Unmanaged.passRetained(self).toOpaque()
  /// call in the conventional C callback
  /// let mosquitto = Unmanaged<Mosquitto>.fromOpaque(myself).takeUnretainedValue()
  public static var Manager:[OpaquePointer: Mosquitto] = [:]

  /// Configure the client for certificate based SSL/TLS support.
  /// Must be called before `connect()`. Cannot be used in conjunction with setTSL(psk).
  /// Define the Certificate Authority certificates to be trusted (ie. the server
  /// certificate must be signed with one of these certificates) using cafile.
  ///
  /// If the server you are connecting to requires clients to provide a
  /// certificate, define certfile and keyfile with your client certificate and
  /// private key. If your private key is encrypted, provide a password .
  ///
  /// - parameters:
  ///   - caFile: String?, path to a file containing the PEM encoded trusted CA certificate files. Either cafile or capath must not be nil.
  ///   - caPath: String?, path to a directory containing the PEM encoded trusted CA certificate files. See mosquitto.conf for more details on configuring this directory. Either cafile or capath must not be nil.
  ///   - certFile: String?, path to a file containing the PEM encoded certificate file for this client. If nil, keyfile must be nil, too
  ///   - keyfile: String?, path to a file containing the PEM encoded private key for this client. if nil, the certfile must be nil, too.
  ///   - keyPass: String?, if keyfile is encrypted, set this password to decryption.
  /// - throws:
  ///   Exception
  public func setTLS(caFile: String?, caPath: String?, certFile: String? = nil, keyFile: String? = nil, keyPass: String? = nil) throws {
    var r = Int32(0)
    if let kp = keyPass {
      self.tlsPassword = kp
      r = mosquitto_tls_set(_handle, caFile, caPath, certFile, keyFile) { buf, size, rwflag, me in
        guard let myself = me, let mosquitto = Mosquitto.Manager[unsafeBitCast(myself, to: OpaquePointer.self)] else {
          return 0
        }//end guard
        if mosquitto.tlsPassword.isEmpty { return 0 }
        return mosquitto.tlsPassword.withCString { ptr -> Int32 in
          let l = Int32(strlen(ptr))
          let sz = l < size ? l : size - 1
          #if os(Linux)
            memcpy(buf!, ptr, Int(sz))
          #else
            memcpy(buf, ptr, Int(sz))
          #endif
          return sz
        }//end return password
      }//end tls-set
    }else{
      r = mosquitto_tls_set(_handle, caFile, caPath, certFile, keyFile, nil)
    }//end if certFile
    guard r == Exception.SUCCESS.rawValue else {
      throw Mosquitto.Panic
    }//end guard
  }//end setTLS

  /// enable or disable TLS settings, use for testing purpose
  /// - parameters:
  ///   - ignore: set to true to disable TLS setting
  /// - throws:
  ///   Mosquitto.Panic
  public func setTLS(ignore: Bool = true) throws {
    let r = mosquitto_tls_insecure_set(_handle, ignore)
    guard r == Exception.SUCCESS.rawValue else {
      throw Mosquitto.Panic
    }//end guard
  }

  /// SSL Verify Options
  public enum SSLVerify: Int32 {
    /// ignore verification, i.e., no security required.
    case NONE = 0
    /// the server certificate will be verified and the connection aborted if the verification fails
    case PEER = 1
  }//end enum

  /// Set advanced SSL/TLS options.  Must be called before `connect()`.
  /// - parameters:
  ///   - verify: SSLVerify, default value .PEER.
  ///   - version: String, the version of the SSL/TLS protocol to use as a string. If nil, the default value is used.  The default value and the available values depend on the version of openssl that the library was compiled against. For openssl >= 1.0.1, the available options are tlsv1.2, tlsv1.1 and tlsv1, with tlv1.2 as the default. For openssl < 1.0.1, only tlsv1 is available.
  ///   - ciphers: String, a string describing the ciphers available for use.  See the “openssl ciphers” tool for more information. If nil, the default ciphers will be used.
  /// - throws:
  ///   Mosquitto.Panic
  public func setTLS(verify: SSLVerify = .PEER, version: String? = nil, ciphers: String? = nil) throws {
    let r = mosquitto_tls_opts_set(_handle, verify.rawValue, version, ciphers)
    guard r == Exception.SUCCESS.rawValue else {
      throw Mosquitto.Panic
    }//end guard
  }//end setTLS

  /// Configure the client for pre-shared-key based TLS support. 
  /// Must be called before `connect()`.
  /// Cannot be used in conjunction with setTLS(caFile).
  /// - parameters:
  ///   - psk: String, the pre-shared-key in hex format with no leading “0x”.
  ///   - identity: String, the identity of this client.May be used as the username depending on the server settings.
  ///   - ciphers: String, a string describing the PSK ciphers available for use. See the “openssl ciphers” tool for more information. If nil, the default ciphers will be used.
  /// - throws:
  ///   Mosquitto.Panic
  public func setTLS(psk: String, identity: String, ciphers: String? = nil) throws {
    let r = mosquitto_tls_psk_set(_handle, psk, identity, ciphers)
    guard r == Exception.SUCCESS.rawValue else {
      throw Mosquitto.Panic
    }//end guard
  }//end setTLS

  /// Used to tell the library that your application is using threads, but not `start()`.
  /// The library operates slightly differently when not in threaded mode in order to simplify its operation. 
  /// If you are managing your own threads and do not use this function you will experience crashes due to race conditions.When using <mosquitto_loop_start>, this is set automatically.
  /// - parameters:
  ///   - yes: Bool, true for enabling threads
  public func enableThreads(_ yes: Bool) throws {
    let r = mosquitto_threaded_set(_handle, yes)
    guard r == Exception.SUCCESS.rawValue else {
      throw Mosquitto.Panic
    }//end guard
  }//end enableThreads

  /// setup all callbacks
  internal func setupCallbacks(_ h: OpaquePointer) {
    let _ = mosquitto_connect_callback_set(h) { me, obj, code in
      guard let this = me, let mosquitto = Mosquitto.Manager[this] else {
        return
      }//end guard
      guard let ret = ConnectionStatus(rawValue: code) else {
        mosquitto.OnConnect(.ELSE)
        return
      }//end ret
      mosquitto.OnConnect(ret)
    }//end set
    let _ = mosquitto_disconnect_callback_set(h) { me, _, code in
      guard let this = me, let mosquitto = Mosquitto.Manager[this] else {
        return
      }//end guard
      guard code == ConnectionStatus.SUCCESS.rawValue else {
        mosquitto.OnDisconnect(.ELSE)
        return
      }//end ret
      mosquitto.OnDisconnect(.SUCCESS)
    }//end set
    let _ = mosquitto_publish_callback_set(h) { me, _, code in
      guard let this = me, let mosquitto = Mosquitto.Manager[this] else {
        return
      }//end guard
      mosquitto.OnPublish(code)
    }//end set
    let _ = mosquitto_message_callback_set(h) { me, _, pMsg in
      guard let this = me,
        let mosquitto = Mosquitto.Manager[this],
        let msg = pMsg else {
        return
      }//end guard
      mosquitto.OnMessage(Message(message: msg.pointee))
      // necessary?
      // mosquitto_message_free(&pMsg)
    }//end set
    let _ = mosquitto_subscribe_callback_set(h) { me, _, mid, count, granted_qos in
      guard let this = me,
        let mosquitto = Mosquitto.Manager[this],
        let pQos = granted_qos else {
        return
      }//end guard
      let qos = UnsafeBufferPointer(start: pQos, count: Int(count))
      mosquitto.OnSubscribe(mid, Array(qos))
    }//end set
    let _ = mosquitto_unsubscribe_callback_set(h) { me, _, mid in
      guard let this = me,
        let mosquitto = Mosquitto.Manager[this]
        else {
          return
      }//end guard
      mosquitto.OnUnsubscribe(mid)
    }//end set
    let _ = mosquitto_log_callback_set(h) { me, _, level, pstr in
      guard let this = me,
        let mosquitto = Mosquitto.Manager[this],
        let str = pstr else {
        return
      }//end guard
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
  public init(id: String? = nil, cleanSession: Bool = true) {
    if let name = id {
      _handle = mosquitto_new(name, cleanSession, nil)
    }else {
      _handle = mosquitto_new(nil, true, nil)
    }//end if
    Mosquitto.Manager[_handle] = self
    setupCallbacks(_handle)
  }//end init

  /// This function allows an existing mosquitto client to be reused. Call on a mosquitto instance to close any open network connections, free memory and reinitialise the client with the new parameters.
  /// - parameters:
  ///   - id: String to use as the client id. If nil, a random client id will be generated and cleanSession will be automatically overrudde to true.
  ///   - cleanSession: Bool, set to true to instruct the broker to clean all messages and subscriptions on disconnect, false to instruct it to keep them.
  /// - throws:
  ///   Exception
  public func reset(id: String? = nil, cleanSession: Bool = true) throws {
    var ret: Int32
    let h = unsafeBitCast(_handle, to: UnsafeMutableRawPointer.self)
    if let name = id {
      ret = mosquitto_reinitialise(_handle, name, cleanSession, h)
    }else {
      ret = mosquitto_reinitialise(_handle, nil, true, h)
    }//end if
    guard ret == Exception.SUCCESS.rawValue else {
      throw Mosquitto.Panic
    }//end guard
    setupCallbacks(_handle)
  }//end init

  /// Connect to an MQTT broker.
  /// - parameters:
  ///   - host:String, the hostname or ip address of the broker to connect to.
  ///   - port:Int32, the network port to connect to. Usually 1883.
  ///   - keepalive: Int32 - the number of seconds after which the broker should send a PING message to the client if no other messages have been exchanged in that time.
  ///   - binding: String, optional, bind socket to a specific address
  /// - throws:
  ///   Exception
  public func connect(host:String = "localhost", port: Int32 = 1883, keepAlive: Int32 = 60, binding: String? = nil, asynchronous: Bool = false) throws {
    var r = Int32(0)
    if let b = binding {
      r = asynchronous ? mosquitto_connect_bind_async(_handle, host, port, keepAlive, b)
        : mosquitto_connect_bind(_handle, host, port, keepAlive, b)
    }else{
      r = asynchronous ? mosquitto_connect_async(_handle, host, port, keepAlive)
        : mosquitto_connect(_handle, host, port, keepAlive)
    }//end if
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
  }//end connect

  /// This function provides an easy way of reconnecting to a broker after a connection has been lost. 
  /// Don't call it before `connect()`
  /// - parameters:
  ///   - asynchronous: Bool, will return immediately and will not block the primary thread if true
  /// - throws:
  ///   Exceptoin
  public func reconnect(_ asynchronous: Bool = true) throws {
    let r = asynchronous ? mosquitto_reconnect_async(_handle) : mosquitto_reconnect(_handle)
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
    let r = mosquitto_reconnect_delay_set(_handle, delay, delayMax, backOff)
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
  }//end setdelay

  public func disconnect() throws {
    let r = mosquitto_disconnect(_handle)
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
  }//end disconnect

  /// get the socket handle of mosquitto
  public var socket: Int32? {
    get {
      let s = mosquitto_socket(_handle)
      guard s > -1 else { return nil }
      return s
    }//end get
  }//end socket

  /// Returns true if there is data ready to be written on the socket.
  public var writeReady: Bool {
    get {
      return mosquitto_want_write(_handle)
    }//end get
  }//end

  /// Configure username and password for a mosquitton instance.
  /// - parameters:
  ///   - username: String?, the username to send as a string, or nil to disable authentication.
  ///   - password: String?, the password to send as a string. Set to nil when username is valid in order to send just a username.
  /// - throws:
  ///   Exception
  public func login(username: String? = nil, password: String? = nil) throws {
    let r = mosquitto_username_pw_set(_handle, username, password)
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
    var r = Int32(0)
    if let m = message {
      r = m.payload.withUnsafeBufferPointer { ptr -> Int32 in
        return mosquitto_will_set(_handle, m.topic, Int32(m.payload.count), ptr.baseAddress, m.qos, m.retain)
      }//end r
    }else {
      r = mosquitto_will_clear(_handle)
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
  @discardableResult
  public func publish(message: Message) throws ->Int32 {
    var mid = Int32(0)
    let r = message.payload.withUnsafeBufferPointer { ptr -> Int32 in
        return mosquitto_publish(_handle, &mid, message.topic, Int32(message.payload.count), ptr.baseAddress, message.qos, message.retain)
    }//end r
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
    return mid
  }//end setConfigWill

  /// Set the number of QoS 1 and 2 messages that can be “in flight” at one time.  
  /// An in flight message is part way through its delivery flow. 
  /// Attempts to send further messages with publish() will result in 
  /// the messages being queued until the number of in flight messages reduces.
  /// A higher number here results in greater message throughput, 
  /// but if set higher than the maximum in flight messages on the broker 
  /// may lead to delays in the messages being acknowledged.
  /// - parameters:
  ///   - max: UInt32, the maximum number of inflight messages. Defaults to 20. Set to 0 for no maximum.
  /// - throws:
  ///   Exception
  public func setInflightMessages(max: UInt32 = 20) throws {
    let r = mosquitto_max_inflight_messages_set(_handle, max)
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
  }//end func

  /// Set the number of seconds to wait before retrying messages.  
  /// This applies to publish messages with QoS>0.  May be called at any time.
  /// - parameters:
  ///   - max: UInt32, the number of seconds to wait for a response before retrying.  Defaults to 20.
  public func setMessageRetry(max: UInt32 = 20) {
    mosquitto_message_retry_set(_handle, max)
  }//end func

  /// Subscribe to a topic
  /// - parameters:
  ///   - id: Int32?, if not nil, the function will set it to the message id of this particular message. This can be then used with the subscribe callback to determine when the message has been sent.
  ///   - topic: the topic to subscribe
  ///   - qos: Int32, quality of service for this subscription can be 0, 1, or 2
  /// - throws:
  ///   Exception
  public func subscribe(messageId: Int32? = nil, topic: String, qos: Int32 = 0) throws {
    var r = Int32(0)
    if let msgId = messageId {
      var mid = msgId
      r = mosquitto_subscribe(_handle, &mid, topic, qos)
    } else {
      r = mosquitto_subscribe(_handle, nil, topic, qos)
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
    var r = Int32(0)
    if let msgId = messageId {
      var mid = msgId
      r = mosquitto_unsubscribe(_handle, &mid, topic)
    } else {
      r = mosquitto_unsubscribe(_handle, nil, topic)
    }//end if
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
  }//end unsubscribe

  /// start network traffic in an independent thread; If synchronous operation
  /// is need, use `wait()` instead.
  /// - throws:
  ///   Exception
  public func start() throws {
    let r = mosquitto_loop_start(_handle)
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
  }//end start

  /// stop network traffic
  /// - throws:
  ///   Exception
  public func stop(force: Bool = true) throws {
    let r = mosquitto_loop_stop(_handle, force)
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
  }//end start

  /// The main network loop for the client. If you don't want it block the main
  /// thread, try start()/stop()
  /// You must call this frequently in order to keep communications 
  /// between the client and broker working.  If incoming data is present 
  /// it will then be processed.  Outgoing commands, from e.g.  publish(), 
  /// are normally sent immediately that their function is called, 
  /// but this is not always possible.  wait() will also attempt to send 
  /// any remaining outgoing messages, which also includes commands that 
  /// are part of the flow for messages with QoS>0.
  /// - parameters:
  ///   - timeout: UInt, Maximum number of milliseconds to wait for network activity in the select() call before timing out. By default, set to 0 for instant return.  Set negative to use the default of 1000ms.
  ///   - maxPackets: Int32, this parameter is currently unused and should be set to 1 for future compatibility.
  /// - throws:
  ///   Exception
  public func wait(_ timeout: Int32 = 0, maxPackets:Int32 = 1) throws {
    let r = mosquitto_loop(_handle, timeout, maxPackets)
    guard r == Exception.SUCCESS.rawValue else {
      throw Exception(rawValue: r) ?? Exception.UNKNOWN
    }//end guard
  }//end wait

  /// Deconstructor
  deinit {
    let _ = mosquitto_loop_stop(_handle, true)
    let _ = mosquitto_disconnect(_handle)
    mosquitto_destroy(_handle)
  }//end deinit
}//end class
