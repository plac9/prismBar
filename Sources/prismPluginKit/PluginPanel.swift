// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public enum PluginPanelLimits {
    public static let maximumElements = 32
    public static let maximumKeys = 64
    public static let maximumActions = 16
    public static let maximumMutations = 4
    public static let maximumIdentifierCharacters = 80
    public static let maximumLabelCharacters = 120
    public static let maximumValueCharacters = 256
}

public struct PluginCommandInvocation: Equatable, Codable, Sendable {
    public let commandIdentifier: String

    public init(commandIdentifier: String) {
        self.commandIdentifier = commandIdentifier
    }
}

public struct PluginPanelDescriptor: Equatable, Codable, Sendable {
    public let identifier: String
    public let title: String
    public let elements: [PluginPanelElement]

    public init(identifier: String, title: String, elements: [PluginPanelElement]) {
        self.identifier = identifier
        self.title = title
        self.elements = elements
    }
}

public enum PluginPanelElement: Equatable, Codable, Sendable {
    case result(PluginResultDescriptor)
    case keypad(PluginKeypadDescriptor)
    case actions(PluginActionGroupDescriptor)
    case status(PluginStatusDescriptor)
}

public struct PluginResultDescriptor: Equatable, Codable, Sendable {
    public let identifier: String
    public let value: String
    public let accessibilityLabel: String

    public init(identifier: String, value: String, accessibilityLabel: String) {
        self.identifier = identifier
        self.value = value
        self.accessibilityLabel = accessibilityLabel
    }
}

public enum PluginKeyStyle: String, Equatable, Codable, Sendable {
    case standard
    case secondary
    case operation
    case accent
}

public struct PluginKeyDescriptor: Equatable, Codable, Sendable {
    public let identifier: String
    public let label: String
    public let commandIdentifier: String
    public let style: PluginKeyStyle
    public let accessibilityLabel: String

    public init(
        identifier: String,
        label: String,
        commandIdentifier: String,
        style: PluginKeyStyle,
        accessibilityLabel: String
    ) {
        self.identifier = identifier
        self.label = label
        self.commandIdentifier = commandIdentifier
        self.style = style
        self.accessibilityLabel = accessibilityLabel
    }
}

public struct PluginKeypadDescriptor: Equatable, Codable, Sendable {
    public let identifier: String
    public let columns: Int
    public let keys: [PluginKeyDescriptor]

    public init(identifier: String, columns: Int, keys: [PluginKeyDescriptor]) {
        self.identifier = identifier
        self.columns = columns
        self.keys = keys
    }
}

public enum PluginActionStyle: String, Equatable, Codable, Sendable {
    case standard
    case accent
}

public struct PluginActionDescriptor: Equatable, Codable, Sendable {
    public let identifier: String
    public let label: String
    public let commandIdentifier: String
    public let style: PluginActionStyle
    public let accessibilityLabel: String

    public init(
        identifier: String,
        label: String,
        commandIdentifier: String,
        style: PluginActionStyle,
        accessibilityLabel: String
    ) {
        self.identifier = identifier
        self.label = label
        self.commandIdentifier = commandIdentifier
        self.style = style
        self.accessibilityLabel = accessibilityLabel
    }
}

public struct PluginActionGroupDescriptor: Equatable, Codable, Sendable {
    public let identifier: String
    public let actions: [PluginActionDescriptor]

    public init(identifier: String, actions: [PluginActionDescriptor]) {
        self.identifier = identifier
        self.actions = actions
    }
}

public enum PluginStatusKind: String, Equatable, Codable, Sendable {
    case information
    case success
    case warning
    case error
}

public struct PluginStatusDescriptor: Equatable, Codable, Sendable {
    public let identifier: String
    public let message: String
    public let kind: PluginStatusKind

    public init(identifier: String, message: String, kind: PluginStatusKind) {
        self.identifier = identifier
        self.message = message
        self.kind = kind
    }
}

public enum PluginMutation: Equatable, Codable, Sendable {
    case copyText(String)
    case openApplication(bundleIdentifier: String)
}

public struct PluginPanelUpdate: Equatable, Codable, Sendable {
    public let panel: PluginPanelDescriptor
    public let mutations: [PluginMutation]

    public init(panel: PluginPanelDescriptor, mutations: [PluginMutation]) {
        self.panel = panel
        self.mutations = mutations
    }

    public func validated(allowedApplicationIdentifiers: Set<String>) throws -> Self {
        var validator = PluginPanelValidator(
            allowedApplicationIdentifiers: allowedApplicationIdentifiers
        )
        try validator.validate(self)
        return self
    }
}

