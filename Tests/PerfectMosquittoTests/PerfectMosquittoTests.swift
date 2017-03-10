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

class PerfectMosquittoTests: XCTestCase {
    func testExample() {
      Mosquitto.OpenLibrary()
      Mosquitto.CloseLibrary()
      let v = Mosquitto.Version
      print(v)
      XCTAssertEqual(v.major, 1)
      XCTAssertEqual(v.minor, 4)
      #if os(Linux)
        XCTAssertEqual(v.revision, 8)
      #else
        XCTAssertEqual(v.revision, 11)
      #endif

      do {
        let _ = try Mosquitto()
      }catch(let err) {
        print("fault: \(err)")
      }
    }


    static var allTests : [(String, (PerfectMosquittoTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
