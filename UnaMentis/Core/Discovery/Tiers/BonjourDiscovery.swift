// UnaMentis - Bonjour Discovery
// Tier 2: mDNS/Bonjour service discovery using Network framework
//
// Part of Core/Discovery

import Foundation
import Network
import Logging

/// Thread-safe state holder for continuation resumption
private final class ResumeState: @unchecked Sendable {
    private let lock = NSLock()
    private var _hasResumed = false

    var hasResumed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _hasResumed
    }

    func tryResume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _hasResumed {
            return false
        }
        _hasResumed = true
        return true
    }
}

/// Tier 2: Discovers servers via Bonjour/mDNS (zero-config networking)
public actor BonjourDiscovery: DiscoveryTierProtocol {
    public let tier: DiscoveryTier = .bonjour

    private let serviceType: String
    private let logger = Logger(label: "com.unamentis.discovery.bonjour")
    private var browser: NWBrowser?
    private var isCancelled = false

    /// Initialize with the Bonjour service type to browse for
    /// - Parameter serviceType: The service type (e.g., "_unamentis._tcp")
    public init(serviceType: String = "_unamentis._tcp") {
        self.serviceType = serviceType
    }

    public func discover(timeout: TimeInterval) async throws -> DiscoveredServer? {
        isCancelled = false

        return try await withCheckedThrowingContinuation { continuation in
            let parameters = NWParameters()
            parameters.includePeerToPeer = false

            let browser = NWBrowser(
                for: .bonjourWithTXTRecord(type: serviceType, domain: nil),
                using: parameters
            )

            let state = ResumeState()

            let safeResume: @Sendable (Result<DiscoveredServer?, Error>) -> Void = { result in
                if state.tryResume() {
                    browser.cancel()
                    continuation.resume(with: result)
                }
            }

            browser.browseResultsChangedHandler = { [weak self] results, _ in
                guard let self = self else { return }

                for result in results {
                    if case .service(let name, let type, let domain, let interface) = result.endpoint {
                        Task { [weak self] in
                            guard let self = self else { return }
                            await self.logFoundService(name: name, type: type)

                            if let server = await self.resolveService(
                                name: name,
                                type: type,
                                domain: domain,
                                interface: interface
                            ) {
                                safeResume(.success(server))
                            }
                        }
                    }
                }
            }

            browser.stateUpdateHandler = { [weak self] newState in
                switch newState {
                case .failed(let error):
                    Task { [weak self] in
                        await self?.logBrowserFailed(error: error)
                    }
                    safeResume(.failure(error))
                case .cancelled:
                    Task { [weak self] in
                        await self?.logBrowserCancelled()
                    }
                case .ready:
                    Task { [weak self] in
                        await self?.logBrowserReady()
                    }
                default:
                    break
                }
            }

            browser.start(queue: .main)
            Task { [weak self] in
                await self?.storeBrowser(browser)
            }

            // Timeout task
            Task { [weak self] in
                try await Task.sleep(for: .seconds(timeout))
                let shouldTimeout = await self?.checkTimeout(state: state) ?? false

                if shouldTimeout {
                    await self?.logTimeout()
                    safeResume(.success(nil))
                }
            }
        }
    }

    // MARK: - Helper Methods for Actor Isolation

    private func storeBrowser(_ browser: NWBrowser) {
        self.browser = browser
    }

    private func checkTimeout(state: ResumeState) -> Bool {
        !state.hasResumed && !self.isCancelled
    }

    private func logFoundService(name: String, type: String) {
        logger.info("Found Bonjour service: \(name) (\(type))")
    }

    private func logBrowserFailed(error: NWError) {
        logger.error("Bonjour browser failed: \(error)")
    }

    private func logBrowserCancelled() {
        logger.debug("Bonjour browser cancelled")
    }

    private func logBrowserReady() {
        logger.debug("Bonjour browser ready")
    }

    private func logTimeout() {
        logger.debug("Bonjour discovery timed out")
    }

    private func logResolved(name: String, host: String, port: Int) {
        logger.info("Resolved \(name) to \(host):\(port)")
    }

    private func logResolveFailed(name: String, error: NWError) {
        logger.debug("Failed to resolve \(name): \(error)")
    }

    public func cancel() async {
        isCancelled = true
        browser?.cancel()
        browser = nil
    }

    // MARK: - Service Resolution

    private func resolveService(
        name: String,
        type: String,
        domain: String,
        interface: NWInterface?
    ) async -> DiscoveredServer? {
        return await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.service(
                name: name,
                type: type,
                domain: domain,
                interface: interface
            )

            let connection = NWConnection(to: endpoint, using: .tcp)
            let state = ResumeState()

            let safeResume: @Sendable (DiscoveredServer?) -> Void = { server in
                if state.tryResume() {
                    connection.cancel()
                    continuation.resume(returning: server)
                }
            }

            connection.stateUpdateHandler = { [weak self] connState in
                switch connState {
                case .ready:
                    // Extract the resolved address
                    if let path = connection.currentPath,
                       let remoteEndpoint = path.remoteEndpoint,
                       case .hostPort(let host, let port) = remoteEndpoint {
                        let hostString = Self.extractHostString(from: host) ?? name
                        let portInt = Int(port.rawValue)

                        Task { [weak self] in
                            await self?.logResolved(name: name, host: hostString, port: portInt)
                        }

                        let server = DiscoveredServer(
                            name: name,
                            host: hostString,
                            port: portInt,
                            discoveryMethod: .bonjour
                        )
                        safeResume(server)
                    } else {
                        safeResume(nil)
                    }

                case .failed(let error):
                    Task { [weak self] in
                        await self?.logResolveFailed(name: name, error: error)
                    }
                    safeResume(nil)

                case .cancelled:
                    break

                default:
                    break
                }
            }

            connection.start(queue: .main)

            // Resolution timeout
            Task {
                try await Task.sleep(for: .seconds(2))
                safeResume(nil)
            }
        }
    }

    private nonisolated static func extractHostString(from host: NWEndpoint.Host) -> String? {
        switch host {
        case .ipv4(let address):
            return address.debugDescription
        case .ipv6(let address):
            return address.debugDescription
        case .name(let hostname, _):
            return hostname
        @unknown default:
            return nil
        }
    }
}
