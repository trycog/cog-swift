// SCIP data structures matching the SCIP protobuf schema.
// See: https://github.com/sourcegraph/scip/blob/main/scip.proto

public struct SCIPIndex: Sendable {
    public var metadata: SCIPMetadata
    public var documents: [SCIPDocument]
    public var externalSymbols: [SCIPSymbolInformation]

    public init(metadata: SCIPMetadata, documents: [SCIPDocument], externalSymbols: [SCIPSymbolInformation]) {
        self.metadata = metadata
        self.documents = documents
        self.externalSymbols = externalSymbols
    }
}

public struct SCIPMetadata: Sendable {
    public var version: Int32 = 0
    public var toolInfo: SCIPToolInfo
    public var projectRoot: String
    public var textDocumentEncoding: Int32 = 1

    public init(version: Int32 = 0, toolInfo: SCIPToolInfo, projectRoot: String, textDocumentEncoding: Int32 = 1) {
        self.version = version
        self.toolInfo = toolInfo
        self.projectRoot = projectRoot
        self.textDocumentEncoding = textDocumentEncoding
    }
}

public struct SCIPToolInfo: Sendable {
    public var name: String
    public var version: String
    public var arguments: [String]

    public init(name: String, version: String, arguments: [String]) {
        self.name = name
        self.version = version
        self.arguments = arguments
    }
}

public struct SCIPDocument: Sendable {
    public var language: String
    public var relativePath: String
    public var occurrences: [SCIPOccurrence]
    public var symbols: [SCIPSymbolInformation]

    public init(language: String, relativePath: String, occurrences: [SCIPOccurrence], symbols: [SCIPSymbolInformation]) {
        self.language = language
        self.relativePath = relativePath
        self.occurrences = occurrences
        self.symbols = symbols
    }
}

public struct SCIPOccurrence: Sendable {
    public var range: [Int32]
    public var symbol: String
    public var symbolRoles: Int32
    public var syntaxKind: Int32 = 0
    public var enclosingRange: [Int32] = []

    public init(range: [Int32], symbol: String, symbolRoles: Int32, syntaxKind: Int32 = 0, enclosingRange: [Int32] = []) {
        self.range = range
        self.symbol = symbol
        self.symbolRoles = symbolRoles
        self.syntaxKind = syntaxKind
        self.enclosingRange = enclosingRange
    }
}

public struct SCIPSymbolInformation: Sendable {
    public var symbol: String
    public var documentation: [String] = []
    public var relationships: [SCIPRelationship] = []
    public var kind: Int32 = 0
    public var displayName: String = ""
    public var enclosingSymbol: String = ""

    public init(symbol: String, documentation: [String] = [], relationships: [SCIPRelationship] = [], kind: Int32 = 0, displayName: String = "", enclosingSymbol: String = "") {
        self.symbol = symbol
        self.documentation = documentation
        self.relationships = relationships
        self.kind = kind
        self.displayName = displayName
        self.enclosingSymbol = enclosingSymbol
    }
}

public struct SCIPRelationship: Sendable {
    public var symbol: String
    public var isReference: Bool = false
    public var isImplementation: Bool = false
    public var isTypeDefinition: Bool = false
    public var isDefinition: Bool = false

    public init(symbol: String, isReference: Bool = false, isImplementation: Bool = false, isTypeDefinition: Bool = false, isDefinition: Bool = false) {
        self.symbol = symbol
        self.isReference = isReference
        self.isImplementation = isImplementation
        self.isTypeDefinition = isTypeDefinition
        self.isDefinition = isDefinition
    }
}

public enum SymbolRole {
    public static let definition: Int32 = 0x1
    public static let `import`: Int32 = 0x2
    public static let writeAccess: Int32 = 0x4
    public static let readAccess: Int32 = 0x8
}

public enum SymbolKind {
    public static let `class`: Int32 = 7
    public static let constant: Int32 = 8
    public static let `enum`: Int32 = 11
    public static let enumMember: Int32 = 12
    public static let field: Int32 = 15
    public static let function: Int32 = 17
    public static let interface: Int32 = 21
    public static let method: Int32 = 26
    public static let module: Int32 = 29
    public static let parameter: Int32 = 37
    public static let property: Int32 = 41
    public static let `struct`: Int32 = 49
    public static let type: Int32 = 54
    public static let typeAlias: Int32 = 55
    public static let typeParameter: Int32 = 58
    public static let variable: Int32 = 61
}
