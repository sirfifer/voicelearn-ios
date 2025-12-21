// UnaMentis - AnalyticsViewModelTests
// Unit tests for AnalyticsViewModel
//
// Tests cover:
// - Data refreshing from TelemetryEngine
// - Export generation

import XCTest
import Combine
@testable import UnaMentis

@MainActor
final class AnalyticsViewModelTests: XCTestCase {
    
    var viewModel: AnalyticsViewModel!
    var telemetry: TelemetryEngine!
    
    override func setUp() async throws {
        try await super.setUp()
        viewModel = AnalyticsViewModel()
        telemetry = TelemetryEngine()
    }
    
    override func tearDown() {
        viewModel = nil
        telemetry = nil
        super.tearDown()
    }
    
    func testRefresh_updatesMetrics() async {
        // Given initialized telemetry with data
        await telemetry.startSession()
        await telemetry.recordEvent(.userFinishedSpeaking(transcript: "Test"))
        
        // When refreshing view model
        await viewModel.refresh(telemetry: telemetry)
        
        // Then metrics should be updated
        XCTAssertEqual(viewModel.currentMetrics.turnsTotal, 1)
    }
    
    func testGenerateExport_createsURL() async {
        // Given telemetry data
        await telemetry.recordEvent(.sessionStarted)
        
        // When generating export
        await viewModel.generateExport(telemetry: telemetry)
        
        // Then exportURL should be set and file should exist
        XCTAssertNotNil(viewModel.exportURL)
        if let url = viewModel.exportURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            
            // Clean up
            try? FileManager.default.removeItem(at: url)
        }
    }
}
