//
//  MockAVAudioSession.swift
//  JogPodTests
//
//  Mock implementation of AVAudioSession for testing audio session management
//  without interacting with the actual audio system.
//
//  Created for JogPod Revival project.
//

import Foundation
import AVFoundation

// MARK: - AudioSessionProtocol

/// Protocol abstracting AVAudioSession for testability.
///
/// This protocol mirrors the key methods and properties of AVAudioSession
/// that are used by AudioPlayerService, enabling dependency injection
/// for testing purposes.
public protocol AudioSessionProtocol: AnyObject {

    // MARK: - Category Configuration

    /// Sets the audio session category and mode.
    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws

    /// Sets whether the session is active.
    func setActive(_ active: Bool) throws

    /// Sets whether the session is active with options.
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws

    // MARK: - Properties

    /// The current audio session category.
    var category: AVAudioSession.Category { get }

    /// The current audio session mode.
    var mode: AVAudioSession.Mode { get }

    /// The current category options.
    var categoryOptions: AVAudioSession.CategoryOptions { get }

    /// Whether the session is currently active.
    var isOtherAudioPlaying: Bool { get }

    /// The current route description.
    var currentRoute: AVAudioSessionRouteDescription { get }
}

// MARK: - AVAudioSession Conformance

extension AVAudioSession: AudioSessionProtocol {}

// MARK: - MockAVAudioSession

/// A mock implementation of AVAudioSession for testing.
///
/// This mock allows tests to verify audio session configuration and simulate
/// various session events without interacting with the actual audio system.
///
/// ## Usage
///
/// ```swift
/// let mockSession = MockAVAudioSession()
/// let service = AudioPlayerService(
///     persistenceManager: mockPersistence,
///     nowPlayingManager: mockNowPlaying,
///     audioSession: mockSession
/// )
///
/// // Verify configuration
/// #expect(mockSession.configuredCategory == .playback)
/// #expect(mockSession.configuredMode == .spokenAudio)
///
/// // Simulate events
/// mockSession.simulateInterruption(type: .began)
/// mockSession.simulateRouteChange(reason: .oldDeviceUnavailable)
/// ```
public final class MockAVAudioSession: @unchecked Sendable {

    // MARK: - Configuration Tracking

    /// The category set on the session.
    public private(set) var configuredCategory: AVAudioSession.Category?

    /// The mode set on the session.
    public private(set) var configuredMode: AVAudioSession.Mode?

    /// The options set on the session.
    public private(set) var configuredOptions: AVAudioSession.CategoryOptions?

    /// Whether the session is currently active.
    public private(set) var isActive: Bool = false

    /// The options used when deactivating the session.
    public private(set) var deactivationOptions: AVAudioSession.SetActiveOptions?

    /// Count of setCategory calls.
    public private(set) var setCategoryCalls: Int = 0

    /// Count of setActive(true) calls.
    public private(set) var activationCalls: Int = 0

    /// Count of setActive(false) calls.
    public private(set) var deactivationCalls: Int = 0

    // MARK: - Error Simulation

    /// Error to throw on setCategory.
    public var setCategoryError: Error?

    /// Error to throw on setActive.
    public var setActiveError: Error?

    // MARK: - Mock State

    /// Simulated state of other audio playing.
    public var mockIsOtherAudioPlaying: Bool = false

    /// Simulated current route.
    public var mockCurrentRoute: MockAudioSessionRouteDescription?

    // MARK: - Notification Handlers

    /// Handler for interruption notifications.
    public var interruptionHandler: ((AVAudioSession.InterruptionType, AVAudioSession.InterruptionOptions?) -> Void)?

    /// Handler for route change notifications.
    public var routeChangeHandler: ((AVAudioSession.RouteChangeReason, AVAudioSessionRouteDescription?) -> Void)?

    // MARK: - Initialization

    /// Creates a new MockAVAudioSession.
    public init() {}

    // MARK: - Test Helpers

