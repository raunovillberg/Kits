import SwiftUI

// MARK: - Loading View

/// View shown during initial scan when no repositories are loaded yet
struct LoadingView: View {
    @Environment(\.uiScale) private var uiScale
    var body: some View {
        VStack(spacing: 15) {
            ProgressView()
                .frame(width: Constants.UI.progressViewSize, height: Constants.UI.progressViewSize)
            Text("Finding repositories...")
                .font(.uiScaled(.headline, scale: uiScale))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scanning for repositories")
        .accessibilityHint("Please wait while Kits scans your selected folder for Git repositories")
    }
}

// MARK: - Previews

#if DEBUG
struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
            .frame(width: 450, height: 300)
    }
}
#endif
