// Workspace root discovery for Swift projects.
// Walks up from the input file looking for Package.swift, .xcodeproj, .xcworkspace, or .git.

import Foundation

enum Workspace {

    /// Find the workspace root by walking up from the given path.
    /// Priority: Package.swift > *.xcodeproj > *.xcworkspace > .git
    static func findRoot(from path: String) -> String {
        let fm = FileManager.default
        var dir = (path as NSString).deletingLastPathComponent

        while dir != "/" {
            // Check for Package.swift (SPM)
            if fm.fileExists(atPath: (dir as NSString).appendingPathComponent("Package.swift")) {
                return dir
            }

            // Check for .xcodeproj
            if let contents = try? fm.contentsOfDirectory(atPath: dir) {
                if contents.contains(where: { $0.hasSuffix(".xcodeproj") }) {
                    return dir
                }
                if contents.contains(where: { $0.hasSuffix(".xcworkspace") }) {
                    return dir
                }
            }

            // Check for .git
            if fm.fileExists(atPath: (dir as NSString).appendingPathComponent(".git")) {
                return dir
            }

            dir = (dir as NSString).deletingLastPathComponent
        }

        // Fallback: parent directory of the file
        return (path as NSString).deletingLastPathComponent
    }

    /// Discover the project/package name from the workspace root.
    /// Attempts to parse `Package.swift` for the package name.
    /// Falls back to the directory name.
    static func discoverPackageName(root: String) -> String {
        let packageSwiftPath = (root as NSString).appendingPathComponent("Package.swift")

        if let contents = try? String(contentsOfFile: packageSwiftPath, encoding: .utf8) {
            // Look for: name: "PackageName" in the Package(...) initializer
            // Match patterns like: name: "foo-bar" or name: "FooBar"
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

        // Fallback: directory name
        return (root as NSString).lastPathComponent
    }
}
