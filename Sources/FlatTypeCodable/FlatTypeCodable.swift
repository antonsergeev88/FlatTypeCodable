@attached(extension, conformances: Codable)
@attached(member, names: named(init(from:)), named(encode(to:)), named(CodingKeys), named(Kind))
public macro FlatTypeCodable() = #externalMacro(
    module: "FlatTypeCodableMacros",
    type: "FlatTypeCodableMacro"
)
