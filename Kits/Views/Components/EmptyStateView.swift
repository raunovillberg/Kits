import SwiftUI

// MARK: - Empty State View

/// View shown when no root folder is selected
struct EmptyStateView: View {
    @Environment(\.uiScale) private var uiScale
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: Constants.UI.emptyStateIconSize))
                .foregroundColor(.secondary)
            Text("No folder selected")
                .font(.uiScaled(.title3, scale: uiScale))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No folder selected")
        .accessibilityHint("Click the folder button in the header to select a root folder")
    }
}

// MARK: - Previews

#if DEBUG
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyStateView()
            .frame(width: 450, height: 300)
    }
}
#endif
