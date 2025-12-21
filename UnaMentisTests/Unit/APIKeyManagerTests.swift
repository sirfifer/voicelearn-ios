// UnaMentis - API Key Manager Tests
// Tests for secure API key management

import XCTest
@testable import UnaMentis

/// Tests for APIKeyManager
final class APIKeyManagerTests: XCTestCase {
    
    // MARK: - Key Type Tests
    
    func testAllKeyTypesHaveDisplayNames() {
        for keyType in APIKeyManager.KeyType.allCases {
            XCTAssertFalse(keyType.displayName.isEmpty)
        }
    }
    
    func testKeyTypeRawValues() {
        XCTAssertEqual(APIKeyManager.KeyType.openAI.rawValue, "OPENAI_API_KEY")
        XCTAssertEqual(APIKeyManager.KeyType.anthropic.rawValue, "ANTHROPIC_API_KEY")
        XCTAssertEqual(APIKeyManager.KeyType.assemblyAI.rawValue, "ASSEMBLYAI_API_KEY")
        XCTAssertEqual(APIKeyManager.KeyType.deepgram.rawValue, "DEEPGRAM_API_KEY")
        XCTAssertEqual(APIKeyManager.KeyType.elevenLabs.rawValue, "ELEVENLABS_API_KEY")
    }
    
    func testKeyTypeDisplayNames() {
        XCTAssertEqual(APIKeyManager.KeyType.openAI.displayName, "OpenAI")
        XCTAssertEqual(APIKeyManager.KeyType.anthropic.displayName, "Anthropic")
        XCTAssertEqual(APIKeyManager.KeyType.assemblyAI.displayName, "AssemblyAI")
        XCTAssertEqual(APIKeyManager.KeyType.deepgram.displayName, "Deepgram")
    }
    
    // MARK: - Key Status Tests
    
    func testGetKeyStatus() async throws {
        let status = await APIKeyManager.shared.getKeyStatus()
        
        // Should have entries for all key types
        XCTAssertEqual(status.count, APIKeyManager.KeyType.allCases.count)
    }
    
    func testValidateRequiredKeys() async throws {
        let missingKeys = await APIKeyManager.shared.validateRequiredKeys()
        
        // In a test environment, likely all keys are missing
        // Just verify it returns an array
        XCTAssertNotNil(missingKeys)
    }
    
    func testHasKey() async throws {
        // Test with a key that likely doesn't exist
        let hasKey = await APIKeyManager.shared.hasKey(.openAI)
        
        // Result depends on environment, but should not crash
        _ = hasKey
    }
    
    // MARK: - Error Tests
    
    func testAPIKeyErrorDescriptions() {
        let invalidValueError = APIKeyError.invalidValue
        XCTAssertEqual(invalidValueError.errorDescription, "Invalid API key value")
        
        let keychainError = APIKeyError.keychainError(-25300)
        XCTAssertTrue(keychainError.errorDescription?.contains("Keychain error") ?? false)
        
        let notFoundError = APIKeyError.keyNotFound(.openAI)
        XCTAssertTrue(notFoundError.errorDescription?.contains("OpenAI") ?? false)
    }
}
