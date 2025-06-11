import Foundation
import os

/// Service responsible for handling Gemini Files API and streaming transcription
class GeminiStreamingService {
    private let logger = Logger(
        subsystem: "com.prakashjoshipax.voiceink", category: "GeminiStreaming")
    private let loggingService = LoggingService.shared
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"

    // MARK: - File Upload

    /// Uploads an audio file to Gemini Files API using simplified binary upload
    /// - Parameters:
    ///   - url: URL of the audio file to upload
    ///   - mimeType: MIME type of the audio file
    ///   - progressCallback: Callback to report upload progress (0.0 to 1.0)
    /// - Returns: UploadedFile containing the file URI and metadata
    func uploadAudioFile(
        url: URL,
        mimeType: String,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> UploadedFile {
        let sessionId = UUID().uuidString
        let fileName = url.lastPathComponent
        let fileSize = try getFileSize(url)

        loggingService.info(
            "Starting Gemini file upload (simplified binary)",
            category: .network,
            context: [
                "session_id": sessionId,
                "file_name": fileName,
                "file_size": "\(fileSize) bytes",
            ]
        )

        // Get API key
        guard let apiKey = getAPIKey() else {
            throw StreamingError.apiKeyInvalid
        }

        // Load audio data
        let audioData = try Data(contentsOf: url)

        loggingService.debug(
            "Preparing binary upload",
            category: .network,
            context: [
                "session_id": sessionId,
                "mime_type": mimeType,
                "data_size": "\(audioData.count) bytes",
            ]
        )

        // Create upload request - Gemini Files API expects different parameters
        let uploadURL = URL(
            string: "https://generativelanguage.googleapis.com/upload/v1beta/files?uploadType=media"
        )!

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-goog-api-key")
        request.timeoutInterval = StreamingConfiguration.uploadTimeout
        request.httpBody = audioData

        // Log request details
        loggingService.debug(
            "Binary upload request details",
            category: .network,
            context: [
                "session_id": sessionId,
                "url": uploadURL.absoluteString,
                "content_type": mimeType,
                "body_size": "\(audioData.count) bytes",
            ]
        )

        // Perform upload with progress tracking
        let uploadedFile = try await performBinaryUploadWithProgress(
            request: request,
            progressCallback: progressCallback,
            sessionId: sessionId
        )

        loggingService.info(
            "Gemini file upload completed",
            category: .network,
            context: [
                "session_id": sessionId,
                "file_uri": uploadedFile.uri,
                "upload_size": uploadedFile.sizeBytes,
            ]
        )

        return uploadedFile
    }

    // MARK: - Streaming Transcription

    /// Creates a streaming transcription session with Gemini
    /// - Parameters:
    ///   - fileURI: URI of the uploaded file (from uploadAudioFile)
    ///   - prompt: Transcription prompt/instructions
    /// - Returns: AsyncThrowingStream of transcription chunks
    func streamTranscription(
        fileURI: String,
        prompt: String
    ) -> AsyncThrowingStream<TranscriptionChunk, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                let sessionId = UUID().uuidString

                loggingService.info(
                    "Starting Gemini streaming transcription",
                    category: .transcription,
                    context: [
                        "session_id": sessionId,
                        "file_uri": fileURI,
                    ]
                )

                do {
                    // Create streaming request
                    let request = try createStreamingRequest(fileURI: fileURI, prompt: prompt)

                    // Start streaming
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw StreamingError.streamingFailed("Invalid response")
                    }

                    guard httpResponse.statusCode == 200 else {
                        let errorMessage = "HTTP \(httpResponse.statusCode)"
                        throw StreamingError.streamingFailed(errorMessage)
                    }

                    // Parse streaming response
                    try await parseStreamingResponse(
                        asyncBytes: asyncBytes, continuation: continuation)

                    loggingService.info(
                        "Gemini streaming transcription completed",
                        category: .transcription,
                        context: ["session_id": sessionId]
                    )

                    continuation.finish()

                } catch {
                    loggingService.error(
                        "Gemini streaming transcription failed",
                        category: .transcription,
                        context: [
                            "session_id": sessionId,
                            "error": error.localizedDescription,
                        ],
                        error: error
                    )
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - File Cleanup

    /// Deletes a file from Gemini Files API
    /// - Parameter uri: URI of the file to delete
    func deleteFile(uri: String) async throws {
        let sessionId = UUID().uuidString
        let fileId = extractFileId(from: uri)

        loggingService.info(
            "Starting Gemini file deletion",
            category: .network,
            context: [
                "session_id": sessionId,
                "file_uri": uri,
                "extracted_file_id": fileId,
            ]
        )

        guard let apiKey = getAPIKey() else {
            loggingService.error(
                "File deletion failed: No API key",
                category: .network,
                context: ["session_id": sessionId, "file_uri": uri]
            )
            throw StreamingError.apiKeyInvalid
        }

        let deleteURL = URL(string: "\(baseURL)/files/\(fileId)")!
        var request = URLRequest(url: deleteURL)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "X-goog-api-key")
        request.timeoutInterval = StreamingConfiguration.cleanupTimeout

        loggingService.debug(
            "Delete request details",
            category: .network,
            context: [
                "session_id": sessionId,
                "delete_url": deleteURL.absoluteString,
                "method": "DELETE",
                "timeout": "\(request.timeoutInterval)s",
            ]
        )

        // Log all headers (with API key redaction) in a single log entry
        let headers = (request.allHTTPHeaderFields ?? [:]).map { key, value in
            key.lowercased().contains("key") ? "\(key): [REDACTED]" : "\(key): \(value)"
        }.joined(separator: "\n")
        loggingService.debug(
            "Delete request headers",
            category: .network,
            context: [
                "session_id": sessionId,
                "headers": headers,
            ]
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            loggingService.error(
                "File deletion failed: Invalid response type",
                category: .network,
                context: [
                    "session_id": sessionId,
                    "response_type": String(describing: type(of: response)),
                ]
            )
            throw StreamingError.cleanupFailed("Invalid response")
        }

        let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"

        loggingService.debug(
            "Delete response details",
            category: .network,
            context: [
                "session_id": sessionId,
                "status_code": "\(httpResponse.statusCode)",
                "response_size": "\(data.count) bytes",
                "response_body": responseString,
            ]
        )
        // Log all response headers together in a single log entry
        let responseHeaders = httpResponse.allHeaderFields.map { key, value in
            "\(key): \(value)"
        }.joined(separator: "\n")
        loggingService.debug(
            "Delete response headers",
            category: .network,
            context: [
                "session_id": sessionId,
                "headers": responseHeaders,
            ]
        )

        guard httpResponse.statusCode == 200 else {
            loggingService.error(
                "Gemini file deletion failed",
                category: .network,
                context: [
                    "session_id": sessionId,
                    "file_uri": uri,
                    "file_id": fileId,
                    "status_code": "\(httpResponse.statusCode)",
                    "response_body": responseString,
                ]
            )
            throw StreamingError.cleanupFailed("HTTP \(httpResponse.statusCode)")
        }

        loggingService.info(
            "Gemini file deletion completed successfully",
            category: .network,
            context: [
                "session_id": sessionId,
                "file_uri": uri,
                "file_id": fileId,
            ]
        )
    }

