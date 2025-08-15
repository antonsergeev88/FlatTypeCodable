import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftDiagnostics
import SwiftSyntaxMacros

private struct FlatTypeCodableError: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity

    init(_ message: String, id: String = "invalid", severity: DiagnosticSeverity = .error) {
        self.message = message
        self.diagnosticID = MessageID(domain: "FlatTypeCodable", id: id)
        self.severity = severity
    }
}

public struct FlatTypeCodableMacro: ExtensionMacro, MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let ext: ExtensionDeclSyntax = try ExtensionDeclSyntax("extension \(type): Codable {}")
        return [ext]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: Syntax(declaration), message: FlatTypeCodableError("@FlatTypeCodable can only be applied to enums")))
            return []
        }

        // Collect enum cases and verify each has exactly one associated value
        var cases: [(name: String, type: String)] = []

        for member in enumDecl.memberBlock.members {
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
            for elem in caseDecl.elements {
                let caseName = elem.name.text

                guard let assoc = elem.parameterClause else {
                    context.diagnose(Diagnostic(node: Syntax(elem), message: FlatTypeCodableError("Each case must have exactly one associated value.")))
                    return []
                }

                let params = assoc.parameters
                guard params.count == 1, let ty = params.first?.type else {
                    context.diagnose(Diagnostic(node: Syntax(elem), message: FlatTypeCodableError("Each case must have exactly one associated value (no more, no less).")))
                    return []
                }

                cases.append((name: caseName, type: ty.description.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }

        if cases.isEmpty {
            // Nothing to synthesize
            return []
        }

        // private enum CodingKeys: String, CodingKey { case type }
        let codingKeysDecl: DeclSyntax = """
        private enum CodingKeys: String, CodingKey { case type }
        """

        // private enum Kind: String, Codable { case ... }
        let kindCases = cases.map { $0.name }.joined(separator: ", ")
        let kindDecl: DeclSyntax = """
        private enum Kind: String, Codable { case \(raw: kindCases) }
        """

        // init(from:)
        let switchDecode = cases.map { c in
            """
            case .\(c.name):
                self = .\(c.name)(try \(c.type)(from: decoder))
            """
        }.joined(separator: "\n")

        let initDecl: DeclSyntax = """
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            switch try c.decode(Kind.self, forKey: .type) {
            \(raw: switchDecode)
            }
        }
        """

        // encode(to:)
        let switchEncode = cases.map { c in
            """
            case .\(c.name)(let m):
                try c.encode(Kind.\(c.name), forKey: .type)
                try m.encode(to: encoder)
            """
        }.joined(separator: "\n")

        let encodeDecl: DeclSyntax = """
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            \(raw: switchEncode)
            }
        }
        """

        return [codingKeysDecl, kindDecl, initDecl, encodeDecl]
    }
}