public enum PluginPanelValidationError: Error, Equatable, Sendable {
    case invalidIdentifier(String)
    case duplicateIdentifier(String)
    case emptyLabel
    case labelTooLong
    case valueTooLong
    case controlCharacters
    case urlContent
    case tooManyElements
    case invalidKeypad
    case tooManyActions
    case tooManyMutations
    case unapprovedApplication(String)
}

private struct PluginPanelValidator {
    let allowedApplicationIdentifiers: Set<String>
    private var identifiers: Set<String> = []

    init(allowedApplicationIdentifiers: Set<String>) {
        self.allowedApplicationIdentifiers = allowedApplicationIdentifiers
    }

    mutating func validate(_ update: PluginPanelUpdate) throws {
        guard update.panel.elements.count <= PluginPanelLimits.maximumElements else {
            throw PluginPanelValidationError.tooManyElements
        }
        guard update.mutations.count <= PluginPanelLimits.maximumMutations else {
            throw PluginPanelValidationError.tooManyMutations
        }

        try validateIdentifier(update.panel.identifier)
        try validateLabel(update.panel.title)
        for element in update.panel.elements {
            try validate(element)
        }
        for mutation in update.mutations {
            try validate(mutation)
        }
    }

    private mutating func validate(_ element: PluginPanelElement) throws {
        switch element {
        case let .result(result):
            try validateIdentifier(result.identifier)
            try validateValue(result.value)
            try validateLabel(result.accessibilityLabel)
        case let .keypad(keypad):
            try validateIdentifier(keypad.identifier)
            guard (1 ... 8).contains(keypad.columns),
                  !keypad.keys.isEmpty,
                  keypad.keys.count <= PluginPanelLimits.maximumKeys
            else {
                throw PluginPanelValidationError.invalidKeypad
            }
            for key in keypad.keys {
                try validateIdentifier(key.identifier)
                try validateCommandIdentifier(key.commandIdentifier)
                try validateLabel(key.label)
                try validateLabel(key.accessibilityLabel)
            }
        case let .actions(group):
            try validateIdentifier(group.identifier)
            guard group.actions.count <= PluginPanelLimits.maximumActions else {
                throw PluginPanelValidationError.tooManyActions
            }
            for action in group.actions {
                try validateIdentifier(action.identifier)
                try validateCommandIdentifier(action.commandIdentifier)
                try validateLabel(action.label)
                try validateLabel(action.accessibilityLabel)
            }
        case let .status(status):
            try validateIdentifier(status.identifier)
            try validateLabel(status.message)
        }
    }

    private func validate(_ mutation: PluginMutation) throws {
        switch mutation {
        case let .copyText(value):
            try validateValue(value)
        case let .openApplication(bundleIdentifier):
            guard allowedApplicationIdentifiers.contains(bundleIdentifier) else {
                throw PluginPanelValidationError.unapprovedApplication(bundleIdentifier)
            }
        }
    }

    private mutating func validateIdentifier(_ identifier: String) throws {
        try validateIdentifierSyntax(identifier)
        guard identifiers.insert(identifier).inserted else {
            throw PluginPanelValidationError.duplicateIdentifier(identifier)
        }
    }

    private func validateCommandIdentifier(_ identifier: String) throws {
        try validateIdentifierSyntax(identifier)
    }

    private func validateIdentifierSyntax(_ identifier: String) throws {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard !identifier.isEmpty,
              identifier.count <= PluginPanelLimits.maximumIdentifierCharacters,
              identifier.unicodeScalars.allSatisfy(allowed.contains)
        else {
            throw PluginPanelValidationError.invalidIdentifier(identifier)
        }
    }

    private func validateLabel(_ label: String) throws {
        guard !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PluginPanelValidationError.emptyLabel
        }
        guard label.count <= PluginPanelLimits.maximumLabelCharacters else {
            throw PluginPanelValidationError.labelTooLong
        }
        try validateTextSafety(label)
    }

    private func validateValue(_ value: String) throws {
        guard value.count <= PluginPanelLimits.maximumValueCharacters else {
            throw PluginPanelValidationError.valueTooLong
        }
        try validateTextSafety(value)
    }

    private func validateTextSafety(_ value: String) throws {
        let controlCharacters = CharacterSet.controlCharacters
        for scalar in value.unicodeScalars where controlCharacters.contains(scalar) {
            throw PluginPanelValidationError.controlCharacters
        }

        let normalized = value.lowercased()
        let forbiddenURLMarkers = [
            "http://",
            "https://",
            "ftp://",
            "file://",
            "data:",
            "javascript:",
            "mailto:",
        ]
        guard !forbiddenURLMarkers.contains(where: normalized.contains) else {
            throw PluginPanelValidationError.urlContent
        }
    }
}
