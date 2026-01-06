//
//  ShareService.swift
//  JogPod
//
//  Created during migration from legacy SocialIntegration.
//  Replaces deprecated Social.framework (ACAccountStore, SLRequest, SLServiceType).
//
//  Migration Notes:
//  - The legacy SocialIntegration used ACAccountStore to access system-level
//    Twitter and Facebook accounts, then posted directly via SLRequest.
//  - These APIs were deprecated in iOS 11 and removed in later versions.
//  - This modern implementation uses UIActivityViewController for UIKit contexts
//    and ShareLink for SwiftUI contexts, which present the system share sheet.
//  - Users now choose their destination (Twitter, Facebook, Messages, etc.)
//    at share time rather than pre-configuring accounts.
//

import Foundation
import UIKit
import SwiftUI
import Observation
import OSLog

// MARK: - Share Service

/// Service for sharing workout data and achievements.
/// Replaces the deprecated SocialIntegration that used Social.framework.
@MainActor
@Observable
final class ShareService {
    // MARK: - Types

    enum ShareError: LocalizedError, Sendable {
        case noContent
        case presentationFailed
        case cancelled
        case unknown(Error)

        var errorDescription: String? {
            switch self {
            case .noContent:
                return "No content available to share"
            case .presentationFailed:
                return "Unable to present share sheet"
            case .cancelled:
                return "Share cancelled"
            case .unknown(let error):
                return "Share failed: \(error.localizedDescription)"
            }
        }
    }

    enum ShareResult: Sendable {
        case success(activityType: String?)
        case cancelled
        case failure(ShareError)
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.jogpod.app", category: "ShareService")

    /// Indicates whether a share operation is in progress
    private(set) var isSharing = false

    /// The most recent share result
    private(set) var lastShareResult: ShareResult?

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Shares workout content using UIActivityViewController.
    /// Use this method when presenting from a UIKit context.
    ///
    /// - Parameters:
    ///   - content: The shareable content to share
    ///   - sourceView: The view to anchor the popover on iPad
    ///   - completion: Called when sharing completes
    func share(
        _ content: some ShareableContent,
        from sourceView: UIView? = nil,
        completion: ((ShareResult) -> Void)? = nil
    ) {
        guard !isSharing else {
            logger.warning("Share already in progress")
            completion?(.cancelled)
            return
        }

        isSharing = true

        // Build activity items
        var activityItems: [Any] = [content.shareText]

        if let url = content.shareURL {
            activityItems.append(url)
        }

        if let image = content.shareImage {
            activityItems.append(image)
        }

        let activityController = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        // Exclude certain activity types if desired
        activityController.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList
        ]

        // Handle completion
        activityController.completionWithItemsHandler = { [weak self] activityType, completed, _, error in
            guard let self else { return }

            self.isSharing = false

            let result: ShareResult
            if let error {
                result = .failure(.unknown(error))
                self.logger.error("Share failed: \(error.localizedDescription)")
            } else if completed {
                result = .success(activityType: activityType?.rawValue)
                self.logger.info("Share completed via: \(activityType?.rawValue ?? "unknown")")
            } else {
                result = .cancelled
                self.logger.info("Share cancelled")
            }

            self.lastShareResult = result
            completion?(result)
        }

        // Configure popover for iPad
        if let sourceView {
            activityController.popoverPresentationController?.sourceView = sourceView
            activityController.popoverPresentationController?.sourceRect = sourceView.bounds
        }

        // Present the share sheet
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            logger.error("Could not find root view controller for share presentation")
            isSharing = false
            let result = ShareResult.failure(.presentationFailed)
            lastShareResult = result
            completion?(result)
            return
        }

        // Find the topmost presented controller
        var presenter = rootViewController
        while let presented = presenter.presentedViewController {
            presenter = presented
        }

