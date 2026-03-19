// cog-swift: SCIP code intelligence indexer for Swift.
// Entry point: parse CLI args, analyze files concurrently, write SCIP protobuf output.

import Foundation

// MARK: - Progress Reporting

func emitProgress(event: String, path: String) {
    let json = "{\"type\":\"progress\",\"event\":\"\(event)\",\"path\":\"\(path)\"}"
    FileHandle.standardError.write(Data((json + "\n").utf8))
}

func emitDebug(event: String, attributes: [String: String] = [:]) {
    guard ProcessInfo.processInfo.environment["COG_SWIFT_DEBUG"] == "1" else { return }
    var dict: [String: String] = ["type": "debug", "event": event]
    for (k, v) in attributes { dict[k] = v }
    if let data = try? JSONSerialization.data(withJSONObject: dict) {
        FileHandle.standardError.write(data)
        FileHandle.standardError.write(Data("\n".utf8))
    }
}

// MARK: - Version

func readVersion() -> String {
    // Try to read version from cog-extension.json relative to the binary
    // Fall back to hardcoded version
    return "0.1.0"
}

// MARK: - File Analysis

struct FileResult: Sendable {
    var document: SCIPDocument
    var workspaceRoot: String
    var packageName: String
    var filePath: String
    var error: String?
}

func analyzeOneFile(path: String) -> FileResult {
    let absolutePath: String
    if path.hasPrefix("/") {
        absolutePath = path
    } else {
        absolutePath = FileManager.default.currentDirectoryPath + "/" + path
    }

    let root = Workspace.findRoot(from: absolutePath)
    let packageName = Workspace.discoverPackageName(root: root)

    guard let source = try? String(contentsOfFile: absolutePath, encoding: .utf8) else {
        return FileResult(
            document: SCIPDocument(language: "swift", relativePath: path, occurrences: [], symbols: []),
            workspaceRoot: root,
            packageName: packageName,
            filePath: path,
            error: "Could not read file"
        )
    }

    // Compute relative path from workspace root
    let relativePath: String
    if absolutePath.hasPrefix(root) {
        relativePath = String(absolutePath.dropFirst(root.count + 1))
    } else {
        relativePath = path
    }

    emitDebug(event: "file_start", attributes: [
        "path": path,
        "size_bytes": "\(source.utf8.count)",
    ])

    let document = analyzeFile(source: source, packageName: packageName, relativePath: relativePath)

    return FileResult(
        document: document,
        workspaceRoot: root,
        packageName: packageName,
        filePath: path
    )
}

// MARK: - Main

let args = Array(CommandLine.arguments.dropFirst())

guard let options = CLI.parse(args) else {
    FileHandle.standardError.write(Data("Usage: cog-swift --output <path> <file> [file ...]\n".utf8))
    exit(1)
}

let version = readVersion()

emitDebug(event: "index_start", attributes: [
    "files": "\(options.filePaths.count)",
    "pid": "\(ProcessInfo.processInfo.processIdentifier)",
])

// Process files concurrently
let results: [FileResult]

if options.filePaths.count == 1 {
    results = [analyzeOneFile(path: options.filePaths[0])]
} else {
    let lock = NSLock()
    nonisolated(unsafe) var collected: [FileResult] = []
    DispatchQueue.concurrentPerform(iterations: options.filePaths.count) { i in
        let result = analyzeOneFile(path: options.filePaths[i])
        lock.lock()
        collected.append(result)
        lock.unlock()
    }
    results = collected
}

// Emit progress events
for result in results {
    if let error = result.error {
        emitProgress(event: "file_error", path: result.filePath)
        emitDebug(event: "file_error", attributes: ["path": result.filePath, "error": error])
    } else {
        emitProgress(event: "file_done", path: result.filePath)
    }
}

// Determine workspace root from first result
let workspaceRoot = results.first?.workspaceRoot ?? FileManager.default.currentDirectoryPath

// Build SCIP index
let index = SCIPIndex(
    metadata: SCIPMetadata(
        toolInfo: SCIPToolInfo(
            name: "cog-swift",
            version: version,
            arguments: args
        ),
        projectRoot: "file://" + workspaceRoot,
        textDocumentEncoding: 1
    ),
    documents: results.map(\.document),
    externalSymbols: []
)

// Encode and write
let data = ProtobufEncoder.encode(index: index)

do {
    try data.write(to: URL(fileURLWithPath: options.outputPath))
} catch {
    FileHandle.standardError.write(Data("Error writing output: \(error)\n".utf8))
    exit(1)
}

emitDebug(event: "index_done", attributes: [
    "documents": "\(results.count)",
    "output_bytes": "\(data.count)",
])
