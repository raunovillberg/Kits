import SwiftUI
import os.log

// MARK: - Header View

/// Header view with folder selection, status, sort toggle, and refresh
struct HeaderView: View {
    @Environment(\.uiScale) private var uiScale
    let folderName: String
    let statusText: String
    let currentScanningPath: String?
    let isScanning: Bool
    let hasRootFolder: Bool
    let sortModeIcon: String
    let sortModeDescription: String
    let onFolderTap: () -> Void
    let onSortTap: () -> Void
    let onRefreshTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Folder button
                Button(action: onFolderTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.uiScaled(.body, scale: uiScale))
                        Text(LocalizedStringKey(folderName))
                            .font(.uiScaled(.body, scale: uiScale))
                            .lineLimit(1)
                    }
                    .foregroundColor(hasRootFolder ? .secondary : .blue)
                }
                .buttonStyle(.plain)
                .help("Click to change root folder")
                
                // Status text
                statusView
            }
            
            Spacer()
            
            // Sort toggle button
            Button(action: onSortTap) {
                Image(systemName: sortModeIcon)
                    .font(.system(size: Constants.Typography.headerIconSize * uiScale))
                    .frame(minWidth: Constants.UI.minTouchTargetSize * uiScale, minHeight: Constants.UI.minTouchTargetSize * uiScale)
                    .contentShape(Rectangle())
                    .help(sortModeDescription)
            }
            .buttonStyle(.plain)
            .disabled(!hasRootFolder)
            .accessibilityLabel(Text("Sort by \(sortModeDescription)"))
            .accessibilityHint(NSLocalizedString("Click to change sort mode", comment: ""))
            .padding(.trailing, Constants.UI.headerButtonTrailingPadding * uiScale)
            
            // Refresh button
            Button(action: onRefreshTap) {
                ZStack {
                    if isScanning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: Constants.Typography.headerIconSize * uiScale))
                    }
                }
                .frame(minWidth: Constants.UI.minTouchTargetSize * uiScale, minHeight: Constants.UI.minTouchTargetSize * uiScale)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isScanning || !hasRootFolder)
            .accessibilityLabel(NSLocalizedString("Refresh repositories", comment: ""))
            .help("Refresh now")
        }
        .padding(.horizontal, Constants.UI.headerPaddingHorizontal)
        .padding(.vertical, Constants.UI.headerPaddingVertical)
    }
    
    /// Status text view that shows different states based on scanning progress
    @ViewBuilder
    private var statusView: some View {
        if isScanning {
            Text(statusText)
                .font(.uiScaled(.body, scale: uiScale))
                .foregroundColor(.secondary)
                .lineLimit(1)
        } else if !statusText.isEmpty {
            Text(statusText)
                .font(.uiScaled(.body, scale: uiScale))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Previews

#if DEBUG
struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // No folder selected
            HeaderView(
                folderName: "Choose root folder...",
                statusText: "",
                currentScanningPath: nil,
                isScanning: false,
                hasRootFolder: false,
                sortModeIcon: "arrow.down.circle",
                sortModeDescription: "Current branch commit date",
                onFolderTap: {},
                onSortTap: {},
                onRefreshTap: {}
            )
            
            // With folder, not scanning
            HeaderView(
                folderName: "~/Projects",
                statusText: "5 repos, updated 2 min ago",
                currentScanningPath: nil,
                isScanning: false,
                hasRootFolder: true,
                sortModeIcon: "arrow.down.circle.fill",
                sortModeDescription: "Any branch commit date",
                onFolderTap: {},
                onSortTap: {},
                onRefreshTap: {}
            )
            
            // Scanning
            HeaderView(
                folderName: "~/Projects",
                statusText: "Updating 3/10...",
                currentScanningPath: nil,
                isScanning: true,
                hasRootFolder: true,
                sortModeIcon: "doc.badge.clock",
                sortModeDescription: "File modification date",
                onFolderTap: {},
                onSortTap: {},
                onRefreshTap: {}
            )
        }
        .frame(width: 450)
        .padding()
    }
}
#endif
