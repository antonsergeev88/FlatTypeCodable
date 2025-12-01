# FlatTypeCodable

FlatTypeCodable is a tiny Swift macro that generates `Codable` conformance for enums representing flat polymorphic JSON objects - the common API pattern where a discriminator field like `type` lives alongside the payload fields.

Instead of writing boilerplate decoding/encoding code yourself, you declare an enum with one associated value per case and annotate it with `@FlatTypeCodable`. The macro generates all the `Codable` machinery for you.

## What problem does it solve?

Many APIs return heterogeneous lists of items in this shape:

```json
[
  {
    "type": "text",
    "text": "Hello world"
  },
  {
    "type": "media",
    "url": "https://example.com/image.png"
  }
]
```

Each object has:

- a discriminator field (for example, `type`) telling you which variant it is
- the actual fields for that variant at the same level (no nesting)

Modeling this manually usually means:

- writing a hand-rolled `init(from:)` with a `switch` on the discriminator
- decoding into different structs depending on the selected case
- mirroring the logic again in `encode(to:)`

FlatTypeCodable removes that boilerplate by generating the `Codable` implementation for you.

## Adding the package

FlatTypeCodable is distributed as a Swift Package.

- **Minimum tools**: Swift 6.1 / Xcode 16 (macro-based package, `swift-tools-version: 6.1`)
- **Supported platforms**: macOS 10.15+, iOS 13+, tvOS 13+, watchOS 6+, macCatalyst 13+

### Swift Package Manager (Package.swift)

Add the package dependency:

```swift
dependencies: [
    .package(url: "https://github.com/antonsergeev88/FlatTypeCodable.git", from: "1.0.0")
],
```

Then add `FlatTypeCodable` to your target dependencies:

```swift
targets: [
    .target(name: "YourApp", dependencies: ["FlatTypeCodable"])
]
```

### Xcode (SPM UI)

1. In Xcode, open **File → Add Packages…**
2. Enter the URL: `https://github.com/antonsergeev88/FlatTypeCodable.git`
3. Set the version rule to **Up to Next Major** starting from **1.0.0**
4. Add the `FlatTypeCodable` library to the targets that need it

## Using `@FlatTypeCodable`

You declare an enum with one associated value per case; each associated type is responsible for its own `Codable` conformance.

```swift
import FlatTypeCodable

@FlatTypeCodable
enum Message {
    case text(TextMessage)
    case media(MediaMessage)
}

struct TextMessage: Codable {
    let text: String
}

struct MediaMessage: Codable {
    let url: URL
}
```

Now you can decode a heterogeneous list of messages directly:

```swift
let data = """
[
    { "type": "text",  "text": "Hello world" },
    { "type": "media", "url": "https://example.com/image.png" }
]
""".data(using: .utf8)!

let decoder = JSONDecoder()
let messages = try decoder.decode([Message].self, from: data)

// messages[0] == .text(TextMessage(text: "Hello world"))
// messages[1] == .media(MediaMessage(url: URL(string: "https://example.com/image.png")!))
```

### Requirements for the enum

The macro enforces a few simple rules:

- It can be applied **only to enums**
- Each case must have **exactly one associated value**
- The associated value’s type must be `Codable`

If these rules are violated, the macro emits a diagnostic error at compile time.

## How it works

The `@FlatTypeCodable` macro expands your enum into:

- an internal `CodingKeys` enum with a single `type` key
- an internal `Kind` enum used as the discriminator, with one case per enum case
- an `init(from:)` that:
  - reads the `type` field as a `Kind`
  - switches on that value
  - decodes the associated payload type from the same decoder
- an `encode(to:)` that:
  - writes the appropriate `Kind` to the `type` field
  - delegates encoding of the payload back to the associated value
- an extension that makes the enum conform to `Codable`

For the `Message` example above, the expansion is conceptually equivalent to:

```swift
enum Message {
    case text(TextMessage)
    case media(MediaMessage)

    private enum CodingKeys: String, CodingKey { case type }

    private enum Kind: String, Codable {
        case text, media
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .text:
            self = .text(try TextMessage(from: decoder))
        case .media:
            self = .media(try MediaMessage(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let m):
            try c.encode(Kind.text, forKey: .type)
            try m.encode(to: encoder)
        case .media(let m):
            try c.encode(Kind.media, forKey: .type)
            try m.encode(to: encoder)
        }
    }
}

extension Message: Codable {}
```

This pattern generalizes to any enum that follows the same rules. You design the payload types as normal `Codable` structs; the macro wires them together into a flat, type‑tagged representation that matches typical API responses.

