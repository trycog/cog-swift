// CLI argument parsing for cog-swift.
// Expected invocation: cog-swift --output <path> <file> [file ...]

public struct CLIOptions: Sendable {
    public var filePaths: [String]
    public var outputPath: String
}

public enum CLI {
    public static func parse(_ args: [String]) -> CLIOptions? {
        var outputPath: String?
        var filePaths: [String] = []
        var i = 0

        while i < args.count {
            if args[i] == "--output" {
                i += 1
                guard i < args.count else { return nil }
                outputPath = args[i]
            } else {
                filePaths.append(args[i])
            }
            i += 1
        }

        guard let output = outputPath, !filePaths.isEmpty else {
            return nil
        }

        return CLIOptions(filePaths: filePaths, outputPath: output)
    }
}
