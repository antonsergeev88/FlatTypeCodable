import XCTest
@testable import FlatTypeCodable
import Foundation

let data = """
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
"""
    .data(using: .utf8)!

@FlatTypeCodable
enum Message: Equatable {
    case text(TextMessage)
    case media(MediaMessage)
}

struct TextMessage: Codable, Equatable {
    let text: String
}

struct MediaMessage: Codable, Equatable {
    let url: URL
}


final class FlatTypeCodableTests: XCTestCase {
    func testExpansion() throws {
        let decoder = JSONDecoder()
        let messages = try decoder.decode([Message].self, from: data)
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0], .text(TextMessage(text: "Hello world")))
        XCTAssertEqual(messages[1], .media(MediaMessage(url: URL(string: "https://example.com/image.png")!)))
    }
}
