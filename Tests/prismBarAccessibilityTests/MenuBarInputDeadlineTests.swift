// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import prismBarAccessibility
import prismBarCore
import Testing

@Suite("Menu bar input deadline")
struct MenuBarInputDeadlineTests {
    @Test("posts one complete drag sequence")
    func postsCompleteSequence() async throws {
        let recorder = DragStageRecorder()
        let lifecycle = DeadlineAwareMenuBarDragLifecycle(
            pauser: ImmediateDragPauser()
        )

        try await lifecycle.perform(
            dragStepCount: 3,
            deadline: OperationDeadline(timeout: .seconds(1)),
            post: recorder.record
        )

        #expect(
            recorder.stages == [
                .position,
                .modifierDown,
                .press,
                .dragStep(0),
                .dragStep(1),
                .dragStep(2),
                .release,
                .modifierUp,
                .restore,
            ]
        )
    }

    @Test("posts nothing when the deadline is already expired")
    func stopsBeforeStarting() async {
        let now = ContinuousClock().now
        let recorder = DragStageRecorder()
        let lifecycle = DeadlineAwareMenuBarDragLifecycle(
            pauser: ImmediateDragPauser()
        )

        await #expect(throws: OperationDeadlineError.expired) {
            try await lifecycle.perform(
                dragStepCount: 2,
                deadline: OperationDeadline(expiresAt: now),
                post: recorder.record
            )
        }
        #expect(recorder.stages.isEmpty)
    }

    @Test("expiry after press posts only mandatory cleanup")
    func cleansUpAfterExpiry() async {
        let recorder = DragStageRecorder()
        let lifecycle = DeadlineAwareMenuBarDragLifecycle(
            pauser: ExpiringSecondPause()
        )

        await #expect(throws: OperationDeadlineError.expired) {
            try await lifecycle.perform(
                dragStepCount: 2,
                deadline: OperationDeadline(timeout: .milliseconds(5)),
                post: recorder.record
            )
        }
        #expect(
            recorder.stages == [
                .position,
                .modifierDown,
                .press,
                .release,
                .modifierUp,
                .restore,
            ]
        )
    }

    @Test("stage failure during the path still cleans up exactly once")
    func cleansUpAfterStageFailure() async {
        let recorder = DragStageRecorder()
        let lifecycle = DeadlineAwareMenuBarDragLifecycle(
            pauser: FailingThirdPause()
        )

        await #expect(throws: TestInputError.injected) {
            try await lifecycle.perform(
                dragStepCount: 3,
                deadline: OperationDeadline(timeout: .seconds(1)),
                post: recorder.record
            )
        }
        #expect(
            recorder.stages == [
                .position,
                .modifierDown,
                .press,
                .dragStep(0),
                .release,
                .modifierUp,
                .restore,
            ]
        )
    }
}

private enum TestInputError: Error {
    case injected
}

private final class DragStageRecorder: @unchecked Sendable {
    private(set) var stages: [MenuBarDragStage] = []

    func record(_ stage: MenuBarDragStage) {
        stages.append(stage)
    }
}

private struct ImmediateDragPauser: MenuBarDragPausing {
    func pause(for _: Duration, deadline: OperationDeadline) throws {
        try deadline.check()
    }
}

private actor ExpiringSecondPause: MenuBarDragPausing {
    private var count = 0

    func pause(for _: Duration, deadline: OperationDeadline) async throws {
        count += 1
        if count == 2 {
            try await Task.sleep(for: .milliseconds(20))
        }
        try deadline.check()
    }
}

private actor FailingThirdPause: MenuBarDragPausing {
    private var count = 0

    func pause(for _: Duration, deadline: OperationDeadline) throws {
        count += 1
        try deadline.check()
        if count == 3 {
            throw TestInputError.injected
        }
    }
}
