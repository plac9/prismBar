// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
@testable import prismBar

@MainActor
struct SceneActionRouterTests {
    @Test("reuses the visible prismBar workspace")
    func reusesVisibleWorkspace() {
        #expect(
            SceneActionRouter.shouldReuseWorkspace(
                title: "prismBar",
                isVisible: true,
                isMiniaturized: false
            )
        )
    }

    @Test("reuses a miniaturized prismBar workspace")
    func reusesMiniaturizedWorkspace() {
        #expect(
            SceneActionRouter.shouldReuseWorkspace(
                title: "prismBar",
                isVisible: false,
                isMiniaturized: true
            )
        )
    }

    @Test("does not reuse a closed workspace")
    func ignoresClosedWorkspace() {
        #expect(
            !SceneActionRouter.shouldReuseWorkspace(
                title: "prismBar",
                isVisible: false,
                isMiniaturized: false
            )
        )
        #expect(
            !SceneActionRouter.shouldReuseWorkspace(
                title: "General",
                isVisible: true,
                isMiniaturized: false
            )
        )
    }
}
