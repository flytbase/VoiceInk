import Foundation
import os

enum AIProvider: String, CaseIterable {
    case groq = "GROQ"
    case openAI = "OpenAI"
    case deepSeek = "DeepSeek"
    case gemini = "Gemini"
    case anthropic = "Anthropic"
    case mistral = "Mistral"
    case ollama = "Ollama"
    case custom = "Custom"
    
    var baseURL: String {
        switch self {
        case .groq:
            return "https://api.groq.com/openai/v1/chat/completions"
        case .openAI:
            return "https://api.openai.com/v1/chat/completions"
        case .deepSeek:
            return "https://api.deepseek.com/v1/chat/completions"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta/models"
        case .anthropic:
            return "https://api.anthropic.com/v1/messages"
        case .mistral:
            return "https://api.mistral.ai/v1/chat/completions"
        case .ollama:
            return UserDefaults.standard.string(forKey: "ollamaBaseURL") ?? "http://localhost:11434"
        case .custom:
            return UserDefaults.standard.string(forKey: "customProviderBaseURL") ?? ""
        }
    }
    
    var defaultModel: String {
        switch self {
        case .groq:
            return "llama-3.3-70b-versatile"
        case .openAI:
            return "gpt-4.1-mini"
        case .deepSeek:
            return "deepseek-chat"
        case .gemini:
            return "gemini-2.5-pro-preview-05-06"
        case .anthropic:
            return "claude-3-5-sonnet-20241022"
        case .mistral:
            return "mistral-large-latest"
        case .ollama:
            return UserDefaults.standard.string(forKey: "ollamaSelectedModel") ?? "mistral"
        case .custom:
            return UserDefaults.standard.string(forKey: "customProviderModel") ?? ""
        }
    }
    
    var availableModels: [String] {
        switch self {
        case .groq:
            return [
                "llama-3.3-70b-versatile",
                "llama-3.1-8b-instant"
            ]
        case .openAI:
            return [
                "gpt-4.1",
                "gpt-4.1-mini"
            ]
        case .deepSeek:
            return [
                "deepseek-chat",
                "deepseek-reasoner"
            ]
        case .gemini:
            return [
                "gemini-2.5-pro-preview-05-06",
                "gemini-2.5-flash-preview-04-17",
                "gemini-2.0-flash",
                "gemini-2.0-flash-lite"
            ]
        case .anthropic:
            return [
                "claude-3-7-sonnet-latest",
                "claude-3-5-haiku-latest",
                "claude-3-5-sonnet-latest"
            ]
        case .mistral:
            return [
                "mistral-large-latest",
                "mistral-small-latest",
                "mistral-saba-latest"
            ]
        case .ollama:
            return []
        case .custom:
            return []
        }
    }
    
    var requiresAPIKey: Bool {
        switch self {
        case .ollama:
            return false
        default:
            return true
        }
    }
}

