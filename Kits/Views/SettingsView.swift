import SwiftUI

struct SettingsView: View {
    @Bindable var settings: Settings
    @Bindable var launchAtLoginHelper: LaunchAtLoginHelper
    
    private var uiScale: CGFloat {
        CGFloat(settings.uiScale)
    }
    
    private let sizeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(NSLocalizedString("Settings", comment: ""))
                    .font(.uiScaled(.headline, scale: uiScale))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("On repo clicked:", comment: ""))
                        .font(.uiScaled(.subheadline, scale: uiScale))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $settings.clickAction) {
                        ForEach(RepoClickAction.allCases) { action in
                            Text(action.displayName).tag(action)
                        }
                    }
                    .labelsHidden()
                    .font(.uiScaled(.body, scale: uiScale))
                    .fixedSize()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("Command", comment: ""))
                            .font(.uiScaled(.subheadline, scale: uiScale))
                            .foregroundColor(.secondary)
                        Spacer()
                        if settings.clickAction != .custom {
                            Text(NSLocalizedString("Read-only (Presets)", comment: ""))
                                .font(.uiScaled(.caption1, scale: uiScale))
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    
                    TextField(NSLocalizedString("e.g. open \"{path}\"", comment: ""), text: $settings.customCommand)
                        .textFieldStyle(.roundedBorder)
                        .disabled(settings.clickAction != .custom)
                        .font(.uiScaled(.body, scale: uiScale, design: .monospaced))
                        .onChange(of: settings.customCommand) { _, newValue in
                            // Trigger validation update on change
                            _ = try? settings.validateCommand(newValue)
                        }
                    
                    if let error = settings.commandError {
                        Text(error)
                            .font(.uiScaled(.caption1, scale: uiScale))
                            .foregroundColor(.red)
                    }
                    
                    Text(NSLocalizedString("Use {path} as a placeholder for the repository path.", comment: ""))
                        .font(.uiScaled(.caption1, scale: uiScale))
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("Popover size:", comment: ""))
                            .font(.uiScaled(.subheadline, scale: uiScale))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(NSLocalizedString("Reset", comment: "")) {
                            settings.popoverWidth = Double(Constants.UI.popoverWidth)
                            settings.popoverHeight = Double(Constants.UI.popoverHeight)
                        }
                        .font(.uiScaled(.caption1, scale: uiScale))
                        .buttonStyle(.link)
                    }
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Text(NSLocalizedString("Width", comment: ""))
                                .font(.uiScaled(.caption1, scale: uiScale))
                                .foregroundColor(.secondary)
                            TextField("", value: $settings.popoverWidth, formatter: sizeFormatter)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 64)
                            Text("px")
                                .font(.uiScaled(.caption1, scale: uiScale))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 6) {
                            Text(NSLocalizedString("Height", comment: ""))
                                .font(.uiScaled(.caption1, scale: uiScale))
                                .foregroundColor(.secondary)
                            TextField("", value: $settings.popoverHeight, formatter: sizeFormatter)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 64)
                            Text("px")
                                .font(.uiScaled(.caption1, scale: uiScale))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("UI scale:", comment: ""))
                            .font(.uiScaled(.subheadline, scale: uiScale))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(settings.uiScale * 100))%")
                            .font(.uiScaled(.caption1, scale: uiScale))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $settings.uiScale, in: Constants.UI.uiScaleMin...Constants.UI.uiScaleMax, step: 0.05)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("App behavior:", comment: ""))
                        .font(.uiScaled(.subheadline, scale: uiScale))
                        .foregroundColor(.secondary)
                    
                    Toggle(NSLocalizedString("Launch at Login", comment: ""), isOn: $launchAtLoginHelper.isEnabled)
                        .font(.uiScaled(.body, scale: uiScale))
                }
            }
            .padding(Constants.UI.settingsPadding)
        }
        .frame(width: Constants.UI.settingsPopoverWidth, height: Constants.UI.settingsPopoverHeight)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(settings: Settings(), launchAtLoginHelper: LaunchAtLoginHelper())
    }
}
