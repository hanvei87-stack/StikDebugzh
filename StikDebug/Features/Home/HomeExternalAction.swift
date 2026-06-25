//
//  HomeExternalAction.swift
//  StikDebug
//

import Foundation
import SwiftUI

struct JITEnableConfiguration {
    var bundleID: String?
    var pid: Int?
    var scriptData: Data?
    var scriptName: String?
}

enum HomeExternalAction: Identifiable {
    case enableJIT(JITEnableConfiguration)
    case killProcess(Int)
    case launchApp(String)

    var id: String {
        switch self {
        case .enableJIT(let configuration):
            return "enable-\(configuration.bundleID ?? "")-\(configuration.pid ?? 0)-\(configuration.scriptName ?? "")"
        case .killProcess(let pid):
            return "kill-\(pid)"
        case .launchApp(let bundleID):
            return "launch-\(bundleID)"
        }
    }

    var title: String {
        switch self {
        case .enableJIT:
            return "Enable JIT?".localized
        case .killProcess:
            return "Kill Process?".localized
        case .launchApp:
            return "Launch App?".localized
        }
    }

    var message: String {
        switch self {
        case .enableJIT(let configuration):
            if configuration.scriptData == nil {
                return String(format: "An external link wants to enable JIT for %@.".localized, targetDescription(for: configuration))
            }
            return String(format: "An external link wants to enable JIT and run a script for %@.".localized, targetDescription(for: configuration))
        case .killProcess(let pid):
            return String(format: "An external link wants to kill process %d.".localized, pid)
        case .launchApp(let bundleID):
            return String(format: "An external link wants to launch %@.".localized, bundleID)
        }
    }

    var confirmationTitle: String {
        switch self {
        case .enableJIT(let configuration):
            return configuration.scriptData == nil ? "Enable JIT".localized : "Enable and Run Script".localized
        case .killProcess:
            return "Kill Process".localized
        case .launchApp:
            return "Launch App".localized
        }
    }

    var role: ButtonRole? {
        switch self {
        case .enableJIT(let configuration):
            return configuration.scriptData == nil ? nil : .destructive
        case .killProcess:
            return .destructive
        case .launchApp:
            return nil
        }
    }

    private func targetDescription(for configuration: JITEnableConfiguration) -> String {
        if let bundleID = configuration.bundleID {
            return bundleID
        }
        if let pid = configuration.pid {
            return String(format: "process %d".localized, pid)
        }
        return "the requested app".localized
    }
}
