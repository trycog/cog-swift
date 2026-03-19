import Testing
import Foundation
@testable import CogSwiftLib

// MARK: - CLI Tests

@Suite("CLI")
struct CLITests {
    @Test func parsesNormalArgs() {
        let opts = CLI.parse(["--output", "/tmp/out.scip", "a.swift", "b.swift"])
        #expect(opts != nil)
        #expect(opts?.outputPath == "/tmp/out.scip")
        #expect(opts?.filePaths == ["a.swift", "b.swift"])
    }

    @Test func parsesFilesBeforeOutput() {
        let opts = CLI.parse(["a.swift", "--output", "/tmp/out.scip", "b.swift"])
        #expect(opts != nil)
        #expect(opts?.outputPath == "/tmp/out.scip")
        #expect(opts?.filePaths == ["a.swift", "b.swift"])
    }

    @Test func returnsNilWithoutOutput() {
        let opts = CLI.parse(["a.swift", "b.swift"])
        #expect(opts == nil)
    }

    @Test func returnsNilWithoutFiles() {
        let opts = CLI.parse(["--output", "/tmp/out.scip"])
        #expect(opts == nil)
    }

    @Test func returnsNilWhenOutputMissingValue() {
        let opts = CLI.parse(["a.swift", "--output"])
        #expect(opts == nil)
    }

    @Test func returnsNilForEmptyArgs() {
        let opts = CLI.parse([])
        #expect(opts == nil)
    }
}

// MARK: - Symbol Tests

@Suite("Symbol Builder")
struct SymbolTests {
    @Test func escapesSimpleIdentifiers() {
        #expect(SCIPSymbolBuilder.escape("Foo") == "Foo")
        #expect(SCIPSymbolBuilder.escape("foo_bar") == "foo_bar")
        #expect(SCIPSymbolBuilder.escape("my-pkg") == "my-pkg")
    }

    @Test func escapesComplexIdentifiers() {
        // + is in the simple set, so +++ stays unescaped
        #expect(SCIPSymbolBuilder.escape("+++") == "+++")
        #expect(SCIPSymbolBuilder.escape("<>") == "`<>`")
        #expect(SCIPSymbolBuilder.escape("") == "``")
    }

    @Test func escapesBackticks() {
        #expect(SCIPSymbolBuilder.escape("a`b") == "`a``b`")
    }

    @Test func buildsPrefix() {
        #expect(SCIPSymbolBuilder.prefix(package: "MyPkg") == "file . MyPkg unversioned ")
    }

    @Test func buildsClassSymbol() {
        let sym = SCIPSymbolBuilder.classSymbol(package: "Pkg", name: "Foo")
        #expect(sym == "file . Pkg unversioned Foo#")
    }

    @Test func buildsNestedClassSymbol() {
        let sym = SCIPSymbolBuilder.classSymbol(package: "Pkg", owner: "Outer", name: "Inner")
        #expect(sym == "file . Pkg unversioned Outer#Inner#")

        // Deep nesting uses chained # descriptors
        let deep = SCIPSymbolBuilder.classSymbol(package: "Pkg", owner: "Outer.Inner", name: "Deep")
        #expect(deep == "file . Pkg unversioned Outer#Inner#Deep#")
    }

    @Test func buildsMethodSymbol() {
        let sym = SCIPSymbolBuilder.methodSymbol(package: "Pkg", owner: "Foo", name: "bar", arity: 2)
        #expect(sym == "file . Pkg unversioned Foo#bar(2).")
    }

    @Test func buildsFunctionSymbol() {
        let sym = SCIPSymbolBuilder.functionSymbol(package: "Pkg", name: "doStuff", arity: 1)
        #expect(sym == "file . Pkg unversioned doStuff(1).")
    }

    @Test func buildsPropertySymbol() {
        let sym = SCIPSymbolBuilder.propertySymbol(package: "Pkg", owner: "Foo", name: "count")
        #expect(sym == "file . Pkg unversioned Foo#count.")
    }

    @Test func buildsEnumMemberSymbol() {
        let sym = SCIPSymbolBuilder.enumMemberSymbol(package: "Pkg", owner: "Dir", name: "north")
        #expect(sym == "file . Pkg unversioned Dir#north.")
    }

    @Test func buildsTypeParameterSymbol() {
        let sym = SCIPSymbolBuilder.typeParameterSymbol(package: "Pkg", owner: "Container", name: "T")
        #expect(sym == "file . Pkg unversioned Container#[T]")
    }

