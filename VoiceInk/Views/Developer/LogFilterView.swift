import SwiftUI

struct LogFilterView: View {
    @Binding var selectedLevels: Set<LogLevel>
    @Binding var selectedCategories: Set<LogCategory>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Log Levels Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Log Levels")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(LogLevel.allCases, id: \.self) { level in
                            FilterToggleRow(
                                title: level.rawValue,
                                icon: level.icon,
                                color: level.color,
                                isSelected: selectedLevels.contains(level)
                            ) {
                                if selectedLevels.contains(level) {
                                    selectedLevels.remove(level)
                                } else {
                                    selectedLevels.insert(level)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Categories Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Categories")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(LogCategory.allCases, id: \.self) { category in
                            FilterToggleRow(
                                title: category.rawValue,
                                icon: category.icon,
                                color: .blue,
                                isSelected: selectedCategories.contains(category)
                            ) {
                                if selectedCategories.contains(category) {
                                    selectedCategories.remove(category)
                                } else {
                                    selectedCategories.insert(category)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Quick Actions
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Button("Select All Levels") {
                            selectedLevels = Set(LogLevel.allCases)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Clear All Levels") {
                            selectedLevels.removeAll()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    HStack(spacing: 12) {
                        Button("Select All Categories") {
                            selectedCategories = Set(LogCategory.allCases)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Clear All Categories") {
                            selectedCategories.removeAll()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Filter Logs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Filter Toggle Row
struct FilterToggleRow: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? color : .secondary)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20)
                
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? color : .secondary)
                    .font(.system(size: 18))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color.opacity(0.1) : Color.clear)
                    .stroke(isSelected ? color.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Preview
#Preview {
    LogFilterView(
        selectedLevels: .constant(Set(LogLevel.allCases)),
        selectedCategories: .constant(Set(LogCategory.allCases))
    )
}
