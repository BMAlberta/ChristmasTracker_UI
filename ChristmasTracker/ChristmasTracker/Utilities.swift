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
    static private let devHost = "http://10.1.80.2:3000"
    static private let prodHost = "https://api.bmalberta.com"
    static private let configHost = "https://content.bmalberta.com"
    
    static func getUrl(forKey key: Path) -> String {
        return Self.stringValue(forKey: "API_SCHEME") +
        "//" +
        Self.stringValue(forKey: "BASE_API_HOST") +
        key.rawValue
    }
    
    static var configUrl: String {
        return Self.stringValue(forKey: "CONFIG_SCHEME") +
        "//" +
        Self.stringValue(forKey: "CONFIG_API_HOST") +
        "/config.json"
    }
    
    
    enum Path: String {
        case auth = "/tracker/auth/login"
        case lwEnroll = "/tracker/enroll/lw/createUser"
        case logout = "/tracker/auth/logout"
        case userDetails = "/tracker/users/"
        case ownedItems = "/tracker/items/owned"
        case ownedLists = "/tracker/lists/owned"
        case itemsGroupedByUser = "/tracker/lists/details/overviews"
        case listForId = "/tracker/lists/"
        case addItem = "/tracker/lists/details/addItem"
        case markPurchased = "/tracker/lists/purchase"
        case markRetracted = "/tracker/lists/purchase/retract"
        case resetPassword = "/tracker/auth/password/update"
        case updateItem = "/tracker/lists/details/update"
        case stats = "/tracker/stats/purchases"
        case addList = "/tracker/lists/create"
        case deleteItem = "/tracker/lists/details/"
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
    
    static func daysUntilChristmas() -> Int {
        let fmt = ISO8601DateFormatter()
        
        let date1 = Date.now
        let date2 = fmt.date(from: Self.stringValue(forKey: "CHRISTMAS_DATE"))!
        
        let diff = Calendar.current.dateComponents([.day], from: date1, to: date2)
        
        guard let numberOfDays = diff.day else {
            return 0
        }
        return numberOfDays + 1
    }
    static func stringValue(forKey key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String
        else {
            fatalError("Invalid value or undefined key")
        }
        return value
    }
    
}

struct NetworkUtility {
    
    enum RequestType: String {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }
    
    static func createBaseRequest(url: URL, method: RequestType) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
    
    static func convertDateOnlyStringToHumanReadable(rawDate: String?) -> String {
        guard let rawDate = rawDate else {
            return "--"
        }
        
        
        let fromFormatter = ISO8601DateFormatter()
        fromFormatter.formatOptions.insert(.withFractionalSeconds)
        
        guard let convertedRaw = fromFormatter.date(from: rawDate) else {
            return "--"
        }
        
        let toFormatter = DateFormatter()
        toFormatter.dateStyle = .medium
        toFormatter.timeStyle = .none
        let targetFormat = toFormatter.string(from: convertedRaw)
        
        return targetFormat
    }
    
    static func convertStringToDate(rawDate: String?) -> Date {
        guard let rawDate = rawDate else {
            return Date()
        }
        
        
        let fromFormatter = ISO8601DateFormatter()
        fromFormatter.formatOptions.insert(.withFractionalSeconds)
        
        guard let convertedRaw = fromFormatter.date(from: rawDate) else {
            return Date()
        }
        
        return convertedRaw
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
    
    static func formatInitials(members: [MemberDetail]) -> [String] {
        var initials: [String] = []
        
        for member in members {
            let temp = "\(member.firstName.first ?? "-")\(member.lastName.first ?? "-")"
            initials.append(temp)
        }
        
        return initials
    }
}

struct LogUtility {
    static private let subsystem = Configuration.stringValue(forKey: "LOG_SUBSYSTEM")
    static let networking = OSLog(subsystem: Self.subsystem, category: "networking")
    static let serviceError = OSLog(subsystem: Self.subsystem, category: "serviceError")
    
    static func logNetworkDetails(message: String, rawData: Data) {
#if DEBUG
        let stringData: String = String(data: rawData, encoding: String.Encoding.utf8)!
        let logData = String(format: "\n=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n%@:\n%@", message, stringData)
        Self.logMessage(osLog: Self.networking, message: logData)
#endif
    }
    
    static func logServiceError(message: String, error: Error) {
#if DEBUG
        let logData = String(format: "\n=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n%@:\n%@", message, String(describing: error))
        Self.logMessage(osLog: Self.serviceError, message: logData)
#endif
    }
    
    private static func logMessage(osLog: OSLog, message: String) {
#if DEBUG
        os_log("%s", log: osLog, message)
#endif
    }
}
