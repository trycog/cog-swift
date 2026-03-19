// Version reading from cog-extension.json manifest.

import Foundation

public enum Version {
    public static func read() -> String {
        // Walk up from the executable to find cog-extension.json
        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()

        // Check sibling of bin/ (i.e., repo root)
        let repoRoot = executableURL.deletingLastPathComponent()
        let manifestPath = repoRoot.appendingPathComponent("cog-extension.json").path

        if let data = FileManager.default.contents(atPath: manifestPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let version = json["version"] as? String {
            return version
        }

        // Fallback: check current directory
        let cwdPath = FileManager.default.currentDirectoryPath + "/cog-extension.json"
        if let data = FileManager.default.contents(atPath: cwdPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let version = json["version"] as? String {
            return version
        }

        return "0.1.0"
    }
}
