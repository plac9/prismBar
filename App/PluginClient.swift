// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import prismPluginKit
import Synchronization

enum PluginClientError: Error, Equatable {
    case busy
    case cancelled
    case connectionInterrupted
    case disabledForSession
    case invalidConnection
    case invalidReply
    case invalidResponse
    case serviceInvalidRequest
    case serviceInvalidResponse
    case serviceRejectedRequest
    case rejected
    case timedOut
    case trustRejected
    case unavailable
}

@MainActor
final class PrismCalcPluginClient {
    private static let failureLimit = 3
    private static let requestTimeout = Duration.seconds(2)
    private static let panelRecoveryDelays: [Duration] = [
        .milliseconds(400),
        .seconds(3),
    ]

    private let codec = PluginWireCodec()
    private let policy: BundledPluginPolicy
    private var authenticated = false
    private var connection: NSXPCConnection?
    private var consecutiveFailures = 0
    private var isRequestInFlight = false

    init() throws {
        policy = try BundledPluginPolicy(
            pluginIdentifier: "com.laclairtech.prismbar.plugin.prismcalc",
            teamIdentifier: "N8A5T2PZY9",
            expectedPluginVersion: .init(major: 0, minor: 1, patch: 0),
            allowedCapabilities: [.panel, .commands, .openApplication],
            allowedApplicationIdentifiers: ["com.laclairtech.prismcalc"]
        )
    }

    func loadPanel() async throws -> PluginPanelUpdate {
        for delay in Self.panelRecoveryDelays {
            do {
                return try await performPanelRequest(.panel)
            } catch let error as PluginClientError where error.isTransientTransportFailure {
                try await Task.sleep(for: delay)
            }
        }
        return try await performPanelRequest(.panel)
    }

    func invoke(_ commandIdentifier: String) async throws -> PluginPanelUpdate {
        try await performPanelRequest(.invoke(.init(commandIdentifier: commandIdentifier)))
    }

    func retryAfterFailure() {
        consecutiveFailures = 0
        invalidateConnection()
    }

    private func performPanelRequest(_ request: PluginRequest) async throws -> PluginPanelUpdate {
        do {
            try await authenticateIfNeeded()
            let response = try await send(request)
            let update = try policy.validatePanelResponse(response)
            consecutiveFailures = 0
            return update
        } catch {
            let clientError = sanitized(error)
            if clientError.countsTowardFailureLimit {
                registerFailure()
            }
            throw clientError
        }
    }

    private func authenticateIfNeeded() async throws {
        guard !authenticated else { return }

        let response = try await send(.handshake(.init(
            hostProtocol: .current,
            requestedCapabilities: Array(policy.allowedCapabilities).sorted {
                $0.rawValue < $1.rawValue
            }
        )))
        guard case let .manifest(manifest) = response else {
            throw PluginClientError.invalidResponse
        }
        _ = try policy.validateManifest(manifest)
        authenticated = true
    }

    private func send(_ request: PluginRequest) async throws -> PluginResponse {
        guard consecutiveFailures < Self.failureLimit else {
            throw PluginClientError.disabledForSession
        }
        guard !isRequestInFlight else {
            throw PluginClientError.busy
        }

        isRequestInFlight = true
        defer { isRequestInFlight = false }

        let requestData = try codec.encode(request)
        let responseData = try await send(requestData)
        return try codec.decode(PluginResponse.self, from: responseData)
    }

    private func send(_ requestData: Data) async throws -> Data {
        let gate = PluginRequestGate()
        let connection = activeConnection()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                gate.install(continuation)
                PluginRequestBridge.start(
                    requestData: requestData,
                    connection: connection,
                    gate: gate
                )

                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: Self.requestTimeout)
                    if gate.resolve(.failure(.timedOut)) {
                        self?.invalidateConnection()
                    }
                }
            }
        } onCancel: {
            gate.resolve(.failure(.cancelled))
        }
    }

    private func activeConnection() -> NSXPCConnection {
        if let connection {
            return connection
        }

        let connection = NSXPCConnection(serviceName: policy.pluginIdentifier)
        connection.setCodeSigningRequirement(policy.codeSigningRequirement)
        connection.remoteObjectInterface = NSXPCInterface(with: PluginXPCServiceProtocol.self)
        connection.interruptionHandler = { [weak self, weak connection] in
            Task { @MainActor in
                guard let self, self.connection === connection else { return }
                self.invalidateConnection()
            }
        }
        connection.invalidationHandler = { [weak self, weak connection] in
            Task { @MainActor in
                guard let self, self.connection === connection else { return }
                self.connection = nil
                self.authenticated = false
            }
        }
        connection.activate()
        self.connection = connection
        return connection
    }

    private func registerFailure() {
        consecutiveFailures = min(Self.failureLimit, consecutiveFailures + 1)
        invalidateConnection()
    }

    private func invalidateConnection() {
        let oldConnection = connection
        connection = nil
        authenticated = false
        oldConnection?.invalidate()
    }

    private func sanitized(_ error: any Error) -> PluginClientError {
        if let error = error as? PluginClientError {
            return error
        }
        return .invalidResponse
    }

}

