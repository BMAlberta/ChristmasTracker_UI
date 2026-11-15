//
//  BrandAssetsTests.swift
//  ChristmasTrackerTests
//
//  Story BA1-A1: the app icon, launch glyph, launch background and launch screen config on disk
//  hold the brief's values. Pure file reads from the source tree (found from #filePath): JSON,
//  plist and PNG header bytes. No image decoding.
//

import Foundation
import Testing

@Suite("Brand assets Tests")
struct BrandAssetsTests {

    // MARK: - Helpers

    private static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    private static func tree(_ file: String = #filePath) throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: file), "source tree not found from \(file)")
    }

    private static func json(_ url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any],
                            "not a JSON object: \(url.lastPathComponent)")
    }

    /// The `luminosity` appearance value of a catalog entry, or nil when it has no appearances.
    private static func luminosity(_ entry: [String: Any]) -> String? {
        guard let appearances = entry["appearances"] as? [[String: String]] else { return nil }
        return appearances.first { $0["appearance"] == "luminosity" }?["value"]
    }

    private static func header(_ url: URL) throws -> [UInt8] {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try #require(try handle.read(upToCount: 26), "no data in \(url.lastPathComponent)")
        return [UInt8](data)
    }

    private static func bigEndian(_ bytes: [UInt8], _ offset: Int) -> Int {
        (0..<4).reduce(0) { ($0 << 8) | Int(bytes[offset + $1]) }
    }

    private static func requirePNG(_ bytes: [UInt8], _ name: String) throws {
        try #require(bytes.count == 26, "short header: \(name)")
        #expect(Array(bytes[0..<8]) == pngSignature, "PNG signature: \(name)")
        #expect(Array(bytes[12..<16]) == Array("IHDR".utf8), "IHDR tag: \(name)")
    }

    private static func assetURL(_ tree: ItemSourceTree, _ relative: String) -> URL {
        tree.file("Assets.xcassets/\(relative)")
    }

    // MARK: - App icon

    @Test("The app icon has default, dark and tinted slots, with files for default and dark only")
    func appIconSlots() throws {
        let tree = try Self.tree()
        let contents = try Self.json(Self.assetURL(tree, "AppIcon.appiconset/Contents.json"))
        let images = try #require(contents["images"] as? [[String: Any]])
        #expect(images.count == 3)
        for image in images {
            #expect(image["idiom"] as? String == "universal")
            #expect(image["platform"] as? String == "ios")
            #expect(image["size"] as? String == "1024x1024")
        }
        let defaultSlot = try #require(images.first { Self.luminosity($0) == nil })
        let darkSlot = try #require(images.first { Self.luminosity($0) == "dark" })
        let tintedSlot = try #require(images.first { Self.luminosity($0) == "tinted" })
        #expect(defaultSlot["filename"] as? String == "app-icon-1024.png")
        #expect(darkSlot["filename"] as? String == "app-icon-dark-1024.png")
        #expect(tintedSlot["filename"] == nil)
        for name in ["app-icon-1024.png", "app-icon-dark-1024.png"] {
            #expect(FileManager.default.fileExists(atPath: Self.assetURL(tree, "AppIcon.appiconset/\(name)").path),
                    "missing \(name)")
        }
    }

    @Test("Both app icon PNGs are 1024x1024, 8-bit RGB without alpha")
    func appIconPNGHeaders() throws {
        let tree = try Self.tree()
        for name in ["app-icon-1024.png", "app-icon-dark-1024.png"] {
            let bytes = try Self.header(Self.assetURL(tree, "AppIcon.appiconset/\(name)"))
            try Self.requirePNG(bytes, name)
            #expect(Self.bigEndian(bytes, 16) == 1024, "width: \(name)")
            #expect(Self.bigEndian(bytes, 20) == 1024, "height: \(name)")
            #expect(bytes[24] == 8, "bit depth: \(name)")
            #expect(bytes[25] == 2, "color type (2 = RGB, no alpha): \(name)")
        }
    }

    // MARK: - Launch glyph

    private static let glyphScales: [(scale: String, width: Int)] = [("1x", 120), ("2x", 240), ("3x", 360)]

    @Test("The launch glyph has one light and one dark file for each of 1x, 2x and 3x")
    func launchGlyphEntries() throws {
        let tree = try Self.tree()
        let contents = try Self.json(Self.assetURL(tree, "LaunchGlyph.imageset/Contents.json"))
        let images = try #require(contents["images"] as? [[String: Any]])
        #expect(images.count == 6)
        for (scale, width) in Self.glyphScales {
            for (appearance, luminosity) in [("light", nil), ("dark", "dark")] as [(String, String?)] {
                let matches = images.filter {
                    $0["scale"] as? String == scale && Self.luminosity($0) == luminosity
                }
                #expect(matches.count == 1, "\(appearance) \(scale)")
                let entry = try #require(matches.first)
                let expected = "launch-glyph-\(appearance)-\(width).png"
                #expect(entry["idiom"] as? String == "universal")
                #expect(entry["filename"] as? String == expected)
                #expect(FileManager.default.fileExists(atPath: Self.assetURL(tree, "LaunchGlyph.imageset/\(expected)").path),
                        "missing \(expected)")
            }
        }
    }

    @Test("The launch glyph PNGs are 120, 240 and 360 pixels wide")
    func launchGlyphWidths() throws {
        let tree = try Self.tree()
        for appearance in ["light", "dark"] {
            for (_, width) in Self.glyphScales {
                let name = "launch-glyph-\(appearance)-\(width).png"
                let bytes = try Self.header(Self.assetURL(tree, "LaunchGlyph.imageset/\(name)"))
                try Self.requirePNG(bytes, name)
                #expect(Self.bigEndian(bytes, 16) == width, "width: \(name)")
            }
        }
    }

    @Test("The launch glyph keeps original rendering (no template)")
    func launchGlyphHasNoTemplateRendering() throws {
        let tree = try Self.tree()
        let url = Self.assetURL(tree, "LaunchGlyph.imageset/Contents.json")
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(!text.contains("template"))
        let contents = try Self.json(url)
        #expect(contents["properties"] == nil)
    }

    // MARK: - Launch background

    @Test("The launch background colorset holds the light and dark sRGB values")
    func launchBackgroundComponents() throws {
        let tree = try Self.tree()
        let contents = try Self.json(Self.assetURL(tree, "LaunchBackground.colorset/Contents.json"))
        let colors = try #require(contents["colors"] as? [[String: Any]])
        #expect(colors.count == 2)
        let expectations: [(String?, [String: String])] = [
            (nil, ["red": "0.980392157", "green": "0.976470588", "blue": "0.968627451", "alpha": "1.000000000"]),
            ("dark", ["red": "0.058823529", "green": "0.101960784", "blue": "0.090196078", "alpha": "1.000000000"])
        ]
        for (luminosity, components) in expectations {
            let entry = try #require(colors.first { Self.luminosity($0) == luminosity }, "entry \(luminosity ?? "light")")
            let color = try #require(entry["color"] as? [String: Any])
            #expect(color["color-space"] as? String == "srgb")
            let actual = try #require(color["components"] as? [String: String])
            for (key, value) in components {
                #expect(actual[key] == value, "\(luminosity ?? "light") \(key)")
            }
        }
    }

    // MARK: - Info.plist and project

    private static func launchScreen(_ tree: ItemSourceTree) throws -> [String: Any] {
        let data = try Data(contentsOf: tree.file("Info.plist"))
        let plist = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        #expect(plist["UILaunchStoryboardName"] == nil)
        return try #require(plist["UILaunchScreen"] as? [String: Any], "UILaunchScreen dictionary")
    }

    @Test("Info.plist declares a UILaunchScreen with the background colour and glyph, and no storyboard")
    func infoPlistLaunchScreen() throws {
        let tree = try Self.tree()
        let launchScreen = try Self.launchScreen(tree)
        #expect(Set(launchScreen.keys) == ["UIColorName", "UIImageName"])
        #expect(launchScreen["UIColorName"] as? String == "LaunchBackground")
        #expect(launchScreen["UIImageName"] as? String == "LaunchGlyph")
    }

    @Test("The names in UILaunchScreen resolve to assets in the catalog")
    func launchNamesResolveToAssets() throws {
        let tree = try Self.tree()
        let launchScreen = try Self.launchScreen(tree)
        let colorName = try #require(launchScreen["UIColorName"] as? String)
        let imageName = try #require(launchScreen["UIImageName"] as? String)
        let catalog = tree.file("Assets.xcassets")
        let enumerator = try #require(FileManager.default.enumerator(at: catalog, includingPropertiesForKeys: nil))
        var directories: [String: URL] = [:]
        for case let url as URL in enumerator where url.hasDirectoryPath {
            directories[url.lastPathComponent] = url
        }
        for name in ["\(colorName).colorset", "\(imageName).imageset"] {
            let directory = try #require(directories[name], "no asset directory \(name)")
            #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Contents.json").path),
                    "no Contents.json in \(name)")
        }
    }

    @Test("The project file does not generate a launch screen from a build setting")
    func projectFileDoesNotGenerateLaunchScreen() throws {
        let tree = try Self.tree()
        let project = tree.root.deletingLastPathComponent()
            .appendingPathComponent("ChristmasTracker.xcodeproj/project.pbxproj")
        let text = try String(contentsOf: project, encoding: .utf8)
        #expect(text.contains("INFOPLIST_FILE = ChristmasTracker/Info.plist"))
        #expect(!text.contains("INFOPLIST_KEY_UILaunchScreen_Generation = YES"))
    }
}
