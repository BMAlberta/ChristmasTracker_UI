// PublicOperations.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.
//
// The four operations that require no bearer token and no 401-refresh attempt.
// Derived from the spec: operations with security: [] override the global bearerAuth requirement.
// Pinned by SpecConformanceTests.publicOperationIDsMatchSpec().

public let publicOperationIDs: Set<String> = [
    "checkAppVersion",
    "register",
    "login",
    "refreshToken"
]