class AIService: ObservableObject {
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "AIService")
    
    @Published var apiKey: String = ""
    @Published var isAPIKeyValid: Bool = false
    @Published var customBaseURL: String = UserDefaults.standard.string(forKey: "customProviderBaseURL") ?? "" {
        didSet {
            userDefaults.set(customBaseURL, forKey: "customProviderBaseURL")
        }
    }
    @Published var customModel: String = UserDefaults.standard.string(forKey: "customProviderModel") ?? "" {
        didSet {
            userDefaults.set(customModel, forKey: "customProviderModel")
        }
    }
    @Published var selectedProvider: AIProvider {
        didSet {
            userDefaults.set(selectedProvider.rawValue, forKey: "selectedAIProvider")
            if selectedProvider.requiresAPIKey {
                if let savedKey = userDefaults.string(forKey: "\(selectedProvider.rawValue)APIKey") {
                    self.apiKey = savedKey
                    self.isAPIKeyValid = true
                } else {
                    self.apiKey = ""
                    self.isAPIKeyValid = false
                }
            } else {
                self.apiKey = ""
                self.isAPIKeyValid = true
                if selectedProvider == .ollama {
                    Task {
                        await ollamaService.checkConnection()
                        await ollamaService.refreshModels()
                    }
                }
            }
        }
    }
    
    @Published private var selectedModels: [AIProvider: String] = [:]
    private let userDefaults = UserDefaults.standard
    private let ollamaService = OllamaService();
    
    var connectedProviders: [AIProvider] {
        AIProvider.allCases.filter { provider in
            if provider == .ollama {
                return ollamaService.isConnected
            } else if provider.requiresAPIKey {
                return userDefaults.string(forKey: "\(provider.rawValue)APIKey") != nil
            }
            return false
        }
    }
    
    var currentModel: String {
        if let selectedModel = selectedModels[selectedProvider],
           !selectedModel.isEmpty,
           (selectedProvider == .ollama && !selectedModel.isEmpty) || availableModels.contains(selectedModel) {
            return selectedModel
        }
        return selectedProvider.defaultModel
    }
    
    var availableModels: [String] {
        if selectedProvider == .ollama {
            return ollamaService.availableModels.map { $0.name }
        }
        return selectedProvider.availableModels
    }
    
    init() {
        if let savedProvider = userDefaults.string(forKey: "selectedAIProvider"),
           let provider = AIProvider(rawValue: savedProvider) {
            self.selectedProvider = provider
        } else {
            self.selectedProvider = .gemini
        }
        
        if selectedProvider.requiresAPIKey {
            if let savedKey = userDefaults.string(forKey: "\(selectedProvider.rawValue)APIKey") {
                self.apiKey = savedKey
                self.isAPIKeyValid = true
            }
        } else {
            self.isAPIKeyValid = true
            if selectedProvider == .ollama {
                Task {
                    await ollamaService.checkConnection()
                    await ollamaService.refreshModels()
                }
            }
        }
        
        loadSavedModelSelections()
    }
    
    private func loadSavedModelSelections() {
        for provider in AIProvider.allCases {
            let key = "\(provider.rawValue)SelectedModel"
            if let savedModel = userDefaults.string(forKey: key), !savedModel.isEmpty {
                selectedModels[provider] = savedModel
            }
        }
    }
    
    func selectModel(_ model: String) {
        guard !model.isEmpty else { return }
        
        selectedModels[selectedProvider] = model
        let key = "\(selectedProvider.rawValue)SelectedModel"
        userDefaults.set(model, forKey: key)
        
        if selectedProvider == .ollama {
            updateSelectedOllamaModel(model)
        }
        
        objectWillChange.send()
    }
    
    func saveAPIKey(_ key: String, completion: @escaping (Bool) -> Void) {
        guard selectedProvider.requiresAPIKey else {
            completion(true)
            return
        }
        
        verifyAPIKey(key) { [weak self] isValid in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if isValid {
                    self.apiKey = key
                    self.isAPIKeyValid = true
                    self.userDefaults.set(key, forKey: "\(self.selectedProvider.rawValue)APIKey")
                    NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
                } else {
                    self.isAPIKeyValid = false
                }
                completion(isValid)
            }
        }
    }
    
    func verifyAPIKey(_ key: String, completion: @escaping (Bool) -> Void) {
        guard selectedProvider.requiresAPIKey else {
            completion(true)
            return
        }
        
        switch selectedProvider {
        case .gemini:
            verifyGeminiAPIKey(key, completion: completion)
        case .anthropic:
            verifyAnthropicAPIKey(key, completion: completion)
        default:
            verifyOpenAICompatibleAPIKey(key, completion: completion)
        }
    }
    
    private func verifyOpenAICompatibleAPIKey(_ key: String, completion: @escaping (Bool) -> Void) {
        let url = URL(string: selectedProvider.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        let testBody: [String: Any] = [
            "model": currentModel,
            "messages": [
                ["role": "user", "content": "test"]
            ],
            "max_tokens": 1
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: testBody)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                completion(httpResponse.statusCode == 200)
            } else {
                completion(false)
            }
        }.resume()
    }
    
    private func verifyAnthropicAPIKey(_ key: String, completion: @escaping (Bool) -> Void) {
        let url = URL(string: selectedProvider.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(key, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let testBody: [String: Any] = [
            "model": currentModel,
            "max_tokens": 1024,
            "system": "You are a test system.",
            "messages": [
                ["role": "user", "content": "test"]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: testBody)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                completion(httpResponse.statusCode == 200)
            } else {
                completion(false)
            }
        }.resume()
    }
    
    private func verifyGeminiAPIKey(_ key: String, completion: @escaping (Bool) -> Void) {
        logger.notice("🔍 Starting Gemini API key verification")
        logger.notice("🔑 API key length: \(key.count) characters")
        logger.notice("🔑 API key prefix: \(String(key.prefix(10)))...")
        
        let baseEndpoint = "https://generativelanguage.googleapis.com/v1beta/models"
        let model = currentModel
        let fullURL = "\(baseEndpoint)/\(model):generateContent"
        
        logger.notice("🌐 Base endpoint: \(baseEndpoint)")
        logger.notice("🤖 Model being used: \(model)")
        logger.notice("🔗 Full URL before query params: \(fullURL)")
        
        var urlComponents = URLComponents(string: fullURL)!
        urlComponents.queryItems = [URLQueryItem(name: "key", value: key)]
        
        guard let url = urlComponents.url else {
            logger.error("❌ Failed to construct URL from components")
            completion(false)
            return
        }
        
        logger.notice("🔗 Final URL: \(url.absoluteString.replacingOccurrences(of: key, with: "\(String(key.prefix(10)))..."))")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        let testBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "Hello, this is a test message for API verification."]
                    ]
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: testBody)
            logger.notice("📤 Request body created successfully")
            if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
                logger.notice("📄 Request body: \(bodyString)")
            }
        } catch {
            logger.error("❌ Failed to serialize request body: \(error.localizedDescription)")
            completion(false)
            return
        }
        
        logger.notice("📤 Sending verification request...")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("❌ Network error: \(error.localizedDescription)")
                self.logger.error("❌ Error details: \(error)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.logger.error("❌ No HTTP response received")
                completion(false)
                return
            }
            
            self.logger.notice("📥 Response status code: \(httpResponse.statusCode)")
            self.logger.notice("📋 Response headers: \(httpResponse.allHeaderFields)")
            
            if let data = data {
                self.logger.notice("📄 Response data size: \(data.count) bytes")
                if let responseString = String(data: data, encoding: .utf8) {
                    self.logger.notice("📄 Response body: \(responseString)")
                } else {
                    self.logger.notice("📄 Response body: [Unable to decode as UTF-8]")
                }
            } else {
                self.logger.notice("📄 No response data received")
            }
            
            switch httpResponse.statusCode {
            case 200:
                self.logger.notice("✅ Gemini API key verification successful (200)")
                completion(true)
            case 400:
                self.logger.error("❌ Bad request (400) - Check request format")
                completion(false)
            case 401:
                self.logger.error("❌ Unauthorized (401) - Invalid API key")
                completion(false)
            case 403:
                self.logger.error("❌ Forbidden (403) - API key lacks permissions")
                completion(false)
            case 404:
                self.logger.error("❌ Not found (404) - Check model name or endpoint")
                completion(false)
            case 429:
                self.logger.error("❌ Rate limited (429) - Too many requests")
                completion(false)
            default:
                self.logger.error("❌ Unexpected status code: \(httpResponse.statusCode)")
                completion(false)
            }
        }.resume()
    }
    
    func clearAPIKey() {
        guard selectedProvider.requiresAPIKey else { return }
        
        apiKey = ""
        isAPIKeyValid = false
        userDefaults.removeObject(forKey: "\(selectedProvider.rawValue)APIKey")
        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
    }
    
    func checkOllamaConnection(completion: @escaping (Bool) -> Void) {
        Task { [weak self] in
            guard let self = self else { return }
            await self.ollamaService.checkConnection()
            DispatchQueue.main.async {
                completion(self.ollamaService.isConnected)
            }
        }
    }
    
    func fetchOllamaModels() async -> [OllamaService.OllamaModel] {
        await ollamaService.refreshModels()
        return ollamaService.availableModels
    }
    
    func enhanceWithOllama(text: String, systemPrompt: String) async throws -> String {
        logger.notice("🔄 Sending transcription to Ollama for enhancement (model: \(self.ollamaService.selectedModel))")
        do {
            let result = try await ollamaService.enhance(text, withSystemPrompt: systemPrompt)
            logger.notice("✅ Ollama enhancement completed successfully (\(result.count) characters)")
            return result
        } catch {
            logger.notice("❌ Ollama enhancement failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func updateOllamaBaseURL(_ newURL: String) {
        ollamaService.baseURL = newURL
        userDefaults.set(newURL, forKey: "ollamaBaseURL")
    }
    
    func updateSelectedOllamaModel(_ modelName: String) {
        ollamaService.selectedModel = modelName
        userDefaults.set(modelName, forKey: "ollamaSelectedModel")
    }
}

extension Notification.Name {
    static let aiProviderKeyChanged = Notification.Name("aiProviderKeyChanged")
}
