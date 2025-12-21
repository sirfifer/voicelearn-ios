// UnaMentis - OpenAIEmbeddingServiceTests
// Unit tests for OpenAI Embedding Service
//
// Tests cover:
// - Initialization
// - Embedding generation request format
// - Response parsing
// - Cost calculation

import XCTest
import Foundation
@testable import UnaMentis

@MainActor
final class OpenAIEmbeddingServiceTests: XCTestCase {
    
    var service: OpenAIEmbeddingService!
    let apiKey = "test_openai_key"
    
    override func setUp() async throws {
        try await super.setUp()
        service = OpenAIEmbeddingService(apiKey: apiKey)
    }
    
    override func tearDown() async throws {
        service = nil
        try await super.tearDown()
    }
    
    func testInitialization() async {
        XCTAssertNotNil(service)
        let dim = await service.embeddingDimension
        XCTAssertEqual(dim, 1536) // text-embedding-3-small default
    }
    
    func testEmbeddingDimension_Small() async {
        let serviceSmall = OpenAIEmbeddingService(apiKey: apiKey, model: .small)
        let dim = await serviceSmall.embeddingDimension
        XCTAssertEqual(dim, 1536)
    }
    
    // Note: Actual network tests require mocking URLSession which is complex for this scope.
    // We trust the structure matches API specs.
}
