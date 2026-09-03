// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import AppKit
import SwiftUI
struct PrismRailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.prismTextSizePreference) private var textSize
    let snapshot: MenuBarSnapshot
    @Binding private var selectedSurfaceID: MenuBarSurfaceID
    @Binding private var selectedItemID: MenuBarItemID?
    @State private var dragTokens: [MenuBarItemID: String]
    @State private var targetedItemID: MenuBarItemID?
    @State private var targetedSection: MenuBarSection?
    @AccessibilityFocusState private var focusedItemID: MenuBarItemID?

    init(
        snapshot: MenuBarSnapshot,
        selectedSurfaceID: Binding<MenuBarSurfaceID>,
        selectedItemID: Binding<MenuBarItemID?>
    ) {
        self.snapshot = snapshot
        _selectedSurfaceID = selectedSurfaceID
        _selectedItemID = selectedItemID
        _dragTokens = State(initialValue: PrismRailViewSupport.makeDragTokens(for: snapshot))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            lane(for: .visible)
            PrismGateView(isActive: targetedSection != nil || targetedItemID != nil)
            lane(for: .hidden)
        }
        .padding(14)
        .background(.background.secondary, in: .rect(cornerRadius: 18))
        .accessibilityIdentifier("prismRail")
        .onAppear {
            resolveSelection()
        }
        .onChange(of: snapshot.generation) {
            dragTokens = PrismRailViewSupport.makeDragTokens(for: snapshot)
            targetedItemID = nil
            targetedSection = nil
            resolveSelection()
        }
        .onChange(of: snapshot.surfaceIDs) {
            resolveSelection()
        }
        .onChange(of: selectedSurfaceID) {
            selectedItemID = PrismRailSelectionResolver().resolve(
                selectedItemID,
                in: snapshot,
                surfaceID: selectedSurfaceID
            )
        }
    }
}

private extension PrismRailView {
    var layout: PrismRailLayout {
        PrismRailLayout(snapshot: snapshot, currentSurfaceID: selectedSurfaceID)
    }

    var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(PrismRailPresentation.title)
                    .prismFont(.headline)
                    .accessibilityAddTraits(.isHeader)

