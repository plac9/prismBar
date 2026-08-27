// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import prismBarCore
import SwiftUI

struct PrismRailView: View {
    @Environment(AppModel.self) private var model
    let snapshot: MenuBarSnapshot

    @State private var selectedSurfaceID: MenuBarSurfaceID
    @State private var dragTokens: [MenuBarItemID: String]
    @State private var targetedItemID: MenuBarItemID?
    @State private var targetedSection: MenuBarSection?

    init(snapshot: MenuBarSnapshot) {
        self.snapshot = snapshot
        _selectedSurfaceID = State(
            initialValue: PrismRailSurfaceResolver().resolve(in: snapshot, current: nil)
        )
        _dragTokens = State(initialValue: Self.makeDragTokens(for: snapshot))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            lane(for: .visible)
            lane(for: .hidden)
        }
        .padding(12)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.separator.opacity(0.38), lineWidth: 0.5)
        }
        .accessibilityIdentifier("prismRail")
        .onChange(of: snapshot.generation) {
            dragTokens = Self.makeDragTokens(for: snapshot)
            targetedItemID = nil
            targetedSection = nil
            selectedSurfaceID = PrismRailSurfaceResolver().resolve(
                in: snapshot,
                current: selectedSurfaceID
            )
        }
        .onChange(of: snapshot.surfaceIDs) {
            guard !snapshot.surfaceIDs.contains(selectedSurfaceID) else { return }
            selectedSurfaceID = snapshot.surfaceIDs.first ?? .unknown
        }
    }
}

private extension PrismRailView {
    var header: some View {
        HStack(spacing: 8) {
            Label("Prism Rail", systemImage: "arrow.left.arrow.right")
                .font(.callout.weight(.semibold))

            Text("Drag to place")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if snapshot.surfaceIDs.count > 1 {
                surfacePicker
            }
        }
    }

    var surfacePicker: some View {
        Menu {
            ForEach(Array(snapshot.surfaceIDs.enumerated()), id: \.element) { offset, surfaceID in
                Button {
                    selectedSurfaceID = surfaceID
                } label: {
                    if surfaceID == selectedSurfaceID {
                        Label("Display \(offset + 1)", systemImage: "checkmark")
                    } else {
                        Text("Display \(offset + 1)")
                    }
                }
            }
        } label: {
            Label(selectedSurfaceTitle, systemImage: "display")
        }
        .menuStyle(.button)
        .controlSize(.small)
    }

    func lane(for section: MenuBarSection) -> some View {
        let laneItems = items(in: section)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(sectionTitle(section), systemImage: sectionSymbol(section))
                    .font(.caption.weight(.medium))
                Spacer()
                Text("\(laneItems.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: 6) {
                    if laneItems.isEmpty {
                        emptyLane(section)
                    } else {
                        ForEach(laneItems) { item in
                            railItem(item, section: section)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(2)
            }
            .scrollIndicators(.never)
            .scrollTargetBehavior(.viewAligned)
            .frame(height: 42)
            .dropDestination(for: String.self) { tokens, _ in
                performDrop(tokens: tokens, targetItemID: nil, section: section)
            } isTargeted: { isTargeted in
                targetedSection = isTargeted ? section : nil
            }
            .background(laneBackground(section))
            .clipShape(.rect(cornerRadius: 10))
            .accessibilityIdentifier("prismRail.\(section.rawValue)")
        }
    }

    @ViewBuilder
    func railItem(_ item: MenuBarItem, section: MenuBarSection) -> some View {
        let content = railItemContent(item)
            .dropDestination(for: String.self) { tokens, _ in
                performDrop(tokens: tokens, targetItemID: item.id, section: section)
            } isTargeted: { isTargeted in
                targetedItemID = isTargeted ? item.id : nil
            }

        if canMove(item), let token = dragTokens[item.id] {
            content
                .glassEffect(.regular.interactive(), in: .capsule)
                .draggable(token) {
                    railItemContent(item)
                        .padding(4)
                        .background(.regularMaterial, in: .capsule)
                }
        } else {
            content
                .background(.thinMaterial, in: .capsule)
        }
    }

    func railItemContent(_ item: MenuBarItem) -> some View {
        HStack(spacing: 5) {
            Image(systemName: canMove(item) ? "line.3.horizontal" : "lock.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(item.displayName)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(height: 32)
        .background {
            Capsule()
                .fill(itemBackground(item))
        }
        .overlay {
            Capsule()
                .stroke(itemStroke(item), lineWidth: targetedItemID == item.id ? 2 : 0.5)
        }
        .contentShape(.capsule)
        .help(canMove(item) ? "Drag \(item.displayName) to a new position" : "This item cannot be moved")
        .accessibilityLabel(item.displayName)
        .accessibilityValue(canMove(item) ? "Draggable" : "Unavailable")
    }

    func emptyLane(_ section: MenuBarSection) -> some View {
        Label("Drop here", systemImage: "arrow.down.to.line")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 32)
            .padding(.horizontal, 10)
            .accessibilityLabel("Empty \(sectionTitle(section)) section. Drop an item here.")
    }

    func laneBackground(_ section: MenuBarSection) -> some ShapeStyle {
        targetedSection == section ? AnyShapeStyle(.tint.opacity(0.16)) : AnyShapeStyle(.clear)
    }

    func itemBackground(_ item: MenuBarItem) -> some ShapeStyle {
        if targetedItemID == item.id {
            return AnyShapeStyle(.tint.opacity(0.2))
        }
        return AnyShapeStyle(.background.tertiary)
    }

    func itemStroke(_ item: MenuBarItem) -> Color {
        targetedItemID == item.id ? .accentColor : .secondary.opacity(0.28)
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
        snapshot.items.filter { item in
            item.role == .item &&
                item.surfaceID == selectedSurfaceID &&
                snapshot.section(for: item.id) == section
        }
    }

    func canMove(_ item: MenuBarItem) -> Bool {
        item.isMovable &&
            item.availability == .controllable &&
            !model.isMenuBarActionInProgress
    }

    func sectionTitle(_ section: MenuBarSection) -> String {
        section == .hidden ? "Hidden" : "Visible"
    }

    func sectionSymbol(_ section: MenuBarSection) -> String {
        section == .hidden ? "eye.slash" : "eye"
    }

    var selectedSurfaceTitle: String {
        let offset = snapshot.surfaceIDs.firstIndex(of: selectedSurfaceID) ?? 0
        return "Display \(offset + 1)"
    }

    static func makeDragTokens(for snapshot: MenuBarSnapshot) -> [MenuBarItemID: String] {
        Dictionary(
            uniqueKeysWithValues: snapshot.items
                .filter { $0.role == .item }
                .map { ($0.id, UUID().uuidString) }
        )
    }
}
