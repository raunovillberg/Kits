import SwiftUI
import os.log

// MARK: - Content View

/// Main content view for the Kits popover
struct ContentView: View {
    @Environment(ContentViewModel.self) private var viewModel
    @State private var showingFolderPicker = false
    @State private var scrollToTopTrigger = UUID()
    
    var body: some View {
        VStack(spacing: 0) {
            // Error banner
            if let errorMessage = viewModel.errorMessage {
                ErrorBanner(message: errorMessage, onDismiss: { viewModel.clearError() })
            }
            
            HeaderView(
                folderName: viewModel.folderName,
                statusText: viewModel.statusText,
                currentScanningPath: viewModel.currentScanningPath,
                isScanning: viewModel.isScanning,
                hasRootFolder: viewModel.hasRootFolder,
                sortModeIcon: viewModel.sortModeIcon,
                sortModeDescription: viewModel.sortModeDescription,
                onFolderTap: { showingFolderPicker = true },
                onSortTap: { 
                    if viewModel.cycleSortMode() {
                        scrollToTopTrigger = UUID()
                    }
                },
                onRefreshTap: { viewModel.refresh() }
            )
            
            Divider()
            
            contentView
        }
        .frame(width: viewModel.popoverWidth, height: viewModel.popoverHeight)
        .environment(\.uiScale, viewModel.uiScale)
        .background {
            // Invisible buttons for keyboard shortcuts
            // These only work when the popover is open
            ZStack {
                Button("") {
                    if viewModel.cycleSortMode() {
                        scrollToTopTrigger = UUID()
                    }
                }
                .keyboardShortcut(.tab, modifiers: .command)
                
                Button("") {
                    if viewModel.cycleSortMode(reverse: true) {
                        scrollToTopTrigger = UUID()
                    }
                }
                .keyboardShortcut(.tab, modifiers: [.command, .shift])
                
                Button("") {
                    viewModel.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            .opacity(0)
            .allowsHitTesting(false)
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
    }
    
    /// Main content area that switches between empty state, loading, and list
    @ViewBuilder
    private var contentView: some View {
        if !viewModel.hasRootFolder {
            EmptyStateView()
        } else if viewModel.repositories.isEmpty && viewModel.isScanning {
            LoadingView()
        } else {
            RepositoryListView(
                repositories: viewModel.repositories,
                scrollToTopTrigger: scrollToTopTrigger,
                onRepoTap: { repo in
                    viewModel.openRepository(at: repo.path)
                }
            )
        }
    }
    
    /// Handles the folder selection result from the file importer
    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                viewModel.setRootFolder(path: url.path)
            }
        case .failure(let error):
            viewModel.showError("Failed to select folder: \(error.localizedDescription)")
            Logger.settings.error("Failed to select folder: \(error.localizedDescription)")
        }
    }
}

// MARK: - Previews

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(ContentViewModel.preview())
            .frame(height: 400)
    }
}
#endif
