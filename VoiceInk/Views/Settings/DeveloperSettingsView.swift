import SwiftUI

struct DeveloperSettingsView: View {
    @StateObject private var loggingService = LoggingService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enable developer mode to access advanced debugging features including the developer console, enhanced logging, and diagnostic tools.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Toggle("Enable Developer Mode", isOn: $loggingService.isDevModeEnabled)
                .toggleStyle(.switch)
                .onChange(of: loggingService.isDevModeEnabled) { _, newValue in
                    loggingService.enableDevMode(newValue)
                }
            
            if loggingService.isDevModeEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.vertical, 4)
                    
                    Text("Developer Features Enabled:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                            Text("Developer console access")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                            Text("Enhanced logging and debugging")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                            Text("Log export capabilities")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 8)
                    
                    Text("Access the developer console from the History page when developer mode is enabled.")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    DeveloperSettingsView()
        .padding()
}