    // MARK: - Private Implementation

    /// Gets the Gemini API key from AIService
    private func getAPIKey() -> String? {
        let aiService = AIService()
        guard aiService.selectedProvider == .gemini && aiService.isAPIKeyValid else {
            return nil
        }
        return aiService.apiKey
    }

    /// Determines MIME type based on file extension
    private func getMimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case "mp3":
            return "audio/mpeg"
        case "m4a":
            return "audio/mp4"
        case "wav":
            return "audio/wav"
        case "aiff":
            return "audio/aiff"
        case "aac":
            return "audio/aac"
        case "flac":
            return "audio/flac"
        default:
            return "audio/mpeg"
        }
    }

    /// Creates multipart form data for file upload
    private func createMultipartBody(
        boundary: String,
        fileName: String,
        mimeType: String,
        audioData: Data
    ) -> Data {
        var body = Data()

        // Metadata part (JSON)
        let metadata = [
            "file": [
                "display_name": fileName
            ]
        ]

        let metadataJSON = try! JSONSerialization.data(withJSONObject: metadata)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"metadata\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(metadataJSON)
        body.append("\r\n".data(using: .utf8)!)

        // Audio data part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(
                using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return body
    }

    /// Performs binary upload with progress tracking (simplified approach)
    private func performBinaryUploadWithProgress(
        request: URLRequest,
        progressCallback: @escaping (Double) -> Void,
        sessionId: String
    ) async throws -> UploadedFile {
        // Log request headers
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                if key.lowercased() == "authorization" {
                    loggingService.debug(
                        "Request header",
                        category: .network,
                        context: [
                            "session_id": sessionId,
                            "header": key,
                            "value": "Bearer [REDACTED]",
                        ]
                    )
                } else {
                    loggingService.debug(
                        "Request header",
                        category: .network,
                        context: [
                            "session_id": sessionId,
                            "header": key,
                            "value": value,
                        ]
                    )
                }
            }
        }

        // Simulate progress for binary upload with proper timing
        let startTime = Date()
        let progressTimer = Timer.scheduledTimer(
            withTimeInterval: 0.1, repeats: true
        ) { _ in
            let elapsed = Date().timeIntervalSince(startTime)
            let estimatedDuration = Double(request.httpBody?.count ?? 0) / (512 * 1024)  // More realistic upload speed estimate
            let progress = min(elapsed / max(estimatedDuration, 1.0), 0.95)

            // Ensure main thread dispatch for UI updates
            DispatchQueue.main.async {
                progressCallback(progress)
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        progressTimer.invalidate()

        loggingService.debug(
            "Binary upload completed",
            category: .network,
            context: [
                "session_id": sessionId,
                "response_size": "\(data.count) bytes",
            ]
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            loggingService.error(
                "Invalid HTTP response type",
                category: .network,
                context: [
                    "session_id": sessionId,
                    "response_type": String(describing: type(of: response)),
                ]
            )
            throw StreamingError.uploadFailed("Invalid response")
        }

        loggingService.debug(
            "HTTP response details",
            category: .network,
            context: [
                "session_id": sessionId,
                "status_code": "\(httpResponse.statusCode)",
                "status_description": HTTPURLResponse.localizedString(
                    forStatusCode: httpResponse.statusCode),
                "headers": httpResponse.allHeaderFields.map { "\($0.key): \($0.value)" }.joined(
                    separator: "\n"),
            ]
        )

        // Log response body
        let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
        loggingService.debug(
            "Response body",
            category: .network,
            context: [
                "session_id": sessionId,
                "response_body": responseString,
            ]
        )

        guard httpResponse.statusCode == 200 else {
            let errorMessage = try parseErrorResponse(data) ?? "HTTP \(httpResponse.statusCode)"
            loggingService.error(
                "Binary upload failed with HTTP error",
                category: .network,
                context: [
                    "session_id": sessionId,
                    "status_code": "\(httpResponse.statusCode)",
                    "error_message": errorMessage,
                    "response_body": responseString,
                ]
            )
            throw StreamingError.uploadFailed(errorMessage)
        }

        // Parse upload response - expect direct file object for binary upload
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            loggingService.error(
                "Failed to parse JSON response",
                category: .network,
                context: [
                    "session_id": sessionId,
                    "response_body": responseString,
                ]
            )
            throw StreamingError.uploadFailed("Invalid JSON response")
        }

        loggingService.debug(
            "Parsed JSON response",
            category: .network,
            context: [
                "session_id": sessionId,
                "json_keys": Array(json.keys).joined(separator: ", "),
            ]
        )

        // For binary upload, the response might be the file object directly
        let fileObject = json["file"] as? [String: Any] ?? json

        guard let name = fileObject["name"] as? String,
            let uri = fileObject["uri"] as? String,
            let mimeType = fileObject["mimeType"] as? String,
            let sizeBytes = fileObject["sizeBytes"] as? String
        else {
            loggingService.error(
                "Missing required fields in response",
                category: .network,
                context: [
                    "session_id": sessionId,
                    "available_keys": Array(fileObject.keys).joined(separator: ", "),
                    "name": fileObject["name"] as? String ?? "missing",
                    "uri": fileObject["uri"] as? String ?? "missing",
                    "mimeType": fileObject["mimeType"] as? String ?? "missing",
                    "sizeBytes": fileObject["sizeBytes"] as? String ?? "missing",
                ]
            )
            throw StreamingError.uploadFailed("Invalid response format - missing required fields")
        }

        progressCallback(1.0)

        loggingService.info(
            "Binary upload successful",
            category: .network,
            context: [
                "session_id": sessionId,
                "file_name": name,
                "file_uri": uri,
                "file_size": sizeBytes,
            ]
        )

        return UploadedFile(
            name: name,
            uri: uri,
            mimeType: mimeType,
            sizeBytes: sizeBytes,
            uploadTimestamp: Date()
        )
    }

    /// Performs upload with progress tracking (legacy multipart method)
    private func performUploadWithProgress(
        request: URLRequest,
        body: Data,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> UploadedFile {
        let sessionId = UUID().uuidString

        loggingService.debug(
            "Starting upload request",
            category: .network,
            context: [
                "session_id": sessionId,
                "url": request.url?.absoluteString ?? "unknown",
                "method": request.httpMethod ?? "unknown",
                "body_size": "\(body.count) bytes",
                "content_type": request.value(forHTTPHeaderField: "Content-Type") ?? "unknown",
            ]
        )

        // Log request headers
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                if key.lowercased() == "authorization" {
                    loggingService.debug(
                        "Request header",
                        category: .network,
                        context: [
                            "session_id": sessionId,
                            "header": key,
                            "value": "Bearer [REDACTED]",
                        ]
                    )
                } else {
                    loggingService.debug(
                        "Request header",
                        category: .network,
                        context: [
                            "session_id": sessionId,
                            "header": key,
                            "value": value,
                        ]
                    )
                }
            }
        }

        // Log first 500 characters of body for debugging
        let bodyPreview = String(data: body.prefix(500), encoding: .utf8) ?? "Unable to decode body"
        loggingService.debug(
            "Request body preview",
            category: .network,
            context: [
                "session_id": sessionId,
                "body_preview": bodyPreview,
            ]
        )

        // Create upload task with progress tracking
        var uploadRequest = request
        uploadRequest.httpBody = body

        // For now, we'll simulate progress since URLSession doesn't provide
        // built-in upload progress for data tasks. In a production app,
        // you might use URLSessionUploadTask with a delegate.
        let progressTimer = Timer.scheduledTimer(
            withTimeInterval: StreamingConfiguration.progressUpdateInterval, repeats: true
        ) { timer in
            // Simulate upload progress
            let elapsed = Date().timeIntervalSince(timer.fireDate)
            let estimatedDuration = Double(body.count) / (1024 * 1024)  // Rough estimate based on size
            let progress = min(elapsed / max(estimatedDuration, 1.0), 0.95)
            progressCallback(progress)
        }

        let (data, response) = try await URLSession.shared.data(for: uploadRequest)
        progressTimer.invalidate()

        loggingService.debug(
            "Upload request completed",
            category: .network,
            context: [
                "session_id": sessionId,
                "response_size": "\(data.count) bytes",
            ]
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            loggingService.error(
                "Invalid HTTP response type",
                category: .network,
                context: [
                    "session_id": sessionId,
                    "response_type": String(describing: type(of: response)),
                ]
            )
            throw StreamingError.uploadFailed("Invalid response")
        }

        loggingService.debug(
            "HTTP response details",
            category: .network,
            context: [
                "session_id": sessionId,
                "status_code": "\(httpResponse.statusCode)",
                "status_description": HTTPURLResponse.localizedString(
                    forStatusCode: httpResponse.statusCode),
            ]
        )

        // Log response headers
        for (key, value) in httpResponse.allHeaderFields {
            loggingService.debug(
                "Response header",
                category: .network,
                context: [
                    "session_id": sessionId,
                    "header": String(describing: key),
                    "value": String(describing: value),
                ]
            )
        }

        // Log response body
        let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
        loggingService.debug(
            "Response body",
            category: .network,
            context: [
                "session_id": sessionId,
                "response_body": responseString,
            ]
        )

        guard httpResponse.statusCode == 200 else {
            let errorMessage = try parseErrorResponse(data) ?? "HTTP \(httpResponse.statusCode)"
            loggingService.error(
                "Upload failed with HTTP error",
                category: .network,
                context: [
                    "session_id": sessionId,
                    "status_code": "\(httpResponse.statusCode)",
                    "error_message": errorMessage,
                    "response_body": responseString,
                ]
            )
            throw StreamingError.uploadFailed(errorMessage)
        }

        // Parse upload response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            loggingService.error(
                "Failed to parse JSON response",
                category: .network,
                context: [
                    "session_id": sessionId,
                    "response_body": responseString,
                ]
            )
            throw StreamingError.uploadFailed("Invalid JSON response")
        }

        loggingService.debug(
            "Parsed JSON response",
            category: .network,
            context: [
                "session_id": sessionId,
                "json_keys": Array(json.keys).joined(separator: ", "),
            ]
        )

        guard let file = json["file"] as? [String: Any] else {
            loggingService.error(
                "Missing 'file' key in response",
                category: .network,
                context: [
                    "session_id": sessionId,
                    "available_keys": Array(json.keys).joined(separator: ", "),
                ]
            )
            throw StreamingError.uploadFailed("Missing 'file' key in response")
        }

        guard let name = file["name"] as? String,
            let uri = file["uri"] as? String,
            let mimeType = file["mimeType"] as? String,
            let sizeBytes = file["sizeBytes"] as? String
        else {
            loggingService.error(
                "Missing required fields in file object",
                category: .network,
                context: [
                    "session_id": sessionId,
                    "file_keys": Array(file.keys).joined(separator: ", "),
                    "name": file["name"] as? String ?? "missing",
                    "uri": file["uri"] as? String ?? "missing",
                    "mimeType": file["mimeType"] as? String ?? "missing",
                    "sizeBytes": file["sizeBytes"] as? String ?? "missing",
                ]
            )
            throw StreamingError.uploadFailed("Invalid response format - missing required fields")
        }

        progressCallback(1.0)

        loggingService.info(
            "Upload successful",
            category: .network,
            context: [
                "session_id": sessionId,
                "file_name": name,
                "file_uri": uri,
                "file_size": sizeBytes,
            ]
        )

        return UploadedFile(
            name: name,
            uri: uri,
            mimeType: mimeType,
            sizeBytes: sizeBytes,
            uploadTimestamp: Date()
        )
    }

    /// Creates a streaming request for transcription
    private func createStreamingRequest(fileURI: String, prompt: String) throws -> URLRequest {
        let sessionId = UUID().uuidString

        guard let apiKey = getAPIKey() else {
            throw StreamingError.apiKeyInvalid
        }

        // Get the selected model from AIService
        let aiService = AIService()
        let model = aiService.currentModel
        let streamURL = URL(string: "\(baseURL)/models/\(model):streamGenerateContent?alt=sse")!

        loggingService.info(
            "Creating streaming transcription request",
            category: .transcription,
            context: [
                "session_id": sessionId,
                "model": model,
                "url": streamURL.absoluteString,
                "file_uri": fileURI,
                "prompt": prompt,
            ]
        )

        var request = URLRequest(url: streamURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-goog-api-key")
        request.timeoutInterval = StreamingConfiguration.streamingTimeout

        let mimeType = getMimeType(for: URL(string: fileURI) ?? URL(fileURLWithPath: fileURI))
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        ["fileData": ["fileUri": fileURI, "mimeType": mimeType]],
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 65500,
            ],
        ]

        let requestBodyData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = requestBodyData

        // Log the request body
        let requestBodyString =
            String(data: requestBodyData, encoding: .utf8) ?? "Unable to decode request body"
        loggingService.debug(
            "Streaming request body",
            category: .transcription,
            context: [
                "session_id": sessionId,
                "request_body": requestBodyString,
                "body_size": "\(requestBodyData.count) bytes",
            ]
        )

        // Log request headers
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                if key.lowercased().contains("key") {
                    loggingService.debug(
                        "Streaming request header",
                        category: .transcription,
                        context: [
                            "session_id": sessionId,
                            "header": key,
                            "value": "[REDACTED]",
                        ]
                    )
                } else {
                    loggingService.debug(
                        "Streaming request header",
                        category: .transcription,
                        context: [
                            "session_id": sessionId,
                            "header": key,
                            "value": value,
                        ]
                    )
                }
            }
        }

        return request
    }

    /// Parses streaming response from Gemini using proper SSE format
    private func parseStreamingResponse(
        asyncBytes: URLSession.AsyncBytes,
        continuation: AsyncThrowingStream<TranscriptionChunk, Error>.Continuation
    ) async throws {
        let sessionId = UUID().uuidString
        var chunkIndex = 0
        var buffer = Data()
        var totalBytesReceived = 0
        var linesProcessed = 0
        var chunksYielded = 0

        // SSE line delimiter - Gemini uses standard \n
        let lineDelimiter = "\n".data(using: .utf8)!

        loggingService.info(
            "🚀 Starting Gemini SSE parser",
            category: .transcription,
            context: ["session_id": sessionId]
        )

        defer {
            loggingService.info(
                "✅ SSE parser completed",
                category: .transcription,
                context: [
                    "session_id": sessionId,
                    "total_bytes": "\(totalBytesReceived)",
                    "lines_processed": "\(linesProcessed)",
                    "chunks_yielded": "\(chunksYielded)",
                ]
            )
        }

        do {
            for try await byte in asyncBytes {
                totalBytesReceived += 1
                buffer.append(byte)

                // Prevent memory bloat
                if buffer.count > 2_000_000 {  // 2MB limit
                    throw StreamingError.streamingFailed("Buffer exceeded 2MB limit")
                }

                // Log progress every 10KB
                if totalBytesReceived % 10240 == 0 {
                    loggingService.debug(
                        "📊 Streaming progress",
                        category: .transcription,
                        context: [
                            "session_id": sessionId,
                            "bytes_received": "\(totalBytesReceived)",
                            "buffer_size": "\(buffer.count)",
                            "lines_processed": "\(linesProcessed)",
                        ]
                    )
                }

                // Process complete lines using standard \n delimiter
                while let newlineRange = buffer.range(of: lineDelimiter) {
                    let lineData = buffer.subdata(in: 0..<newlineRange.lowerBound)

                    // Remove processed line from buffer
                    buffer.removeSubrange(0..<newlineRange.upperBound)

                    linesProcessed += 1

                    // Convert to string for processing
                    guard let line = String(data: lineData, encoding: .utf8) else {
                        loggingService.warning(
                            "⚠️ Failed to decode line as UTF-8",
                            category: .transcription,
                            context: ["session_id": sessionId, "line_number": "\(linesProcessed)"]
                        )
                        continue
                    }

                    // Log every line for debugging
                    loggingService.debug(
                        "📝 Processing line",
                        category: .transcription,
                        context: [
                            "session_id": sessionId,
                            "line_number": "\(linesProcessed)",
                            "line_content": line.isEmpty ? "[EMPTY]" : "'\(line)'",
                            "starts_with_data": "\(line.hasPrefix("data: "))",
                        ]
                    )

                    // Process the line
                    do {
                        if let chunk = try parseSSELine(
                            line,
                            chunkIndex: chunkIndex,
                            sessionId: sessionId,
                            lineNumber: linesProcessed
                        ) {
                            continuation.yield(chunk)
                            chunkIndex += 1
                            chunksYielded += 1

                            loggingService.debug(
                                "🎯 Yielded transcription chunk",
                                category: .transcription,
                                context: [
                                    "session_id": sessionId,
                                    "chunk_index": "\(chunk.chunkIndex)",
                                    "text_length": "\(chunk.text.count)",
                                    "is_complete": "\(chunk.isComplete)",
                                    "text_preview": String(chunk.text.prefix(100)),
                                ]
                            )

                            // Check for completion
                            if chunk.isComplete {
                                loggingService.info(
                                    "🏁 Transcription completed",
                                    category: .transcription,
                                    context: [
                                        "session_id": sessionId,
                                        "total_chunks": "\(chunksYielded)",
                                    ]
                                )
                                continuation.finish()
                                return
                            }
                        }

                    } catch {
                        loggingService.error(
                            "❌ Error processing SSE line",
                            category: .transcription,
                            context: [
                                "session_id": sessionId,
                                "line_number": "\(linesProcessed)",
                                "line_content": line,
                            ],
                            error: error
                        )
                        // Continue processing other lines
                    }
                }
            }

            // Process any remaining data in buffer
            if !buffer.isEmpty {
                loggingService.debug(
                    "📋 Processing remaining buffer",
                    category: .transcription,
                    context: [
                        "session_id": sessionId,
                        "remaining_bytes": "\(buffer.count)",
                    ]
                )
            }

        } catch {
            loggingService.error(
                "❌ SSE parser error",
                category: .transcription,
                context: ["session_id": sessionId],
                error: error
            )
            continuation.finish(throwing: error)
            return
        }

        // Finish the stream if we reach here without completion
        continuation.finish()
    }

    /// Parse a single SSE line based on actual Gemini format
    private func parseSSELine(
        _ line: String,
        chunkIndex: Int,
        sessionId: String,
        lineNumber: Int
    ) throws -> TranscriptionChunk? {

        // Skip empty lines
        if line.isEmpty {
            return nil
        }

        // Only process lines that start with "data: "
        guard line.hasPrefix("data: ") else {
            loggingService.debug(
                "⏭️ Skipping non-data line",
                category: .transcription,
                context: [
                    "session_id": sessionId,
                    "line_number": "\(lineNumber)",
                    "line_content": "'\(line)'",
                ]
            )
            return nil
        }

        // Extract JSON after "data: "
        let jsonString = String(line.dropFirst(6))  // Remove "data: " prefix

        // Skip empty JSON or termination markers
        if jsonString.isEmpty
            || jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]"
        {
            return nil
        }

        // Parse JSON
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw StreamingError.streamingFailed("Cannot convert to UTF-8: \(jsonString)")
        }

        do {
            let response = try JSONDecoder().decode(GeminiSSEResponse.self, from: jsonData)

            loggingService.debug(
                "✅ Successfully parsed Gemini SSE response",
                category: .transcription,
                context: [
                    "session_id": sessionId,
                    "line_number": "\(lineNumber)",
                    "candidates_count": "\(response.candidates.count)",
                    "model_version": response.modelVersion ?? "unknown",
                    "response_id": response.responseId ?? "unknown",
                ]
            )

            // Extract text from first candidate
            guard let firstCandidate = response.candidates.first else {
                loggingService.warning(
                    "⚠️ No candidates in response",
                    category: .transcription,
                    context: ["session_id": sessionId, "line_number": "\(lineNumber)"]
                )
                return nil
            }

            guard let firstPart = firstCandidate.content.parts.first else {
                loggingService.warning(
                    "⚠️ No parts in candidate content",
                    category: .transcription,
                    context: ["session_id": sessionId, "line_number": "\(lineNumber)"]
                )
                return nil
            }

            let text = firstPart.text
            let isComplete = firstCandidate.finishReason == "STOP"

            // Create transcription chunk
            let chunk = TranscriptionChunk(
                text: text,
                isComplete: isComplete,
                timestamp: extractTimestamp(from: text),
                confidence: nil,
                chunkIndex: chunkIndex,
                usageMetadata: response.usageMetadata
            )

            return chunk

        } catch {
            throw StreamingError.streamingFailed("Failed to decode JSON: \(error)")
        }
    }

    /// Extract timestamp from text if present (for audio transcription)
    private func extractTimestamp(from text: String) -> String? {
        // Look for patterns like [00:15], [MM:SS], [HH:MM:SS]
        let timestampPattern = #"\[(\d{1,2}:\d{2}(?::\d{2})?)\]"#

        if let regex = try? NSRegularExpression(pattern: timestampPattern),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range(at: 1), in: text)
        {
            return String(text[range])
        }

        return nil
    }

    /// Parses error response from API
    private func parseErrorResponse(_ data: Data) throws -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = json["error"] as? [String: Any],
            let message = error["message"] as? String
        else {
            return nil
        }
        return message
    }

    /// Extracts file ID from URI
    private func extractFileId(from uri: String) -> String {
        // Handle full URI: "https://generativelanguage.googleapis.com/v1beta/files/abc123"
        // Extract just the file ID: "abc123"
        if let lastComponent = uri.components(separatedBy: "/").last, !lastComponent.isEmpty {
            return lastComponent
        }

        // Fallback for relative paths like "files/abc123"
        return uri.replacingOccurrences(of: "files/", with: "")
    }

    /// Gets file size in bytes
    private func getFileSize(_ url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
}

