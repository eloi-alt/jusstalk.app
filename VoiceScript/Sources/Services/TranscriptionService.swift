import Foundation

enum TranscriptionError: Error {
    case invalidURL
    case networkError
    case invalidResponse
    case apiError(String)
}

class TranscriptionService {
    func transcribe(audioURL: URL) async throws -> String {
        guard let url = URL(string: Config.voxtralAPIEndpoint) else {
            throw TranscriptionError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Config.apiKey)", forHTTPHeaderField: "Authorization")

        var body = Data()
        let audioData = try Data(contentsOf: audioURL)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("voxtral-mini-transcribe-2507\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        for attempt in 0..<3 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw TranscriptionError.invalidResponse
                }

                if httpResponse.statusCode == 200 {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let text = json?["text"] as? String {
                        return text
                    } else if let transcription = json?["transcription"] as? String {
                        return transcription
                    }
                }

                let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw TranscriptionError.apiError(errorMsg)
            } catch {
                if attempt < 2 {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
                } else {
                    throw error
                }
            }
        }

        throw TranscriptionError.networkError
    }
}
