import Foundation
import os
import UniformTypeIdentifiers

// Gemini Audio Transcription Service for VoiceInk
class GeminiAudioTranscription {
    static let shared = GeminiAudioTranscription()
    
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "GeminiAudioTranscription")
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    
    private init() {}
    
    // Check if Gemini transcription is enabled and configured
    var isEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "UseGeminiTranscription")
    }
    
    var isConfigured: Bool {
        let aiService = AIService()
        return aiService.isAPIKeyValid && aiService.selectedProvider.rawValue == "Gemini"
    }
    
    // Enable/disable Gemini transcription
    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "UseGeminiTranscription")
    }
    
    // Transcribe audio using Gemini 2.5 Pro
    func transcribe(audioURL: URL, language: String?) async throws -> String {
        guard isConfigured else {
            throw NSError(
                domain: "GeminiAudioTranscription", 
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Gemini API not configured. Please set up Gemini in AI Provider settings."]
            )
        }
        
        logger.notice("🔄 Starting Gemini audio transcription")
        
        // Get AI service instance for API key and model
        let aiService = AIService()
        let apiKey = aiService.apiKey
        let model = aiService.currentModel
        
        // Validate file size (20MB limit)
        let fileSize = try getFileSize(audioURL)
        let maxSize: Int64 = 20 * 1024 * 1024 // 20MB
        guard fileSize <= maxSize else {
            throw NSError(
                domain: "GeminiAudioTranscription",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Audio file too large. Maximum size is 20MB."]
            )
        }
        
        // Convert audio to base64
        let audioData = try Data(contentsOf: audioURL)
        let base64Audio = audioData.base64EncodedString()
        
        // Determine MIME type
        let mimeType = getMimeType(for: audioURL)
        
        logger.notice("📁 Audio file: \(self.formatFileSize(fileSize)), MIME: \(mimeType)")
        
        // Get transcription prompt from service
        let transcriptionPrompt = getSelectedTranscriptionPrompt()
        
        // Create Gemini request
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": transcriptionPrompt
                        ],
                        [
                            "inline_data": [
                                "mime_type": mimeType,
                                "data": base64Audio
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        // Build request URL
        let fullURL = "\(baseURL)/\(model):generateContent"
        var urlComponents = URLComponents(string: fullURL)!
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        
        guard let url = urlComponents.url else {
            throw NSError(
                domain: "GeminiAudioTranscription",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Invalid request URL"]
            )
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // Longer timeout for audio processing
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw NSError(
                domain: "GeminiAudioTranscription",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode request: \(error.localizedDescription)"]
            )
        }
        
        logger.notice("📤 Sending transcription request to Gemini...")
        
        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "GeminiAudioTranscription",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Network error"]
            )
        }
        
        logger.notice("📥 Response status: \(httpResponse.statusCode)")
        
        // Handle response
        switch httpResponse.statusCode {
        case 200:
            return try parseTranscriptionResponse(data)
            
        case 400:
            let errorMessage = try parseErrorResponse(data) ?? "Bad request - check audio format and size"
            logger.error("❌ Gemini API: Bad request - \(errorMessage)")
            throw NSError(
                domain: "GeminiAudioTranscription",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            )
            
        case 401:
            logger.error("❌ Gemini API: Unauthorized")
            throw NSError(
                domain: "GeminiAudioTranscription",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: "Invalid API key"]
            )
            
        case 403:
            logger.error("❌ Gemini API: Forbidden")
            throw NSError(
                domain: "GeminiAudioTranscription",
                code: 8,
                userInfo: [NSLocalizedDescriptionKey: "API access forbidden - check permissions"]
            )
            
        case 429:
            logger.error("❌ Gemini API: Rate limited")
            throw NSError(
                domain: "GeminiAudioTranscription",
                code: 9,
                userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded - please try again later"]
            )
            
        default:
            let errorMessage = try parseErrorResponse(data) ?? "Unknown error"
            logger.error("❌ Gemini API: Error \(httpResponse.statusCode) - \(errorMessage)")
            throw NSError(
                domain: "GeminiAudioTranscription",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "Gemini API error: \(httpResponse.statusCode)"]
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func getFileSize(_ url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    private func getMimeType(for url: URL) -> String {
        if let uti = UTType(filenameExtension: url.pathExtension) {
            return uti.preferredMIMEType ?? "audio/wav"
        }
        return "audio/wav" // Default fallback
    }
    
    private func getSelectedTranscriptionPrompt() -> String {
        let promptService = TranscriptionPromptService()
        return promptService.selectedPrompt?.prompt ?? TranscriptionPrompt.defaultSelectedPrompt.prompt
    }
    
    private func getLanguageName(for code: String) -> String {
        switch code.lowercased() {
        case "en": return "English"
        case "es": return "Spanish"
        case "fr": return "French"
        case "de": return "German"
        case "it": return "Italian"
        case "pt": return "Portuguese"
        case "ru": return "Russian"
        case "ja": return "Japanese"
        case "ko": return "Korean"
        case "zh": return "Chinese"
        case "ar": return "Arabic"
        case "hi": return "Hindi"
        case "nl": return "Dutch"
        default: return "the detected language"
        }
    }
    
    private func parseTranscriptionResponse(_ data: Data) throws -> String {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let text = firstPart["text"] as? String {
                
                let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                logger.notice("✅ Gemini transcription completed: \(cleanedText.count) characters")
                return cleanedText
            } else {
                logger.warning("⚠️ Gemini returned empty or invalid response")
                return ""
            }
        } catch {
            logger.error("❌ Failed to parse Gemini response: \(error.localizedDescription)")
            throw NSError(
                domain: "GeminiAudioTranscription",
                code: 11,
                userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"]
            )
        }
    }
    
    private func parseErrorResponse(_ data: Data) throws -> String? {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                return message
            }
        } catch {
            // Ignore parsing errors for error responses
        }
        return nil
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