        presenter.present(activityController, animated: true)
    }

    /// Creates shareable workout content from workout data.
    ///
    /// - Parameters:
    ///   - duration: Workout duration in seconds
    ///   - distance: Distance covered in meters
    ///   - averagePace: Average pace in seconds per kilometer (optional)
    ///   - calories: Calories burned (optional)
    ///   - date: Date of the workout
    ///   - message: Custom message to include (optional)
    /// - Returns: Configured WorkoutShareContent ready to share
    func createWorkoutContent(
        duration: TimeInterval,
        distance: Double,
        averagePace: TimeInterval? = nil,
        calories: Double? = nil,
        date: Date = Date(),
        message: String? = nil
    ) -> WorkoutShareContent {
        WorkoutShareContent(
            duration: duration,
            distance: distance,
            averagePace: averagePace,
            calories: calories,
            workoutDate: date,
            customMessage: message
        )
    }

    /// Creates shareable achievement content.
    ///
    /// - Parameters:
    ///   - title: Achievement title
    ///   - description: Achievement description
    ///   - earnedDate: Date the achievement was earned
    ///   - badgeImage: Optional badge image
    /// - Returns: Configured AchievementShareContent ready to share
    func createAchievementContent(
        title: String,
        description: String,
        earnedDate: Date = Date(),
        badgeImage: UIImage? = nil
    ) -> AchievementShareContent {
        AchievementShareContent(
            achievementTitle: title,
            achievementDescription: description,
            earnedDate: earnedDate,
            badgeImage: badgeImage
        )
    }
}

// MARK: - SwiftUI Share Sheet View

/// A SwiftUI view that presents a share sheet.
/// Use this when you need imperative control over share sheet presentation.
struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?
    let excludedActivityTypes: [UIActivity.ActivityType]?
    let onComplete: ((Bool, UIActivity.ActivityType?) -> Void)?

    init(
        activityItems: [Any],
        applicationActivities: [UIActivity]? = nil,
        excludedActivityTypes: [UIActivity.ActivityType]? = nil,
        onComplete: ((Bool, UIActivity.ActivityType?) -> Void)? = nil
    ) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
        self.excludedActivityTypes = excludedActivityTypes
        self.onComplete = onComplete
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            onComplete?(completed, activityType)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - View Modifier for Share Sheet

/// View modifier that provides easy share sheet presentation.
struct ShareSheetModifier<ShareContent: ShareableContent>: ViewModifier {
    @Binding var isPresented: Bool
    let shareContent: ShareContent
    let onComplete: ((Bool, UIActivity.ActivityType?) -> Void)?

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            ShareSheetView(
                activityItems: buildActivityItems(),
                onComplete: { completed, activityType in
                    isPresented = false
                    onComplete?(completed, activityType)
                }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private func buildActivityItems() -> [Any] {
        var items: [Any] = [shareContent.shareText]
        if let url = shareContent.shareURL {
            items.append(url)
        }
        if let image = shareContent.shareImage {
            items.append(image)
        }
        return items
    }
}

extension View {
    /// Presents a share sheet with the given content.
    ///
    /// - Parameters:
    ///   - isPresented: Binding to control sheet presentation
    ///   - content: The shareable content to share
    ///   - onComplete: Called when sharing completes
    func shareSheet<ShareContent: ShareableContent>(
        isPresented: Binding<Bool>,
        content: ShareContent,
        onComplete: ((Bool, UIActivity.ActivityType?) -> Void)? = nil
    ) -> some View {
        modifier(ShareSheetModifier(
            isPresented: isPresented,
            shareContent: content,
            onComplete: onComplete
        ))
    }
}

// MARK: - SwiftUI ShareLink Convenience

/// Convenience wrapper for creating ShareLink with workout content.
struct WorkoutShareLink<Label: View>: View {
    let content: WorkoutShareContent
    let label: () -> Label

    init(
        content: WorkoutShareContent,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.content = content
        self.label = label
    }

    var body: some View {
        ShareLink(item: content.shareText) {
            label()
        }
    }
}

/// Convenience wrapper for creating ShareLink with any shareable content.
struct ContentShareLink<Content: ShareableContent, Label: View>: View {
    let content: Content
    let label: () -> Label

    init(
        content: Content,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.content = content
        self.label = label
    }

    var body: some View {
        if let image = content.shareImage, let url = content.shareURL {
            ShareLink(
                item: url,
                subject: Text(content.shareText),
                message: Text(content.shareText),
                preview: SharePreview(content.shareText, image: Image(uiImage: image))
            ) {
                label()
            }
        } else if let url = content.shareURL {
            ShareLink(
                item: url,
                subject: Text(content.shareText),
                message: Text(content.shareText)
            ) {
                label()
            }
        } else {
            ShareLink(item: content.shareText) {
                label()
            }
        }
    }
}
