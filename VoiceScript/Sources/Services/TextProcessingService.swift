import Foundation

class TextProcessingService {
    private let apiEndpoint = "https://api.deepseek.com/v1/chat/completions"
    private var apiKey: String { Config.deepseekKey }

    func formatAsMarkdown(text: String, metadata: [String: Any]) async throws -> String {
        let prompt = """
Transform the following transcription into a well-structured Markdown document.

Requirements:
- Add appropriate headings (# ## ###) based on topic changes
- Format lists with proper bullets or numbers when relevant
- Add **bold** for emphasis on key terms
- Use > blockquotes for important quotes if present
- Add horizontal rules (---) to separate major sections
- Keep the original meaning and ALL content intact
- Output ONLY the formatted markdown, no explanations or comments

Transcription:
\(text)
"""
        return try await processText(prompt: prompt)
    }

    func formatAsJSON(text: String, metadata: [String: Any]) async throws -> String {
        let dateFormatter = ISO8601DateFormatter()
        let date = metadata["date"] as? Date ?? Date()
        let duration = metadata["duration"] as? TimeInterval ?? 0

        let prompt = """
Transform the following transcription into a valid JSON structure.

Requirements:
- Create a JSON object with these exact fields:
  {
    "transcription": "<full text here>",
    "date": "\(dateFormatter.string(from: date))",
    "duration": \(duration),
    "summary": "<1-2 sentence summary>",
    "topics": ["topic1", "topic2", ...],
    "key_points": ["point1", "point2", ...]
  }
- Properly escape all special JSON characters (quotes, backslashes, newlines)
- topics array: 2-5 main topics discussed
- key_points array: 3-5 most important points
- Output ONLY valid JSON, no markdown code blocks, no explanations

Transcription:
\(text)
"""
        return try await processText(prompt: prompt)
    }

    func formatAsHTML(text: String, metadata: [String: Any]) async throws -> String {
        let prompt = """
Transform the following transcription into semantic HTML5 content.

Requirements:
- Use proper HTML5 semantic tags: <article>, <section>, <h2>, <h3>, <p>, <ul>, <ol>, <li>
- Add headings based on content structure
- Format lists as <ul> or <ol> where appropriate
- Properly escape HTML special characters: & → &amp;, < → &lt;, > → &gt;, " → &quot;, ' → &#39;
- Add <strong> for emphasis on key terms
- Keep clean structure, no inline styles
- Output ONLY the HTML body content (no <!DOCTYPE>, <html>, <head>, or <body> tags)
- No CSS, no JavaScript, no attributes except semantic ones

Transcription:
\(text)
"""
        return try await processText(prompt: prompt)
    }

    func formatAsCSV(text: String, metadata: [String: Any]) async throws -> String {
        let dateFormatter = ISO8601DateFormatter()
        let date = metadata["date"] as? Date ?? Date()
        let duration = metadata["duration"] as? TimeInterval ?? 0

        let prompt = """
Transform the following transcription into CSV format.

Requirements:
- First row MUST be: Date,Duration,Speaker,Content,Topic
- Analyze the transcription and detect:
  * Multiple speakers (if present): create separate rows per speaker
  * Topics/sections: identify and label them
  * If single speaker: create one data row with "Speaker 1"
- Properly escape CSV format:
  * Wrap fields containing commas in double quotes
  * Escape quotes by doubling them: " becomes ""
  * Format: "\(dateFormatter.string(from: date))",\(Int(duration)),"Speaker Name","Content text","Topic"
- Output ONLY the CSV data (header + data rows), no explanations

Transcription:
\(text)
"""
        return try await processText(prompt: prompt)
    }

    private func processText(prompt: String) async throws -> String {
        guard let url = URL(string: apiEndpoint) else {
            throw TextProcessingError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let requestBody: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a text formatting expert. Output only the requested format with no additional commentary, explanations, or markdown code blocks."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.3,
            "max_tokens": 4000
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TextProcessingError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("DeepSeek API Error: \(errorMessage)")
            throw TextProcessingError.apiError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw TextProcessingError.invalidResponse
        }

        var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanedContent.hasPrefix("```") {
            cleanedContent = cleanedContent
                .replacingOccurrences(of: "```json\n", with: "")
                .replacingOccurrences(of: "```html\n", with: "")
                .replacingOccurrences(of: "```markdown\n", with: "")
                .replacingOccurrences(of: "```csv\n", with: "")
                .replacingOccurrences(of: "```\n", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return cleanedContent
    }
}

enum TextProcessingError: Error {
    case invalidURL
    case apiError
    case invalidResponse

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid API endpoint URL"
        case .apiError:
            return "API request failed"
        case .invalidResponse:
            return "Invalid API response format"
        }
    }
}
