//
//  Package.swift
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
import PackageDescription

#if os(Linux)
let package = Package(
    name: "PerfectMosquitto",
    dependencies: [
      .Package(url: "https://github.com/PerfectlySoft/Perfect-libMosquitto.git", majorVersion: 1),
      .Package(url: "https://github.com/PerfectlySoft/Perfect-LinuxBridge.git", majorVersion: 2)
    ]
)
#else
let package = Package(
    name: "PerfectMosquitto",
    dependencies: [.Package(url: "https://github.com/PerfectlySoft/Perfect-libMosquitto.git", majorVersion: 1)]
)
#endif
