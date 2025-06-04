import Foundation
import SwiftUI

class TranscriptionPromptService: ObservableObject {
    @Published var allPrompts: [TranscriptionPrompt] = []
    @Published var selectedPromptId: UUID?
    
    private let userDefaults = UserDefaults.standard
    private let customPromptsKey = "CustomTranscriptionPrompts"
    private let selectedPromptKey = "SelectedTranscriptionPromptId"
    
    init() {
        loadPrompts()
    }
    
    // MARK: - Public Methods
    
    var selectedPrompt: TranscriptionPrompt? {
        if let selectedId = selectedPromptId {
            return allPrompts.first { $0.id == selectedId }
        }
        return TranscriptionPrompt.defaultSelectedPrompt
    }
    
    func setActivePrompt(_ prompt: TranscriptionPrompt) {
        selectedPromptId = prompt.id
        userDefaults.set(prompt.id.uuidString, forKey: selectedPromptKey)
    }
    
    func addCustomPrompt(_ prompt: TranscriptionPrompt) {
        var newPrompt = prompt
        newPrompt.isDefault = false
        allPrompts.append(newPrompt)
        saveCustomPrompts()
    }
    
    func updatePrompt(_ prompt: TranscriptionPrompt) {
        if let index = allPrompts.firstIndex(where: { $0.id == prompt.id }) {
            allPrompts[index] = prompt
            if !prompt.isDefault {
                saveCustomPrompts()
            }
        }
    }
    
    func deletePrompt(_ prompt: TranscriptionPrompt) {
        guard !prompt.isDefault else { return } // Can't delete default prompts
        
        allPrompts.removeAll { $0.id == prompt.id }
        
        // If deleted prompt was selected, select default
        if selectedPromptId == prompt.id {
            setActivePrompt(TranscriptionPrompt.defaultSelectedPrompt)
        }
        
        saveCustomPrompts()
    }
    
    // MARK: - Private Methods
    
    private func loadPrompts() {
        // Start with default prompts
        allPrompts = TranscriptionPrompt.defaultPrompts
        
        // Load custom prompts
        if let data = userDefaults.data(forKey: customPromptsKey),
           let customPrompts = try? JSONDecoder().decode([TranscriptionPrompt].self, from: data) {
            allPrompts.append(contentsOf: customPrompts)
        }
        
        // Load selected prompt
        if let selectedIdString = userDefaults.string(forKey: selectedPromptKey),
           let selectedId = UUID(uuidString: selectedIdString),
           allPrompts.contains(where: { $0.id == selectedId }) {
            selectedPromptId = selectedId
        } else {
            // Default to "Translate to English"
            setActivePrompt(TranscriptionPrompt.defaultSelectedPrompt)
        }
    }
    
    private func saveCustomPrompts() {
        let customPrompts = allPrompts.filter { !$0.isDefault }
        if let data = try? JSONEncoder().encode(customPrompts) {
            userDefaults.set(data, forKey: customPromptsKey)
        }
    }
    
    // MARK: - Computed Properties
    
    var defaultPrompts: [TranscriptionPrompt] {
        return allPrompts.filter { $0.isDefault }
    }
    
    var customPrompts: [TranscriptionPrompt] {
        return allPrompts.filter { !$0.isDefault }
    }
}
