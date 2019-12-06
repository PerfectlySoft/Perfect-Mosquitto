//
//  PerfectMosquittoTests.swift
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
import XCTest
@testable import PerfectMosquitto
import Foundation

let mqttServer = "test.mosquitto.org"
class PerfectMosquittoTests: XCTestCase {

  deinit {
    Mosquitto.CloseLibrary()

  }

	func testVersions() {
		let testID = "06-versions"
    let m = Mosquitto(id: testID)
		do {
			try m.setClientOption(.V31)
		} catch( let err) {
			XCTFail("set V31 failed: \(err)")
		}
		do {
			try m.setClientOption(.V311)
		} catch( let err) {
			XCTFail("set V31 failed: \(err)")
		}
	}
  func testConnection() {

    let testID = "01-con-discon-success"
    let m = Mosquitto(id: testID)
    var connection = false
    m.OnConnect = { status in
      if status == .SUCCESS {
        connection = true
      }else{
        XCTFail("\(testID) connection failed: \(status)")
      }//end if
    }//end OnConnect
    do {
      try m.connect(host :mqttServer)
    }catch(let err) {
      XCTFail("\(testID) connect() fault: \(err)")
    }//end do
    var i = 0
    while connection == false && i < 1000 {
      do {
        try m.wait(0)
      }catch(let err) {
        XCTFail("\(testID) stop() fault: \(err)")
        return
      }//end do
      i += 1
    }//next
    print("---------------- \(testID) --------------")
    print("connection for \(i) ticks")
    do {
      try m.disconnect()
    }catch(let err) {
      XCTFail("\(testID) disconnect() fault: \(err)")
    }//end do
  }

  func testSubscription() {

    let testID = "subscribe-qos0-test"
    let m = Mosquitto(id: testID)
    var subscribed = false
    m.OnConnect = { status in
      guard status == .SUCCESS else {
        XCTFail("\(testID) connection failed: \(status)")
        return
      }//end if
      do {
        try m.subscribe(topic: "qos0/test")
      }catch (let err) {
        XCTFail("\(testID) subscription failure: \(err)")
      }//end catch
    }//end OnConnect
    m.OnSubscribe = { id, qosArray in
      subscribed = true
      print(id)
      print(qosArray)
    }//end onsubscribe
    do {
      try m.connect(host :mqttServer)
    }catch(let err) {
      XCTFail("\(testID) connection() fault: \(err)")
    }//end do
    var i = 0
    while subscribed == false && i < 1000 {
      do {
        try m.wait(0)
      }catch(let err) {
        XCTFail("\(testID) stop() fault: \(err)")
        return
      }//end do
      i += 1
    }//next
    print("---------------- \(testID) --------------")
    print("subscription for \(i) ticks")
    do {
      try m.disconnect()
    }catch(let err) {
      XCTFail("\(testID) disconnect() fault: \(err)")
    }//end do
  }

  func testUnsubscription() {

    let testID = "unsubscribe-test"
    let m = Mosquitto(id: testID)
    var unsubscribed = false
    m.OnConnect = { status in
      guard status == .SUCCESS else {
        XCTFail("\(testID) connection failed: \(status)")
        return
      }//end if
      do {
        try m.unsubscribe(topic: testID)
      }catch (let err) {
        XCTFail("\(testID) unsubscribe failure: \(err)")
      }//end catch
    }//end OnConnect
    m.OnUnsubscribe = { result in
      unsubscribed = true
      print(result)
    }//end onsubscribe
    do {
      try m.connect(host :mqttServer)
    }catch(let err) {
      XCTFail("\(testID) connection() fault: \(err)")
    }//end do
    var i = 0
    while unsubscribed == false && i < 1000 {
      do {
        try m.wait(0)
      }catch(let err) {
        XCTFail("\(testID) stop() fault: \(err)")
        return
      }//end do
      i += 1
    }//next
    print("---------------- \(testID) --------------")
    print("unsubscription for \(i) ticks")
    do {
      try m.disconnect()
    }catch(let err) {
      XCTFail("\(testID) disconnect() fault: \(err)")
    }//end do
  }

