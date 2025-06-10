import Foundation
import os
import UniformTypeIdentifiers

// Gemini Audio Transcription Service for VoiceInk
@available(*, deprecated, message: "Use GeminiStreamingService instead. This legacy service will be removed in a future version.")
class GeminiAudioTranscription {
    static let shared = GeminiAudioTranscription()
    
    private let loggingService: LoggingService
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    
    private init(loggingService: LoggingService = LoggingService.shared) {
        self.loggingService = loggingService
        
        // Log deprecation warning
        loggingService.warning(
            "GeminiAudioTranscription is deprecated. Use GeminiStreamingService instead.",
            category: .general
        )
    }
    
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
        let startTime = Date()
        let audioFileName = audioURL.lastPathComponent
        let requestId = UUID().uuidString
        
        // Log start of transcription
        loggingService.info(
            "Starting Gemini audio transcription",
            category: .transcription,
            context: [
                "request_id": requestId,
                "file_name": audioFileName,
                "language": language ?? "auto",
                "source": "GeminiAudioTranscription"
            ]
        )
        
        guard isConfigured else {
            loggingService.error(
                "Gemini transcription failed: API not configured",
                category: .transcription,
                context: [
                    "request_id": requestId,
                    "file_name": audioFileName,
                    "source": "GeminiAudioTranscription"
                ]
            )
            throw NSError(
                domain: "GeminiAudioTranscription", 
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Gemini API not configured. Please set up Gemini in AI Provider settings."]
            )
        }
        
        // Get AI service instance for API key and model
        let aiService = AIService()
        let apiKey = aiService.apiKey
        let model = aiService.currentModel
        
        loggingService.debug(
            "Gemini API configuration validated",
            category: .transcription,
            context: [
                "request_id": requestId,
                "model": model,
                "source": "GeminiAudioTranscription"
            ]
        )
        
        // Validate file size (20MB limit)
        let fileSize = try getFileSize(audioURL)
        let maxSize: Int64 = 20 * 1024 * 1024 // 20MB
        guard fileSize <= maxSize else {
            loggingService.error(
                "Gemini transcription failed: Audio file too large",
                category: .transcription,
                context: [
                    "request_id": requestId,
                    "file_name": audioFileName,
                    "file_size": formatFileSize(fileSize),
                    "max_size": "20MB",
                    "source": "GeminiAudioTranscription"
                ]
            )
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
        
        loggingService.debug(
            "Audio file processed for Gemini API",
            category: .transcription,
            context: [
                "request_id": requestId,
                "file_size": formatFileSize(fileSize),
                "mime_type": mimeType,
                "base64_length": "\(base64Audio.count)",
                "source": "GeminiAudioTranscription"
            ]
        )
        
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
            loggingService.error(
                "Gemini transcription failed: Invalid request URL",
                category: .network,
                context: [
                    "request_id": requestId,
                    "model": model,
                    "base_url": baseURL,
                    "source": "GeminiAudioTranscription"
                ]
            )
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
            loggingService.error(
                "Gemini transcription failed: Request encoding error",
                category: .network,
                context: [
                    "request_id": requestId,
                    "error_domain": (error as NSError).domain,
                    "error_code": "\((error as NSError).code)",
                    "source": "GeminiAudioTranscription"
                ],
                error: error
            )
            throw NSError(
                domain: "GeminiAudioTranscription",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode request: \(error.localizedDescription)"]
            )
        }

        loggingService.debug(
            "Sending transcription request to Gemini API",
            category: .network,
            context: [
                "request_id": requestId,
                "url": fullURL,
                "timeout": "60s",
                "source": "GeminiAudioTranscription"
            ]
        )

        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            loggingService.error(
                "Gemini transcription failed: Network error",
                category: .network,
                context: [
                    "request_id": requestId,
                    "source": "GeminiAudioTranscription"
                ]
            )
            throw NSError(
                domain: "GeminiAudioTranscription",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Network error"]
            )
        }

        loggingService.debug(
            "Received Gemini API response",
            category: .network,
            context: [
                "request_id": requestId,
                "status_code": "\(httpResponse.statusCode)",
                "response_size": "\(data.count) bytes",
                "source": "GeminiAudioTranscription"
            ]
        )
        
        // Handle response
        switch httpResponse.statusCode {
        case 200:
            return try await parseTranscriptionResponse(data, requestId: requestId, audioFileName: audioFileName, startTime: startTime)
            
        case 400:
            let errorMessage = try parseErrorResponse(data) ?? "Bad request - check audio format and size"
            loggingService.error(
                "Gemini API error: Bad request",
                category: .network,
                context: [
                    "request_id": requestId,
                    "status_code": "400",
                    "error_message": errorMessage,
                    "source": "GeminiAudioTranscription"
                ]
            )
            throw NSError(
                domain: "GeminiAudioTranscription",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            )
            
        case 401:
            loggingService.error(
                "Gemini API error: Unauthorized",
                category: .network,
                context: [
                    "request_id": requestId,
                    "status_code": "401",
                    "source": "GeminiAudioTranscription"
                ]
            )
            throw NSError(
                domain: "GeminiAudioTranscription",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: "Invalid API key"]
            )
            
        case 403:
            loggingService.error(
                "Gemini API error: Forbidden",
                category: .network,
                context: [
                    "request_id": requestId,
                    "status_code": "403",
                    "source": "GeminiAudioTranscription"
                ]
            )
            throw NSError(
                domain: "GeminiAudioTranscription",
                code: 8,
                userInfo: [NSLocalizedDescriptionKey: "API access forbidden - check permissions"]
            )
            
        case 429:
            loggingService.error(
                "Gemini API error: Rate limited",
                category: .network,
                context: [
                    "request_id": requestId,
                    "status_code": "429",
                    "source": "GeminiAudioTranscription"
                ]
            )
            throw NSError(
                domain: "GeminiAudioTranscription",
                code: 9,
                userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded - please try again later"]
            )
            
        default:
            let errorMessage = try parseErrorResponse(data) ?? "Unknown error"
            loggingService.error(
                "Gemini API error: Unknown status code",
                category: .network,
                context: [
                    "request_id": requestId,
                    "status_code": "\(httpResponse.statusCode)",
                    "error_message": errorMessage,
                    "source": "GeminiAudioTranscription"
                ]
            )
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
    
    private func parseTranscriptionResponse(_ data: Data, requestId: String, audioFileName: String, startTime: Date) async throws -> String {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let text = firstPart["text"] as? String {
                
                let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let processingTime = Date().timeIntervalSince(startTime)
                
                loggingService.info(
                    "Gemini transcription completed successfully",
                    category: .transcription,
                    context: [
                        "request_id": requestId,
                        "file_name": audioFileName,
                        "text_length": "\(cleanedText.count)",
                        "processing_time": String(format: "%.2f", processingTime),
                        "source": "GeminiAudioTranscription"
                    ]
                )
                return cleanedText
            } else {
                loggingService.warning(
                    "Gemini returned empty or invalid response",
                    category: .transcription,
                    context: [
                        "request_id": requestId,
                        "file_name": audioFileName,
                        "response_size": "\(data.count) bytes",
                        "source": "GeminiAudioTranscription"
                    ]
                )
                return ""
            }
        } catch {
            loggingService.error(
                "Failed to parse Gemini response",
                category: .transcription,
                context: [
                    "request_id": requestId,
                    "file_name": audioFileName,
                    "response_size": "\(data.count) bytes",
                    "error_domain": (error as NSError).domain,
                    "error_code": "\((error as NSError).code)",
                    "source": "GeminiAudioTranscription"
                ],
                error: error
            )
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
