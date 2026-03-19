// Workspace root discovery for Swift projects.
// Walks up from the input file looking for Package.swift, .xcodeproj, .xcworkspace, or .git.

import Foundation

public enum Workspace {

    public static func findRoot(from path: String) -> String {
        let fm = FileManager.default
        var dir = (path as NSString).deletingLastPathComponent

        while dir != "/" {
            if fm.fileExists(atPath: (dir as NSString).appendingPathComponent("Package.swift")) {
                return dir
            }

            if let contents = try? fm.contentsOfDirectory(atPath: dir) {
                if contents.contains(where: { $0.hasSuffix(".xcodeproj") }) {
                    return dir
                }
                if contents.contains(where: { $0.hasSuffix(".xcworkspace") }) {
                    return dir
                }
            }

            if fm.fileExists(atPath: (dir as NSString).appendingPathComponent(".git")) {
                return dir
            }

            dir = (dir as NSString).deletingLastPathComponent
        }

        return (path as NSString).deletingLastPathComponent
    }

    public static func discoverPackageName(root: String) -> String {
        let packageSwiftPath = (root as NSString).appendingPathComponent("Package.swift")

        if let contents = try? String(contentsOfFile: packageSwiftPath, encoding: .utf8) {
            let pattern = #"name:\s*"([^"]+)""#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(
                   in: contents,
                   range: NSRange(contents.startIndex..., in: contents)
               ) {
                if let range = Range(match.range(at: 1), in: contents) {
                    return String(contents[range])
                }
            }
        }

        return (root as NSString).lastPathComponent
    }
}
