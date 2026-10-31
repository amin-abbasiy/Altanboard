#!/usr/bin/env swift
import Foundation
import FoundationXML

struct ValidationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func require(_ condition: Bool, _ message: String) throws {
    guard condition else { throw ValidationError(message: message) }
}

struct ProjectValidator {
    let root: URL

    func run() throws {
        let projectURL = root.appendingPathComponent("Altanboard.xcodeproj/project.pbxproj")
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: projectURL), format: nil)
        guard let project = plist as? [String: Any],
              let objects = project["objects"] as? [String: [String: Any]],
              let rootID = project["rootObject"] as? String,
              let projectObject = objects[rootID],
              let mainGroup = projectObject["mainGroup"] as? String else {
            throw ValidationError(message: "Malformed Xcode project.")
        }

        func validateReferences(_ value: Any) throws {
            if let string = value as? String,
               string.range(of: "^[A-F0-9]{24}$", options: .regularExpression) != nil {
                try require(objects[string] != nil, "Dangling Xcode object reference: \(string)")
            } else if let array = value as? [Any] {
                for item in array { try validateReferences(item) }
            } else if let dictionary = value as? [String: Any] {
                for item in dictionary.values { try validateReferences(item) }
            }
        }
        try validateReferences(project)

        var files = Set<String>()
        func walkGroup(_ id: String, directory: URL) throws {
            guard let object = objects[id] else { return }
            if object["sourceTree"] as? String == "BUILT_PRODUCTS_DIR" { return }
            let resolved = (object["path"] as? String).map { directory.appendingPathComponent($0) } ?? directory
            if let children = object["children"] as? [String] {
                for child in children { try walkGroup(child, directory: resolved) }
            } else if object["isa"] as? String == "PBXFileReference" {
                try require(FileManager.default.fileExists(atPath: resolved.path), "Missing project file: \(resolved.path)")
                files.insert(resolved.standardizedFileURL.path)
            }
        }
        try walkGroup(mainGroup, directory: root)

        for directory in ["Altanboard", "Tests/WhiteboardCoreTests", "Tests/AltanboardAppTests"] {
            for file in try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent(directory), includingPropertiesForKeys: nil)
            where file.pathExtension == "swift" {
                try require(files.contains(file.standardizedFileURL.path), "Swift source missing from Xcode: \(file.lastPathComponent)")
            }
        }

        let configurations = objects.values.filter { $0["isa"] as? String == "XCBuildConfiguration" }
        for configuration in configurations {
            guard let settings = configuration["buildSettings"] as? [String: Any] else { continue }
            if let architecture = settings["ARCHS"] as? String {
                try require(architecture == "arm64", "The project must target Apple Silicon only.")
                try require(settings["SWIFT_VERSION"] as? String == "6.0", "Expected Swift 6 language mode.")
            }
            if settings["PRODUCT_BUNDLE_IDENTIFIER"] as? String == "local.altanboard.app" {
                try require(settings["ENABLE_APP_SANDBOX"] as? String == "YES", "App Sandbox must remain enabled.")
                try require(settings["CODE_SIGN_IDENTITY"] as? String == "-", "Local builds should use ad-hoc signing.")
            }
        }

        let localPackages = objects.values.filter { $0["isa"] as? String == "XCLocalSwiftPackageReference" }
        try require(localPackages.count == 1 && localPackages.first?["relativePath"] as? String == ".", "Expected the local core package.")
        try require(FileManager.default.fileExists(atPath: root.appendingPathComponent("Package.swift").path), "Missing package manifest.")

        let schemeData = try Data(contentsOf: root.appendingPathComponent("Altanboard.xcodeproj/xcshareddata/xcschemes/Altanboard.xcscheme"))
        try require(XMLParser(data: schemeData).parse(), "Malformed shared Xcode scheme.")
        let scheme = String(decoding: schemeData, as: UTF8.self)
        let targets = objects.filter { $0.value["isa"] as? String == "PBXNativeTarget" }
        for (id, target) in targets {
            try require(scheme.contains("BlueprintIdentifier=\"\(id)\""), "Scheme is missing target \(target["name"] ?? id).")
        }

        let entitlementData = try Data(contentsOf: root.appendingPathComponent("Altanboard/Altanboard.entitlements"))
        let entitlements = try PropertyListSerialization.propertyList(from: entitlementData, format: nil) as? [String: Bool]
        try require(entitlements == [
            "com.apple.security.app-sandbox": true,
            "com.apple.security.files.user-selected.read-write": true
        ], "Unexpected sandbox permissions.")

        let exampleData = try Data(contentsOf: root.appendingPathComponent("Examples/Drawing.json"))
        let example = try JSONSerialization.jsonObject(with: exampleData) as? [String: Any]
        try require(example?["formatVersion"] as? Int == 1, "Invalid example drawing.")
        print("Project verified: \(objects.count) Xcode objects, \(files.count) source/config files, arm64-only, sandboxed, shared build/test scheme.")
    }
}

do {
    let root = URL(
        fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath,
        isDirectory: true
    ).standardizedFileURL
    try ProjectValidator(root: root).run()
} catch {
    FileHandle.standardError.write(Data("Verification failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}
