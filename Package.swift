// swift-tools-version:4.2
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

let package = Package(
  name: "PerfectMosquitto",
  products: [
    .library(name: "PerfectMosquitto", targets: ["PerfectMosquitto"]),
    ],
  dependencies: [
    ],
  targets: [
    .systemLibrary(name: "cmosquitto",
      pkgConfig: "libmosquitto",
      providers:[
        .brew(["mosquitto"]),
        .apt(["libmosquitto-dev"])
      ]
    ),
    .target(name: "PerfectMosquitto", dependencies: [
      "cmosquitto",
    ]),
    .testTarget(name: "PerfectMosquittoTests", dependencies: [
      "PerfectMosquitto",
      ]),
    ]
)