    @Test func buildsLocalSymbol() {
        #expect(SCIPSymbolBuilder.localSymbol(index: 0) == "local 0")
        #expect(SCIPSymbolBuilder.localSymbol(index: 42) == "local 42")
    }

    @Test func buildsImportSymbol() {
        let sym = SCIPSymbolBuilder.importSymbol(moduleName: "Foundation")
        #expect(sym == "file . Foundation unversioned ")
    }

    @Test func buildsTypeAliasSymbolTopLevel() {
        let sym = SCIPSymbolBuilder.typeAliasSymbol(package: "Pkg", name: "StringArray")
        #expect(sym == "file . Pkg unversioned StringArray#")
    }

    @Test func buildsTypeAliasSymbolNested() {
        let sym = SCIPSymbolBuilder.typeAliasSymbol(package: "Pkg", owner: "Foo", name: "Elem")
        #expect(sym == "file . Pkg unversioned Foo#Elem#")
    }
}

// MARK: - Protobuf Tests

@Suite("Protobuf Encoder")
struct ProtobufTests {
    @Test func encodesVarintSmall() {
        let data = ProtobufEncoder.encodeVarint(1)
        #expect(data == Data([0x01]))
    }

    @Test func encodesVarintZero() {
        let data = ProtobufEncoder.encodeVarint(0)
        #expect(data == Data([0x00]))
    }

    @Test func encodesVarint127() {
        let data = ProtobufEncoder.encodeVarint(127)
        #expect(data == Data([0x7F]))
    }

    @Test func encodesVarint128() {
        let data = ProtobufEncoder.encodeVarint(128)
        #expect(data == Data([0x80, 0x01]))
    }

    @Test func encodesVarint300() {
        let data = ProtobufEncoder.encodeVarint(300)
        #expect(data == Data([0xAC, 0x02]))
    }

    @Test func encodesTag() {
        // Field 1, wire type 0 (varint) = 0x08
        let data = ProtobufEncoder.encodeTag(fieldNumber: 1, wireType: WireType.varint)
        #expect(data == Data([0x08]))

        // Field 1, wire type 2 (delimited) = 0x0A
        let data2 = ProtobufEncoder.encodeTag(fieldNumber: 1, wireType: WireType.delimited)
        #expect(data2 == Data([0x0A]))

        // Field 2, wire type 0 = 0x10
        let data3 = ProtobufEncoder.encodeTag(fieldNumber: 2, wireType: WireType.varint)
        #expect(data3 == Data([0x10]))
    }

    @Test func encodesStringField() {
        let data = ProtobufEncoder.encodeStringField(fieldNumber: 1, value: "hi")
        // Tag: field 1, wire type 2 = 0x0A; length: 2 = 0x02; "hi" = 0x68, 0x69
        #expect(data == Data([0x0A, 0x02, 0x68, 0x69]))
    }

    @Test func encodesEmptyStringAsEmpty() {
        let data = ProtobufEncoder.encodeStringField(fieldNumber: 1, value: "")
        #expect(data.isEmpty)
    }

    @Test func encodesInt32Field() {
        let data = ProtobufEncoder.encodeInt32Field(fieldNumber: 1, value: 1)
        // Tag: 0x08; value: 0x01
        #expect(data == Data([0x08, 0x01]))
    }

    @Test func encodesInt32ZeroAsEmpty() {
        let data = ProtobufEncoder.encodeInt32Field(fieldNumber: 1, value: 0)
        #expect(data.isEmpty)
    }

    @Test func encodesBoolField() {
        let trueData = ProtobufEncoder.encodeBoolField(fieldNumber: 1, value: true)
        #expect(trueData == Data([0x08, 0x01]))

        let falseData = ProtobufEncoder.encodeBoolField(fieldNumber: 1, value: false)
        #expect(falseData.isEmpty)
    }

    @Test func encodesPackedInt32() {
        let data = ProtobufEncoder.encodePackedInt32Field(fieldNumber: 1, values: [0, 5, 0, 10])
        // Should produce: tag(1, delimited) + length + packed varints
        #expect(!data.isEmpty)
        #expect(data[0] == 0x0A) // field 1, delimited
    }