  func testMessaging() {

    let testID = "publish-qos1-test"
    let topic = "publish/test"
    let m = Mosquitto(id: testID)
    var received = 0
    m.OnConnect = { status in
      guard status == .SUCCESS else {
        XCTFail("\(testID) connection failed: \(status)")
        return
      }//end if
    }//end OnConnect
    m.OnMessage = { msg in
      print("\(testID) received #\(msg.id) => \(msg.string!)")
      received += 1
    }//end on Message
    do {
      try m.connect(host :mqttServer)
      m.setMessageRetry(max: 3)
      try m.subscribe(topic: topic)
    }catch(let err) {
      XCTFail("\(testID) connection() fault: \(err)")
    }//end do
    var i = 0
    var j = 0
    let total = 10
    while received < total && i < 3000 {
      do {
        if j <= total {
          var msg = Mosquitto.Message()
          msg.id = Int32(j)
          j += 1
          msg.topic = topic
          msg.string = "publication test 🇨🇳🇨🇦 #\(j)"
          let _ = try m.publish(message: msg)
        }//end if
        try m.wait(0)
        i += 1
      }catch(let err) {
        XCTFail("\(testID) stop() fault: \(err)")
        return
      }//end do
    }//next
    print("---------------- \(testID) --------------")
    print("receiving for \(received) ticks")
    do {
      try m.disconnect()
    }catch(let err) {
      XCTFail("\(testID) disconnect() fault: \(err)")
    }//end do
  }

  func testThreadMessaging() {

    let testID = "publish-threads-test"
    let topic = "publish/test2"
    let m = Mosquitto(id: testID)
    let total = 10
    var received = 0
    m.OnConnect = { status in
      guard status == .SUCCESS else {
        XCTFail("\(testID) connection failed: \(status)")
        return
      }//end if
    }//end OnConnect

    let exp = expectation(description: testID)

    m.OnMessage = { msg in
      print("\(testID) received #\(msg.id) => \(msg.string!)")
      received += 1
      if received == total {
        exp.fulfill()
      }//end if
    }//end on Message
    do {
      try m.connect(host :mqttServer)
      try m.subscribe(topic: topic)
      try m.start()
    }catch(let err) {
      XCTFail("\(testID) connection() fault: \(err)")
    }//end do
    for i in 0 ... total + 1 {
      do {
        var msg = Mosquitto.Message()
        msg.id = Int32(i)
        msg.topic = topic
        msg.string = "thread test 🇨🇳🇨🇦 #\(i)"
        let _ = try m.publish(message: msg)
      }catch(let err) {
        XCTFail("\(testID) stop() fault: \(err)")
        return
      }//end do
    }//next
    self.waitForExpectations(timeout: 5) { timeoutErr in
      if let err = timeoutErr {
        XCTFail("\(testID) timeout \(err)")
      }//end if
    }
    print("---------------- \(testID) --------------")
    print("receiving for \(received) ticks")
    do {
      try m.stop()
      try m.disconnect()
    }catch(let err) {
      XCTFail("\(testID) disconnect() fault: \(err)")
    }//end do
  }
/*
  func testPW() {

    let testID = "01-unpwd-set"
    let m = Mosquitto(id: testID)
    do {
      try m.login(username: "uname", password: ";'[08gn=#")
      try m.connect()
    }catch(let err) {
      XCTFail("\(testID) connect() fault: \(err)")
    }//end do
    print("---------------- \(testID) --------------")
    print("connection for password / username")
    do {
      try m.disconnect()
    }catch(let err) {
      XCTFail("\(testID) disconnect() fault: \(err)")
    }//end do
  }

  func testWill() {

    let testID = "01-will-set"
    let m = Mosquitto(id: testID)
    do {
      var msg = Mosquitto.Message()
      msg.topic = "topic/on/unexpected/disconnect"
      msg.string = "will message"
      try m.setConfigWill(message: msg)
      try m.connect(host :mqttServer)
    }catch(let err) {
      XCTFail("\(testID) connect() fault: \(err)")
    }//end do
    print("---------------- \(testID) --------------")
    print("connection for password / username")
    do {
      try m.disconnect()
    }catch(let err) {
      XCTFail("\(testID) disconnect() fault: \(err)")
    }//end do
  }
*/
  static var allTests : [(String, (PerfectMosquittoTests) -> () throws -> Void)] {
    Mosquitto.OpenLibrary()

    return [
      ("testConnection", testConnection),
      ("testSubscription", testSubscription),
      ("testUnsubscription", testUnsubscription),
      ("testMessaging", testMessaging),
      ("testThreadMessaging", testThreadMessaging),
			("testVersions", testVersions)
      //("testPW", testPW),
      //("testWill", testWill)
    ]
  }
}
