import Foundation
import PDFKit
import UIKit

class ExportService {
    func export(text: String, format: ExportFormat, metadata: [String: Any]) async throws -> URL {
        let filename = generateFilename(format: format)
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        switch format {
        case .txt: return try exportToTXT(text: text, url: fileURL)
        case .md: return try exportToMD(text: text, url: fileURL, metadata: metadata)
        case .json: return try exportToJSON(text: text, url: fileURL, metadata: metadata)
        case .pdf: return try exportToPDF(text: text, url: fileURL)
        case .docx: return try exportToRTF(text: text, url: fileURL)
        case .html: return try exportToHTML(text: text, url: fileURL)
        case .rtf: return try exportToRTF(text: text, url: fileURL)
        case .csv: return try exportToCSV(text: text, url: fileURL, metadata: metadata)
        }
    }

    private func generateFilename(format: ExportFormat) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let dateString = dateFormatter.string(from: Date())
        return "transcription_\(dateString).\(format.fileExtension)"
    }

    private func exportToTXT(text: String, url: URL) throws -> URL {
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func exportToMD(text: String, url: URL, metadata: [String: Any]) throws -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short

        let date = metadata["date"] as? Date ?? Date()
        var markdown = "# Transcription\n\n**Date:** \(dateFormatter.string(from: date))\n\n"

        if let duration = metadata["duration"] as? TimeInterval {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            markdown += "**Duration:** \(minutes)m \(seconds)s\n\n"
        }

        markdown += "---\n\n\(text)"
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func exportToJSON(text: String, url: URL, metadata: [String: Any]) throws -> URL {
        let dateFormatter = ISO8601DateFormatter()
        let date = metadata["date"] as? Date ?? Date()

        let jsonObject: [String: Any] = [
            "transcription": text,
            "date": dateFormatter.string(from: date),
            "duration": metadata["duration"] as? TimeInterval ?? 0,
            "format": "voxtral-mini-transcribe-2507"
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
        try jsonData.write(to: url)
        return url
    }

    private func exportToPDF(text: String, url: URL) throws -> URL {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            let textRect = CGRect(x: 50, y: 50, width: 512, height: 692)
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12)]
            text.draw(in: textRect, withAttributes: attributes)
        }

        try data.write(to: url)
        return url
    }

    private func exportToHTML(text: String, url: URL) throws -> URL {
        let escapedText = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")

        let html = """
        <!DOCTYPE html>
        <html><head><meta charset="UTF-8"><title>Transcription</title></head>
        <body><h1>Transcription</h1><p>\(escapedText)</p></body></html>
        """

        try html.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func exportToRTF(text: String, url: URL) throws -> URL {
        let attributedString = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 12)])
        let rtfData = try attributedString.data(from: NSRange(location: 0, length: attributedString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        try rtfData.write(to: url)
        return url
    }

    private func exportToCSV(text: String, url: URL, metadata: [String: Any]) throws -> URL {
        let dateFormatter = ISO8601DateFormatter()
        let date = metadata["date"] as? Date ?? Date()
        let escapedText = text.replacingOccurrences(of: "\"", with: "\"\"")
        let csv = "Date,Duration,Transcription\n\"\(dateFormatter.string(from: date))\",\(metadata["duration"] as? TimeInterval ?? 0),\"\(escapedText)\""
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