    @Test func encodesFullDocument() {
        let doc = SCIPDocument(
            language: "swift",
            relativePath: "test.swift",
            occurrences: [
                SCIPOccurrence(range: [0, 0, 0, 3], symbol: "local 0", symbolRoles: SymbolRole.definition)
            ],
            symbols: [
                SCIPSymbolInformation(symbol: "local 0", kind: SymbolKind.variable, displayName: "foo")
            ]
        )
        let data = ProtobufEncoder.encode(document: doc)
        #expect(!data.isEmpty)
    }

    @Test func encodesFullIndex() {
        let index = SCIPIndex(
            metadata: SCIPMetadata(
                toolInfo: SCIPToolInfo(name: "test", version: "0.1.0", arguments: []),
                projectRoot: "file:///tmp",
                textDocumentEncoding: 1
            ),
            documents: [],
            externalSymbols: []
        )
        let data = ProtobufEncoder.encode(index: index)
        #expect(!data.isEmpty)
    }
}

// MARK: - Scope Tests

@Suite("Scope Stack")
struct ScopeTests {
    @Test func startsEmpty() {
        let stack = ScopeStack()
        #expect(stack.isEmpty)
        #expect(stack.count == 0)
        #expect(stack.current == nil)
    }

    @Test func pushAndPop() {
        var stack = ScopeStack()
        stack.push(Scope(kind: .class, name: "Foo", symbol: "Foo#"))
        #expect(stack.count == 1)
        #expect(stack.current?.name == "Foo")

        let popped = stack.pop()
        #expect(popped?.name == "Foo")
        #expect(stack.isEmpty)
    }

    @Test func enclosingTypeName() {
        var stack = ScopeStack()
        stack.push(Scope(kind: .class, name: "Outer", symbol: "Outer#"))
        stack.push(Scope(kind: .function, name: "doStuff", symbol: "doStuff()."))

        #expect(stack.enclosingTypeName() == "Outer")
    }

    @Test func enclosingTypeNameReturnsNilWhenNoType() {
        var stack = ScopeStack()
        stack.push(Scope(kind: .function, name: "main", symbol: "main()."))

        #expect(stack.enclosingTypeName() == nil)
    }

    @Test func qualifiedTypeName() {
        var stack = ScopeStack()
        stack.push(Scope(kind: .class, name: "Outer", symbol: "Outer#"))
        stack.push(Scope(kind: .struct, name: "Inner", symbol: "Inner#"))

        #expect(stack.qualifiedTypeName() == "Outer.Inner")
    }

    @Test func qualifiedTypeNameSkipsFunctions() {
        var stack = ScopeStack()
        stack.push(Scope(kind: .class, name: "Foo", symbol: "Foo#"))
        stack.push(Scope(kind: .function, name: "bar", symbol: "bar()."))
        stack.push(Scope(kind: .struct, name: "Baz", symbol: "Baz#"))

        #expect(stack.qualifiedTypeName() == "Foo.Baz")
    }

    @Test func localVariableLookup() {
        var stack = ScopeStack()
        stack.push(Scope(kind: .function, name: "test", symbol: "test()."))
        stack.defineLocal(name: "x", symbol: "local 0")

        #expect(stack.lookupLocal(name: "x") == "local 0")
        #expect(stack.lookupLocal(name: "y") == nil)
    }

    @Test func localVariableShadowing() {
        var stack = ScopeStack()
        stack.push(Scope(kind: .function, name: "outer", symbol: "outer()."))
        stack.defineLocal(name: "x", symbol: "local 0")
        stack.push(Scope(kind: .closure, name: "<closure>", symbol: "local 1"))
        stack.defineLocal(name: "x", symbol: "local 2")

        #expect(stack.lookupLocal(name: "x") == "local 2")

        stack.pop()
        #expect(stack.lookupLocal(name: "x") == "local 0")
    }
}

// MARK: - Analyzer Tests

@Suite("Analyzer")
struct AnalyzerTests {
    @Test func indexesClassDefinition() {
        let source = "class Foo { }"
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let classSymbol = doc.symbols.first { $0.displayName == "Foo" }
        #expect(classSymbol != nil)
        #expect(classSymbol?.kind == SymbolKind.class)
        #expect(classSymbol?.symbol.contains("Foo#") == true)
    }

    @Test func indexesStructDefinition() {
        let source = "struct Point { var x: Int }"
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let structSym = doc.symbols.first { $0.displayName == "Point" }
        #expect(structSym != nil)
        #expect(structSym?.kind == SymbolKind.struct)

        let propSym = doc.symbols.first { $0.displayName == "x" }
        #expect(propSym != nil)
        #expect(propSym?.kind == SymbolKind.property)
    }