    /// Resets all tracking data and configuration.
    public func reset() {
        configuredCategory = nil
        configuredMode = nil
        configuredOptions = nil
        isActive = false
        deactivationOptions = nil
        setCategoryCalls = 0
        activationCalls = 0
        deactivationCalls = 0
        setCategoryError = nil
        setActiveError = nil
        mockIsOtherAudioPlaying = false
        mockCurrentRoute = nil
        interruptionHandler = nil
        routeChangeHandler = nil
    }

    /// Verifies that the session was configured with expected values.
    ///
    /// - Parameters:
    ///   - category: Expected category.
    ///   - mode: Expected mode.
    ///   - options: Expected options.
    /// - Returns: True if all values match.
    public func verifyConfiguration(
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) -> Bool {
        return configuredCategory == category
            && configuredMode == mode
            && configuredOptions == options
    }

    // MARK: - Simulation Methods

    /// Simulates an audio session interruption.
    ///
    /// This posts a notification that AudioPlayerService observes.
    ///
    /// - Parameters:
    ///   - type: The interruption type (began or ended).
    ///   - options: Options for the ended case.
    public func simulateInterruption(
        type: AVAudioSession.InterruptionType,
        options: AVAudioSession.InterruptionOptions? = nil
    ) {
        var userInfo: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: type.rawValue
        ]

        if let options = options {
            userInfo[AVAudioSessionInterruptionOptionKey] = options.rawValue
        }

        // Notify any registered handler
        interruptionHandler?(type, options)

        // Post the notification
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: self,
            userInfo: userInfo
        )
    }

    /// Simulates an audio route change.
    ///
    /// This posts a notification that AudioPlayerService observes.
    ///
    /// - Parameters:
    ///   - reason: The reason for the route change.
    ///   - previousRoute: The previous route description.
    public func simulateRouteChange(
        reason: AVAudioSession.RouteChangeReason,
        previousRoute: AVAudioSessionRouteDescription? = nil
    ) {
        var userInfo: [AnyHashable: Any] = [
            AVAudioSessionRouteChangeReasonKey: reason.rawValue
        ]

        if let previousRoute = previousRoute {
            userInfo[AVAudioSessionRouteChangePreviousRouteKey] = previousRoute
        }

        // Notify any registered handler
        routeChangeHandler?(reason, previousRoute)

        // Post the notification
        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification,
            object: self,
            userInfo: userInfo
        )
    }

    /// Simulates media services being reset.
    public func simulateMediaServicesReset() {
        NotificationCenter.default.post(
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: self
        )
    }

    /// Simulates media services being lost.
    public func simulateMediaServicesLost() {
        NotificationCenter.default.post(
            name: AVAudioSession.mediaServicesWereLostNotification,
            object: self
        )
    }

    /// Simulates silence secondary audio hint.
    ///
    /// - Parameter shouldSilence: Whether secondary audio should be silenced.
    public func simulateSilenceSecondaryAudioHint(shouldSilence: Bool) {
        let userInfo: [AnyHashable: Any] = [
            AVAudioSessionSilenceSecondaryAudioHintTypeKey: shouldSilence
                ? AVAudioSession.SilenceSecondaryAudioHintType.begin.rawValue
                : AVAudioSession.SilenceSecondaryAudioHintType.end.rawValue
        ]

        NotificationCenter.default.post(
            name: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: self,
            userInfo: userInfo
        )
    }
}

// MARK: - AudioSessionProtocol Conformance

extension MockAVAudioSession: AudioSessionProtocol {

    public func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws {
        setCategoryCalls += 1

        if let error = setCategoryError {
            throw error
        }

        configuredCategory = category
        configuredMode = mode
        configuredOptions = options
    }

    public func setActive(_ active: Bool) throws {
        if let error = setActiveError {
            throw error
        }

        if active {
            activationCalls += 1
        } else {
            deactivationCalls += 1
        }

        isActive = active
    }

    public func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        if let error = setActiveError {
            throw error
        }

        if active {
            activationCalls += 1
        } else {
            deactivationCalls += 1
            deactivationOptions = options
        }

