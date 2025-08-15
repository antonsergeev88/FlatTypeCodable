import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct FlatTypeCodablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        FlatTypeCodableMacro.self
    ]
}