                Text("Drag once. prismBar verifies the result.")
                    .prismFont(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(layout.itemCount)")
                .prismFont(.caption, weight: .semibold, monospacedDigits: true)
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(layout.itemCount) items on this display")

            if snapshot.surfaceIDs.count > 1 {
                surfacePicker
            }
        }
    }

    var surfacePicker: some View {
        Picker("Display", selection: $selectedSurfaceID) {
            ForEach(Array(snapshot.surfaceIDs.enumerated()), id: \.element) { offset, surfaceID in
                Text("Display \(offset + 1)")
                    .tag(surfaceID)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        .accessibilityLabel("Rail display")
    }

    func lane(for section: MenuBarSection) -> some View {
        let laneItems = items(in: section)

        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: PrismRailViewSupport.sectionSymbol(section))
                    .foregroundStyle(section == .visible ? Color.accentColor : .secondary)
                    .accessibilityHidden(true)

                Text(PrismRailViewSupport.sectionTitle(section))
                    .prismFont(.caption, weight: .semibold)

                Text("\(laneItems.count)")
                    .prismFont(.caption2, monospacedDigits: true)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text(PrismRailViewSupport.sectionHint(section))
                    .prismFont(.caption2)
                    .foregroundStyle(.tertiary)
            }

            laneScroller(laneItems, section: section)
            .background(laneBackground(section), in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(laneStroke(section), style: .init(lineWidth: 1, dash: [4, 4]))
            }
            .accessibilityIdentifier("prismRail.\(section.rawValue)")
        }
    }

    func laneScroller(_ laneItems: [MenuBarItem], section: MenuBarSection) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 7) {
                    if laneItems.isEmpty {
                        emptyLane(section)
                    } else {
                        ForEach(laneItems) { item in
                            railItem(item, section: section)
                                .id(item.id)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(4)
            }
            .scrollIndicators(.visible)
            .scrollTargetBehavior(.viewAligned)
            .frame(height: 48 * CGFloat(textSize.scale))
            .dropDestination(for: String.self) { tokens, _ in
                performDrop(tokens: tokens, targetItemID: nil, section: section)
            } isTargeted: { isTargeted in
                targetedSection = isTargeted ? section : nil
            }
            .onChange(of: selectedItemID) {
                guard let selectedItemID,
                      laneItems.contains(where: { $0.id == selectedItemID })
                else { return }
                proxy.scrollTo(selectedItemID, anchor: .center)
                focusedItemID = selectedItemID
            }
        }
    }

    @ViewBuilder
    func railItem(_ item: MenuBarItem, section: MenuBarSection) -> some View {
        let content = railItemContent(item, section: section)
            .dropDestination(for: String.self) { tokens, _ in
                performDrop(tokens: tokens, targetItemID: item.id, section: section)
            } isTargeted: { isTargeted in
                targetedItemID = isTargeted ? item.id : nil
            }

        if canMove(item), let token = dragTokens[item.id] {
            content
                .glassEffect(.regular.interactive(), in: .capsule)
                .draggable(token) {
                    railItemContent(item, section: section)
                        .padding(5)
                        .background(.regularMaterial, in: .capsule)
                }
        } else {
            content
                .background(.quaternary, in: .capsule)
        }
    }

    func railItemContent(_ item: MenuBarItem, section: MenuBarSection) -> some View {
        let laneItems = items(in: section)
        let position = (laneItems.firstIndex(where: { $0.id == item.id }) ?? 0) + 1

        return HStack(spacing: 6) {
            itemIcon(item)

            Text(item.displayName)
                .prismFont(.caption, weight: .medium)
                .lineLimit(1)
                .frame(maxWidth: 150 * CGFloat(textSize.scale))

            if movingItemID == item.id {
                ProgressView()
                    .controlSize(.mini)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 34 * CGFloat(textSize.scale))
        .overlay {
            Capsule()
                .strokeBorder(itemStroke(item), lineWidth: itemStrokeWidth(item))
        }
        .contentShape(.capsule)
        .onTapGesture {
            guard item.ownership == .application else { return }
            selectedItemID = item.id
        }
        .contextMenu {
            railMenu(item, section: section)
        }
        .help(PrismRailViewSupport.itemHelp(item, canMove: canMove(item)))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("prismRail.\(section.rawValue).item.\(position)")
        .accessibilityLabel(item.displayName)
        .accessibilityFocused($focusedItemID, equals: item.id)
        .accessibilityValue(
            canMove(item)
                ? "\(PrismRailViewSupport.sectionTitle(section)), position \(position) " +
                    "of \(laneItems.count), draggable"
                : "\(PrismRailViewSupport.sectionTitle(section)), " +
                    PrismRailViewSupport.fixedItemDescription(item)
        )
        .accessibilityActions {
            railAccessibilityActions(item, section: section)
        }
    }

    @ViewBuilder
    func railMenu(_ item: MenuBarItem, section: MenuBarSection) -> some View {
        if canMove(item) {
            Button(section == .hidden ? "Show" : "Hide") {
                model.moveMenuBarItem(item.id, to: section == .hidden ? .visible : .hidden)
            }
            Divider()
            keyboardMoveButton("Move Left", systemImage: "arrow.left", move: .previous, item: item)
            keyboardMoveButton("Move Right", systemImage: "arrow.right", move: .next, item: item)
            keyboardMoveButton("Move to First Position", systemImage: "arrow.left.to.line", move: .first, item: item)
            keyboardMoveButton("Move to Last Position", systemImage: "arrow.right.to.line", move: .last, item: item)
        }
    }

    @ViewBuilder
    func railAccessibilityActions(_ item: MenuBarItem, section: MenuBarSection) -> some View {
        if canMove(item) {
            Button(section == .hidden ? "Show" : "Hide") {
                model.moveMenuBarItem(item.id, to: section == .hidden ? .visible : .hidden)
            }
            keyboardMoveButton("Move Left", move: .previous, item: item)
            keyboardMoveButton("Move Right", move: .next, item: item)
            keyboardMoveButton("Move to First Position", move: .first, item: item)
            keyboardMoveButton("Move to Last Position", move: .last, item: item)
        }
    }

    @ViewBuilder
    func keyboardMoveButton(
        _ title: String,
        systemImage: String? = nil,
        move: PrismRailKeyboardMove,
        item: MenuBarItem
    ) -> some View {
        let destination = PrismRailKeyboardMoveResolver().resolve(move, itemID: item.id, in: snapshot)
        if let systemImage {
            Button(title, systemImage: systemImage) {
                if let destination { model.moveMenuBarItem(item.id, to: destination) }
            }
            .disabled(destination == nil)
        } else {
            Button(title) {
                if let destination { model.moveMenuBarItem(item.id, to: destination) }
            }
            .disabled(destination == nil)
        }
    }

    func emptyLane(_ section: MenuBarSection) -> some View {
        Label("Drop an item here", systemImage: "arrow.down.to.line.compact")
            .prismFont(.caption)
            .foregroundStyle(.secondary)
            .frame(
                minWidth: 150 * CGFloat(textSize.scale),
                minHeight: 34 * CGFloat(textSize.scale)
            )
            .accessibilityLabel(
                "Empty \(PrismRailViewSupport.sectionTitle(section)). Drop an item here."
            )
    }

    func performDrop(
        tokens: [String],
        targetItemID: MenuBarItemID?,
        section: MenuBarSection
    ) -> Bool {
        guard !model.isMenuBarActionInProgress,
              let token = tokens.first,
              let itemID = dragTokens.first(where: { $0.value == token })?.key
        else {
            return false
        }

        let request = PrismRailDropRequest(
            itemID: itemID,
            snapshotGeneration: snapshot.generation,
            targetItemID: targetItemID,
            destinationSection: section
        )
        guard let action = PrismRailDropResolver().resolve(request, in: snapshot) else {
            return false
        }

        switch action {
        case let .position(position):
            model.moveMenuBarItem(itemID, to: position)
        case let .section(destinationSection):
            model.moveMenuBarItem(itemID, to: destinationSection)
        }
        return true
    }

    func items(in section: MenuBarSection) -> [MenuBarItem] {
        section == .hidden ? layout.hiddenItems : layout.visibleItems
    }

    func canMove(_ item: MenuBarItem) -> Bool {
        item.allowsVerifiedMovement &&
            !model.isMenuBarActionInProgress
    }

    var movingItemID: MenuBarItemID? {
        guard case let .moving(itemID) = model.menuBarActionState else { return nil }
        return itemID
    }

    @ViewBuilder
    func itemIcon(_ item: MenuBarItem) -> some View {
        let symbol = PrismRailViewSupport.itemSymbol(
            isMoving: movingItemID == item.id,
            canMove: canMove(item)
        )
        if item.ownership == .application {
            MenuBarApplicationIcon(
                bundleIdentifier: item.ownerBundleIdentifier,
                fallbackSymbol: symbol,
                size: 16
            )
        } else {
            Image(systemName: symbol)
                .prismFont(.caption2, weight: .semibold)
                .foregroundStyle(movingItemID == item.id ? Color.accentColor : .secondary)
                .accessibilityHidden(true)
        }
    }

    func laneBackground(_ section: MenuBarSection) -> Color {
        targetedSection == section ? .accentColor.opacity(0.12) : .clear
    }

    func laneStroke(_ section: MenuBarSection) -> Color {
        targetedSection == section ? .accentColor : Color(nsColor: .separatorColor).opacity(0.55)
    }

    func itemStroke(_ item: MenuBarItem) -> Color {
        if targetedItemID == item.id { return .accentColor }
        if selectedItemID == item.id { return .accentColor }
        if movingItemID == item.id { return .accentColor.opacity(0.7) }
        return Color(nsColor: .separatorColor).opacity(0.65)
    }

    func itemStrokeWidth(_ item: MenuBarItem) -> CGFloat {
        targetedItemID == item.id || selectedItemID == item.id ? 2 : 0.5
    }

    func resolveSelection() {
        selectedSurfaceID = PrismRailSurfaceResolver().resolve(
            in: snapshot,
            current: selectedSurfaceID
        )
        selectedItemID = PrismRailSelectionResolver().resolve(
            selectedItemID,
            in: snapshot,
            surfaceID: selectedSurfaceID
        )
    }
}
