import SwiftUI

// MARK: - Error Banner

/// A banner view for displaying error messages at the top of the content
struct ErrorBanner: View {
    @Environment(\.uiScale) private var uiScale
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            
            Text(message)
                .font(.system(size: 12 * uiScale, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .font(.system(size: 12 * uiScale, weight: .bold))
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(NSLocalizedString("Dismiss error", comment: ""))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.9))
    }
}

// MARK: - Previews

#if DEBUG
struct ErrorBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ErrorBanner(
                message: "Failed to open repository: Command not found",
                onDismiss: {}
            )
            Spacer()
        }
        .frame(width: 360, height: 200)
    }
}
#endif