private nonisolated enum PluginRequestBridge {
    static func start(
        requestData: Data,
        connection: NSXPCConnection,
        gate: PluginRequestGate
    ) {
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            let failure = PluginTransportFailure.classify(error)
            gate.resolve(.failure(clientError(for: failure)))
        }
        guard let service = proxy as? PluginXPCServiceProtocol else {
            gate.resolve(.failure(.unavailable))
            return
        }

        service.process(requestData) { data, serviceError in
            guard let data else {
                gate.resolve(.failure(clientError(for: serviceError)))
                return
            }
            gate.resolve(.success(data))
        }
    }

    private static func clientError(
        for failure: PluginTransportFailure
    ) -> PluginClientError {
        switch failure {
        case .codeSigningRequirement:
            .trustRejected
        case .interrupted:
            .connectionInterrupted
        case .invalidConnection:
            .invalidConnection
        case .invalidReply:
            .invalidReply
        case .unknown:
            .unavailable
        }
    }

    private static func clientError(for error: NSError?) -> PluginClientError {
        guard let error,
              let failure = PluginServiceFailure.classify(error)
        else {
            return .rejected
        }

        switch failure {
        case .invalidRequest:
            return .serviceInvalidRequest
        case .requestRejected:
            return .serviceRejectedRequest
        case .invalidResponse:
            return .serviceInvalidResponse
        }
    }
}

private extension PluginClientError {
    var isTransientTransportFailure: Bool {
        switch self {
        case .connectionInterrupted, .invalidConnection, .invalidReply,
             .timedOut, .unavailable:
            true
        case .busy, .cancelled, .disabledForSession, .invalidResponse,
             .rejected, .serviceInvalidRequest, .serviceInvalidResponse,
             .serviceRejectedRequest, .trustRejected:
            false
        }
    }

    var countsTowardFailureLimit: Bool {
        switch self {
        case .connectionInterrupted, .invalidConnection, .invalidReply,
             .invalidResponse, .rejected, .serviceInvalidRequest,
             .serviceInvalidResponse, .serviceRejectedRequest, .timedOut,
             .trustRejected, .unavailable:
            true
        case .busy, .cancelled, .disabledForSession:
            false
        }
    }
}

private nonisolated final class PluginRequestGate: Sendable {
    private struct State {
        var continuation: CheckedContinuation<Data, any Error>?
        var pendingResult: Result<Data, PluginClientError>?
        var isResolved = false
    }

    private let state = Mutex(State())

    func install(_ continuation: CheckedContinuation<Data, any Error>) {
        let pending: Result<Data, PluginClientError>? = state.withLock { state in
            if let pendingResult = state.pendingResult {
                state.pendingResult = nil
                return pendingResult
            }
            state.continuation = continuation
            return nil
        }
        if let pending {
            continuation.resume(with: pending.mapError { $0 as any Error })
        }
    }

    @discardableResult
    func resolve(_ result: Result<Data, PluginClientError>) -> Bool {
        let resolution: (continuation: CheckedContinuation<Data, any Error>?, won: Bool) = state.withLock { state in
            guard !state.isResolved else { return (nil, false) }
            state.isResolved = true
            guard let continuation = state.continuation else {
                state.pendingResult = result
                return (nil, true)
            }
            state.continuation = nil
            return (continuation, true)
        }
        resolution.continuation?.resume(with: result.mapError { $0 as any Error })
        return resolution.won
    }
}