    @Test func indexesEnumWithCases() {
        let source = """
        enum Color {
            case red
            case green
            case blue
        }
        """
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let enumSym = doc.symbols.first { $0.displayName == "Color" }
        #expect(enumSym != nil)
        #expect(enumSym?.kind == SymbolKind.enum)

        let caseSym = doc.symbols.first { $0.displayName == "red" }
        #expect(caseSym != nil)
        #expect(caseSym?.kind == SymbolKind.enumMember)
    }

    @Test func indexesProtocol() {
        let source = """
        protocol Drawable {
            associatedtype Color
            func draw()
        }
        """
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let protoSym = doc.symbols.first { $0.displayName == "Drawable" }
        #expect(protoSym != nil)
        #expect(protoSym?.kind == SymbolKind.interface)

        let assocSym = doc.symbols.first { $0.displayName == "Color" }
        #expect(assocSym != nil)
        #expect(assocSym?.kind == SymbolKind.typeParameter)

        let methodSym = doc.symbols.first { $0.displayName == "draw" }
        #expect(methodSym != nil)
        #expect(methodSym?.kind == SymbolKind.method)
    }

    @Test func indexesActor() {
        let source = """
        actor Counter {
            var count: Int = 0
            func increment() { count += 1 }
        }
        """
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let actorSym = doc.symbols.first { $0.displayName == "Counter" }
        #expect(actorSym != nil)
        #expect(actorSym?.kind == SymbolKind.class)
    }

    @Test func indexesFunctionWithParameters() {
        let source = "func add(x: Int, y: Int) -> Int { return x + y }"
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let funcSym = doc.symbols.first { $0.displayName == "add" }
        #expect(funcSym != nil)
        #expect(funcSym?.kind == SymbolKind.function)
        #expect(funcSym?.symbol.contains("add(2)") == true)

        let params = doc.symbols.filter { $0.kind == SymbolKind.parameter }
        #expect(params.count == 2)
    }

    @Test func indexesInitializer() {
        let source = """
        class Foo {
            init(value: Int) { }
        }
        """
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let initSym = doc.symbols.first { $0.displayName == "init" }
        #expect(initSym != nil)
        #expect(initSym?.kind == SymbolKind.method)
        #expect(initSym?.symbol.contains("init(1)") == true)
    }

    @Test func indexesDeinit() {
        let source = """
        class Foo {
            deinit { }
        }
        """
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let deinitSym = doc.symbols.first { $0.displayName == "deinit" }
        #expect(deinitSym != nil)
        #expect(deinitSym?.kind == SymbolKind.method)
    }

    @Test func indexesSubscript() {
        let source = """
        struct Foo {
            subscript(index: Int) -> String { return "" }
        }
        """
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let subSym = doc.symbols.first { $0.displayName == "subscript" }
        #expect(subSym != nil)
        #expect(subSym?.kind == SymbolKind.method)
    }

    @Test func indexesExtension() {
        let source = """
        struct Foo { }
        extension Foo {
            func bar() { }
        }
        """
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let methodSym = doc.symbols.first { $0.displayName == "bar" }
        #expect(methodSym != nil)
        #expect(methodSym?.kind == SymbolKind.method)
        #expect(methodSym?.symbol.contains("Foo#bar(0)") == true)
    }

    @Test func indexesTypealias() {
        let source = "typealias StringArray = [String]"
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let taSym = doc.symbols.first { $0.displayName == "StringArray" }
        #expect(taSym != nil)
        #expect(taSym?.kind == SymbolKind.typeAlias)
    }

    @Test func indexesGenericParameters() {
        let source = "struct Box<T, U> { var first: T; var second: U }"
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let typeParams = doc.symbols.filter { $0.kind == SymbolKind.typeParameter }
        let names = typeParams.map(\.displayName)
        #expect(names.contains("T"))
        #expect(names.contains("U"))
    }

    @Test func indexesImport() {
        let source = "import Foundation"
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let importOcc = doc.occurrences.first { $0.symbolRoles == SymbolRole.import }
        #expect(importOcc != nil)
        #expect(importOcc?.symbol.contains("Foundation") == true)
    }

    @Test func indexesLocalVariables() {
        let source = """
        func test() {
            let x = 1
            var y = 2
        }
        """
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let locals = doc.symbols.filter { $0.kind == SymbolKind.variable && $0.symbol.hasPrefix("local") }
        #expect(locals.count == 2)
    }

