//
//  AlertView.swift
//  JogPodWatch
//
//  Alert view shown when the iOS app requires initialization.
//

import SwiftUI

// MARK: - AlertView

/// Alert view displayed when the iOS app is not initialized.
///
/// This view replaces the legacy `AlertInterfaceController` and is shown
/// when the user needs to complete setup on the iPhone before using
/// the watch app.
struct AlertView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)

                Text("JogPod")
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray5))

            // Message
            Text("You need to open the iPhone app, accept terms, and enable location tracking.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Spacer()

            // Close Button
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    AlertView()
}
