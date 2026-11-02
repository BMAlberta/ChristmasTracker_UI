// Instrumented.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation
@_exported import os
@_exported import Sentry

@attached(body)
public macro Instrumented() = #externalMacro(
    module: "TrackerInstrumentationMacros",
    type: "InstrumentedMacro")