    @Test func indexesClosureParameters() {
        let source = """
        let f = { (x: Int, y: Int) -> Int in
            return x + y
        }
        """
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let params = doc.symbols.filter { $0.kind == SymbolKind.parameter }
        let names = params.map(\.displayName)
        #expect(names.contains("x"))
        #expect(names.contains("y"))
    }

    @Test func indexesDocComments() {
        let source = """
        /// A greeting function.
        func greet() { }
        """
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let funcSym = doc.symbols.first { $0.displayName == "greet" }
        #expect(funcSym != nil)
        #expect(funcSym?.documentation.first == "A greeting function.")
    }

    @Test func indexesNestedTypes() {
        let source = """
        struct Outer {
            struct Inner {
                var prop: Int
            }
        }
        """
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let innerSym = doc.symbols.first { $0.displayName == "Inner" }
        #expect(innerSym != nil)
        #expect(innerSym?.symbol.contains("Outer#Inner#") == true)
        #expect(innerSym?.enclosingSymbol.contains("Outer#") == true)
    }

    @Test func indexesEnumAssociatedValues() {
        let source = """
        enum Result {
            case success(value: Int)
            case failure(error: String)
        }
        """
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let params = doc.symbols.filter { $0.kind == SymbolKind.parameter }
        let names = params.map(\.displayName)
        #expect(names.contains("value"))
        #expect(names.contains("error"))
    }

    @Test func indexesOperatorDeclaration() {
        let source = "infix operator <>"
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let opSym = doc.symbols.first { $0.displayName == "<>" }
        #expect(opSym != nil)
        #expect(opSym?.kind == SymbolKind.function)
    }

    @Test func indexesPrecedenceGroup() {
        let source = """
        precedencegroup MyPrecedence {
            higherThan: AdditionPrecedence
        }
        """
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let pgSym = doc.symbols.first { $0.displayName == "MyPrecedence" }
        #expect(pgSym != nil)
        #expect(pgSym?.kind == SymbolKind.type)
    }

    @Test func indexesStaticMethod() {
        let source = """
        struct Foo {
            static func bar() { }
        }
        """
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let methodSym = doc.symbols.first { $0.displayName == "static bar" }
        #expect(methodSym != nil)
        #expect(methodSym?.kind == SymbolKind.method)
        #expect(methodSym?.symbol.contains("static.bar") == true)
    }

    @Test func indexesStaticProperty() {
        let source = """
        struct Foo {
            static var shared: Int = 0
        }
        """
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let propSym = doc.symbols.first { $0.displayName == "static shared" }
        #expect(propSym != nil)
        #expect(propSym?.kind == SymbolKind.property)
        #expect(propSym?.symbol.contains("static.shared") == true)
    }

    @Test func indexesPatternBinding() {
        let source = """
        func test() {
            if let x = Optional.some(1) {
                print(x)
            }
        }
        """
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let locals = doc.symbols.filter { $0.kind == SymbolKind.variable && $0.displayName == "x" }
        #expect(!locals.isEmpty)
    }

    @Test func indexesForInLoop() {
        let source = """
        func test() {
            for item in [1, 2, 3] {
                print(item)
            }
        }
        """
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let itemSym = doc.symbols.first { $0.displayName == "item" }
        #expect(itemSym != nil)
        #expect(itemSym?.kind == SymbolKind.variable)
    }

    @Test func indexesInheritanceAsReference() {
        let source = """
        protocol P { }
        class Foo: P { }
        """
        let doc = analyzeFile(source: source, packageName: "Test", relativePath: "test.swift")

        let refs = doc.occurrences.filter { $0.symbolRoles == SymbolRole.readAccess }
        let refSymbols = refs.map(\.symbol)
        #expect(refSymbols.contains { $0.contains("P#") })
    }
}

// MARK: - Workspace Tests

@Suite("Workspace")
struct WorkspaceTests {
    @Test func discoversPackageName() {
        // Use the cog-swift project itself as a test fixture
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CogSwiftTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // cog-swift
            .path
        let name = Workspace.discoverPackageName(root: root)
        #expect(name == "cog-swift")
    }

    @Test func fallsBackToDirectoryName() {
        let name = Workspace.discoverPackageName(root: "/tmp")
        #expect(name == "tmp")
    }
}
