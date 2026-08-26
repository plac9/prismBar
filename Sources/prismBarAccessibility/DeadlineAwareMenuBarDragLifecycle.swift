// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore

enum MenuBarDragStage: Equatable, Sendable {
    case position
    case press
    case midpoint
    case endpoint
    case release
    case restore
}

protocol MenuBarDragPausing: Sendable {
    func pause(for duration: Duration, deadline: OperationDeadline) async throws
}

struct SystemMenuBarDragPauser: MenuBarDragPausing {
    func pause(for duration: Duration, deadline: OperationDeadline) async throws {
        try Task.checkCancellation()
        try deadline.check()
        guard deadline.remaining() >= duration else {
            throw OperationDeadlineError.expired
        }
        try await Task.sleep(for: duration)
        try Task.checkCancellation()
        try deadline.check()
    }
}

struct DeadlineAwareMenuBarDragLifecycle<Pauser: MenuBarDragPausing>: Sendable {
    private let pauser: Pauser

    init(pauser: Pauser) {
        self.pauser = pauser
    }

    func perform(
        deadline: OperationDeadline,
        post: @Sendable (MenuBarDragStage) -> Void
    ) async throws {
        var didStart = false
        var didPress = false
        defer {
            if didPress {
                post(.release)
            }
            if didStart {
                post(.restore)
            }
        }

        try check(deadline)
        post(.position)
        didStart = true
        try await pauser.pause(for: .milliseconds(25), deadline: deadline)

        try check(deadline)
        post(.press)
        didPress = true
        try await pauser.pause(for: .milliseconds(40), deadline: deadline)

        try check(deadline)
        post(.midpoint)
        try await pauser.pause(for: .milliseconds(40), deadline: deadline)

        try check(deadline)
        post(.endpoint)
        try await pauser.pause(for: .milliseconds(40), deadline: deadline)
    }

    private func check(_ deadline: OperationDeadline) throws {
        try Task.checkCancellation()
        try deadline.check()
    }
}
