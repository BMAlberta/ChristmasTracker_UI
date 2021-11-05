//
//  Utilities.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/17/21.
//

import Foundation
import os

struct Configuration {
    
    static private let localHost = "http://127.0.0.1:3000"
    static private let devHost = "http://10.1.20.152:3000"
    static private let prodHost = "https://api.bmalberta.com"
    static private let configHost = "https://appstore.bmalberta.com"
    
    static func getUrl(forKey key: Path) -> String {
        return Self.prodHost + key.rawValue
    }
    
    static var configUrl: String {
        return Self.configHost + "/config/tracker/config.json"
    }
    
    
    enum Path: String {
        case auth = "/tracker/auth/login"
        case userDetails = "/tracker/users/"
        case ownedItems = "/tracker/items/owned"
        case itemsGroupedByUser = "/tracker/items/groupedByUser"
        case itemsForUser = "/tracker/items/user/"
        case addItem = "/tracker/items"
        case markPurchased = "/tracker/purchases"
        case markRetracted = "/tracker/purchases/retract"
        case resetPassword = "/tracker/auth/password/update"
        case updateItem = "/tracker/items/"
    }
    
    static var appVersion: String {
        guard let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return "--"
        }
        return versionString
    }
    
    static var buildDate: String {
        guard let infoPath = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let infoAttributes = try? FileManager.default.attributesOfItem(atPath: infoPath),
              let infoDate = infoAttributes[.modificationDate] as? Date else {
                  return "--"
              }
        return FormatUtility.convertDateToHumanReadable(rawDate: infoDate)
    }
    
    
    static func isUpdateAvailable(updateInfo: UpdateInfoModel?) -> Bool {
        guard let updateInfo = updateInfo else {
            return false
        }
        guard updateInfo.availableVersion.compare(Self.appVersion, options: .numeric) == .orderedDescending else {
            return false
        }
        
        guard let _ = URL(string: "itms-services://?action=download-manifest&url="+updateInfo.downloadUri) else {
            return false
        }
        return true
    }
    
    static func generateUpdateUri(updateInfo: UpdateInfoModel?) -> URL? {
        guard let updateInfo = updateInfo else {
            return nil
        }

        return URL(string: "itms-services://?action=download-manifest&url="+updateInfo.downloadUri)
    }
    
    
}

struct NetworkUtility {
    
    enum RequestType: String {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }
    
    static func createBaseRequest(url: URL, method: RequestType, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "auth-token")
        request.httpMethod = method.rawValue
        
        return request
    }
}

struct FormatUtility {
    static func convertDateStringToHumanReadable(rawDate: String?) -> String {
        guard let rawDate = rawDate else {
            return "--"
        }

        
        let fromFormatter = ISO8601DateFormatter()
        fromFormatter.formatOptions.insert(.withFractionalSeconds)

        guard let convertedRaw = fromFormatter.date(from: rawDate) else {
            return "--"
        }

        let toFormatter = DateFormatter()
        toFormatter.dateStyle = .long
        toFormatter.timeStyle = .short
        let targetFormat = toFormatter.string(from: convertedRaw)
        
        return targetFormat
    }
    
    static func convertDateToHumanReadable(rawDate: Date?) -> String {
        guard let rawDate = rawDate else {
            return "--"
        }

        let toFormatter = DateFormatter()
        toFormatter.dateStyle = .long
        toFormatter.timeStyle = .short
        let targetFormat = toFormatter.string(from: rawDate)
        
        return targetFormat
    }
    
    static func calculateTimeInterval(from fromDate: String?) -> Int {
        
        guard let rawDate = fromDate else {
            return 0
        }
        
        let fromFormatter = ISO8601DateFormatter()
        fromFormatter.formatOptions.insert(.withFractionalSeconds)

        guard let convertedFromRaw = fromFormatter.date(from: rawDate) else {
            return 0
        }
        
        let diffComponents = Calendar.current.dateComponents([.day], from: convertedFromRaw, to: Date())
        guard let numberOfDays = diffComponents.day else {
            return 0
        }
        
        return numberOfDays
    }
}

struct LogUtility {
    static private let subsystem = "com.alberta.ChristmasTracker"
    static let networking = OSLog(subsystem: Self.subsystem, category: "networking")
}