        isActive = active
    }

    public var category: AVAudioSession.Category {
        configuredCategory ?? .soloAmbient
    }

    public var mode: AVAudioSession.Mode {
        configuredMode ?? .default
    }

    public var categoryOptions: AVAudioSession.CategoryOptions {
        configuredOptions ?? []
    }

    public var isOtherAudioPlaying: Bool {
        mockIsOtherAudioPlaying
    }

    public var currentRoute: AVAudioSessionRouteDescription {
        // Note: We cannot create a real AVAudioSessionRouteDescription,
        // so tests should use mockCurrentRoute for verification
        fatalError("Use mockCurrentRoute for testing route information")
    }
}

// MARK: - MockAudioSessionRouteDescription

/// Mock audio route description for testing.
public struct MockAudioSessionRouteDescription {

    /// The output ports in this route.
    public var outputs: [MockAudioSessionPortDescription]

    /// The input ports in this route.
    public var inputs: [MockAudioSessionPortDescription]

    /// Creates a new mock route description.
    public init(
        outputs: [MockAudioSessionPortDescription] = [],
        inputs: [MockAudioSessionPortDescription] = []
    ) {
        self.outputs = outputs
        self.inputs = inputs
    }

    /// Creates a route with built-in speaker output.
    public static var builtInSpeaker: MockAudioSessionRouteDescription {
        MockAudioSessionRouteDescription(
            outputs: [.builtInSpeaker]
        )
    }

    /// Creates a route with headphones output.
    public static var headphones: MockAudioSessionRouteDescription {
        MockAudioSessionRouteDescription(
            outputs: [.headphones]
        )
    }

    /// Creates a route with Bluetooth output.
    public static var bluetooth: MockAudioSessionRouteDescription {
        MockAudioSessionRouteDescription(
            outputs: [.bluetooth]
        )
    }

    /// Creates a route with AirPlay output.
    public static var airPlay: MockAudioSessionRouteDescription {
        MockAudioSessionRouteDescription(
            outputs: [.airPlay]
        )
    }
}

// MARK: - MockAudioSessionPortDescription

/// Mock audio port description for testing.
public struct MockAudioSessionPortDescription {

    /// The port type.
    public var portType: AVAudioSession.Port

    /// The port name.
    public var portName: String

    /// Creates a new mock port description.
    public init(portType: AVAudioSession.Port, portName: String) {
        self.portType = portType
        self.portName = portName
    }

    /// Built-in speaker port.
    public static var builtInSpeaker: MockAudioSessionPortDescription {
        MockAudioSessionPortDescription(portType: .builtInSpeaker, portName: "Speaker")
    }

    /// Headphones port.
    public static var headphones: MockAudioSessionPortDescription {
        MockAudioSessionPortDescription(portType: .headphones, portName: "Headphones")
    }

    /// Bluetooth port.
    public static var bluetooth: MockAudioSessionPortDescription {
        MockAudioSessionPortDescription(portType: .bluetoothA2DP, portName: "Bluetooth Headphones")
    }

    /// AirPlay port.
    public static var airPlay: MockAudioSessionPortDescription {
        MockAudioSessionPortDescription(portType: .airPlay, portName: "AirPlay")
    }

    /// Built-in receiver port.
    public static var builtInReceiver: MockAudioSessionPortDescription {
        MockAudioSessionPortDescription(portType: .builtInReceiver, portName: "Receiver")
    }

    /// Built-in microphone port.
    public static var builtInMic: MockAudioSessionPortDescription {
        MockAudioSessionPortDescription(portType: .builtInMic, portName: "iPhone Microphone")
    }
}

// MARK: - Test Error

/// Test error for simulating audio session failures.
public struct MockAudioSessionError: Error, LocalizedError {

    /// The error message.
    public let message: String

    /// Creates a new mock error.
    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? {
        message
    }

    /// Common test error: cannot activate audio session.
    public static var cannotActivate: MockAudioSessionError {
        MockAudioSessionError("The operation couldn't be completed. Cannot activate audio session.")
    }

    /// Common test error: category not supported.
    public static var categoryNotSupported: MockAudioSessionError {
        MockAudioSessionError("The operation couldn't be completed. Category not supported.")
    }

    /// Common test error: interrupted by another app.
    public static var interruptedByOtherApp: MockAudioSessionError {
        MockAudioSessionError("The operation couldn't be completed. Interrupted by another app.")
    }
}
