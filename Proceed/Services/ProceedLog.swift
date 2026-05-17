import Foundation
import os

/// Centralized loggers for Proceed. Subsystem is the bundle id so Console.app
/// filters consistently. Keep category names short and lowercase.
enum ProceedLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.proceed"

    /// Persistence-layer issues — silent JSON decode failures, save errors,
    /// schema-drift symptoms.
    static let persistence = Logger(subsystem: subsystem, category: "persistence")

    /// Execution engine state transitions worth flagging in production.
    static let execution = Logger(subsystem: subsystem, category: "execution")

    /// CloudKit / sharing diagnostics.
    static let cloud = Logger(subsystem: subsystem, category: "cloud")
}
