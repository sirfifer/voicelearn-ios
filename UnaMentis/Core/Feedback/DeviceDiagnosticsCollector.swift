// UnaMentis - Device Diagnostics Collector
// Collects opt-in device diagnostic information
//
// Privacy-first: Only collected when user explicitly consents
// Follows GDPR/CCPA requirements for transparent data collection

import Foundation
import UIKit
import Network

/// Collects device diagnostic information (requires user consent)
/// Thread-safe actor following Swift 6 concurrency model
public actor DeviceDiagnosticsCollector {

    /// Collect current device diagnostics
    /// - Returns: Device diagnostics snapshot
    public func collect() async -> DeviceDiagnostics {
        // Memory usage (resident size in MB)
        let memoryMB = await collectMemoryUsage()

        // Battery level (0.0 to 1.0)
        let batteryLevel = await collectBatteryLevel()

        // Network type
        let networkType = await determineNetworkType()

        // Low power mode
        let lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

        return DeviceDiagnostics(
            memoryUsageMB: memoryMB,
            batteryLevel: batteryLevel,
            networkType: networkType,
            lowPowerMode: lowPowerMode
        )
    }

    /// Collect current memory usage in MB
    private func collectMemoryUsage() async -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if kerr == KERN_SUCCESS {
            return Int(info.resident_size / 1024 / 1024) // Convert to MB
        } else {
            return 0
        }
    }

    /// Collect battery level (0.0 to 1.0)
    private func collectBatteryLevel() async -> Float {
        await UIDevice.current.isBatteryMonitoringEnabled = true
        let level = await UIDevice.current.batteryLevel

        // batteryLevel returns -1.0 if monitoring is not enabled or not available
        return level >= 0 ? level : 0.0
    }

    /// Determine network type (wifi, cellular, or none)
    private func determineNetworkType() async -> String {
        // For v1, use a simple approach
        // Future enhancement: Use NWPathMonitor for more detailed info
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")

        return await withCheckedContinuation { continuation in
            monitor.pathUpdateHandler = { path in
                let networkType: String
                if path.usesInterfaceType(.wifi) {
                    networkType = "wifi"
                } else if path.usesInterfaceType(.cellular) {
                    networkType = "cellular"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    networkType = "ethernet"
                } else if path.status == .satisfied {
                    networkType = "other"
                } else {
                    networkType = "none"
                }
                monitor.cancel()
                continuation.resume(returning: networkType)
            }
            monitor.start(queue: queue)
        }
    }
}
