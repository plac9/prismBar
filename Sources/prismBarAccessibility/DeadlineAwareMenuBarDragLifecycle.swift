// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore

enum MenuBarDragStage: Equatable, Sendable {
    case position
    case modifierDown
    case press
    case dragStep(Int)
    case release
    case modifierUp
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
        dragStepCount: Int,
        deadline: OperationDeadline,
        post: @Sendable (MenuBarDragStage) -> Void
    ) async throws {
        var didStart = false
        var didHoldModifier = false
        var didPress = false
        defer {
            if didPress {
                post(.release)
            }
            if didHoldModifier {
                post(.modifierUp)
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
        post(.modifierDown)
        didHoldModifier = true
        post(.press)
        didPress = true
        try await pauser.pause(for: .milliseconds(40), deadline: deadline)

        for index in 0..<dragStepCount {
            try check(deadline)
            post(.dragStep(index))
            let isEndpoint = index == dragStepCount - 1
            let pause: Duration = isEndpoint ? .milliseconds(240) : .milliseconds(16)
            try await pauser.pause(for: pause, deadline: deadline)
        }
    }

    private func check(_ deadline: OperationDeadline) throws {
        try Task.checkCancellation()
        try deadline.check()
    }
}