// MARK: - Testing and Validation

extension GeminiStreamingService {
    /// Test parser with sample SSE data from actual Gemini response
    func testSSEParser() {
        let sampleLines = [
            #"data: {"candidates": [{"content": {"parts": [{"text": "C"}],"role": "model"}}],"usageMetadata": {"promptTokenCount": 7,"totalTokenCount": 7,"promptTokensDetails": [{"modality": "TEXT","tokenCount": 7}]},"modelVersion": "gemini-2.5-pro","responseId": "test123"}"#,
            #"data: {"candidates": [{"content": {"parts": [{"text": "lementine, a ginger tabby"}],"role": "model"}}],"usageMetadata": {"promptTokenCount": 7,"totalTokenCount": 15},"modelVersion": "gemini-2.5-pro","responseId": "test124"}"#,
            #"data: {"candidates": [{"content": {"parts": [{"text": " cat who considered himself"}],"role": "model"},"finishReason": "STOP"}],"usageMetadata": {"promptTokenCount": 7,"totalTokenCount": 25},"modelVersion": "gemini-2.5-pro","responseId": "test125"}"#,
        ]

        loggingService.info(
            "🧪 Testing SSE parser with sample data",
            category: .transcription,
            context: ["sample_lines_count": "\(sampleLines.count)"]
        )

        for (index, line) in sampleLines.enumerated() {
            do {
                if let chunk = try parseSSELine(
                    line,
                    chunkIndex: index,
                    sessionId: "test-session",
                    lineNumber: index + 1
                ) {
                    loggingService.info(
                        "✅ Successfully parsed test line",
                        category: .transcription,
                        context: [
                            "line_index": "\(index)",
                            "text": chunk.text,
                            "is_complete": "\(chunk.isComplete)",
                            "usage_tokens": "\(chunk.usageMetadata?.totalTokenCount ?? 0)",
                        ]
                    )
                } else {
                    loggingService.warning(
                        "⚠️ Test line returned nil chunk",
                        category: .transcription,
                        context: ["line_index": "\(index)"]
                    )
                }
            } catch {
                loggingService.error(
                    "❌ Test line parsing failed",
                    category: .transcription,
                    context: ["line_index": "\(index)"],
                    error: error
                )
            }
        }
    }
}

// MARK: - Utility Extensions

extension GeminiStreamingService {
    /// Validates that the service is properly configured
    func validateConfiguration() throws {
        guard getAPIKey() != nil else {
            throw StreamingError.apiKeyInvalid
        }
    }

    /// Estimates upload time based on file size and connection speed
    func estimateUploadTime(fileSize: Int64) -> TimeInterval {
        // Assume average upload speed of 1MB/s (conservative estimate)
        let uploadSpeedBytesPerSecond: Double = 1024 * 1024
        return Double(fileSize) / uploadSpeedBytesPerSecond
    }

    /// Checks if a file size is within Gemini's limits
    func isFileSizeSupported(_ fileSize: Int64) -> Bool {
        return fileSize <= StreamingConfiguration.maxFileSize
    }
}
