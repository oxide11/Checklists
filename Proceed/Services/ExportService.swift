import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum ExportError: LocalizedError {
    case pdfGenerationFailed
    case pdfRenderedEmpty

    var errorDescription: String? {
        switch self {
        case .pdfGenerationFailed:
            return "The PDF context could not be created."
        case .pdfRenderedEmpty:
            return "The PDF renderer produced no pages."
        }
    }
}

struct ExportService {

    // MARK: - Markdown

    static func exportMarkdown(checklist: Checklist) -> String {
        var md = "# \(checklist.title)\n\n"
        md += "**Version:** \(checklist.versionNumber)  \n"
        md += "**Category:** \(checklist.category?.name ?? "Uncategorized")  \n"
        md += "**Last Updated:** \(checklist.lastUpdatedDate.formatted(date: .abbreviated, time: .omitted))  \n"
        md += "**Last Reviewed:** \(checklist.lastReviewedDate.formatted(date: .abbreviated, time: .omitted))  \n"

        if checklist.isEmergency {
            md += "\n> **EMERGENCY PROCEDURE**\n"
        }

        // Preparation notes
        if let notes = checklist.preparationNotes, !notes.isEmpty {
            md += "\n## Preparation\n\n\(notes)\n"
        }

        // Equipment
        let equipment = checklist.requiredEquipment
        let inventoryItems = checklist.safeEquipmentItems
        if !equipment.isEmpty || !inventoryItems.isEmpty {
            md += "\n## Required Equipment\n\n"
            for item in inventoryItems {
                md += "- [ ] \(item.name)"
                if !item.storageLocation.isEmpty {
                    md += " — *\(item.storageLocation)*"
                }
                md += "\n"
            }
            for item in equipment {
                md += "- [ ] \(item)\n"
            }
        }

        // Steps
        md += "\n## Steps\n\n"
        for (index, step) in checklist.orderedSteps.enumerated() {
            let num = index + 1
            switch step.stepType {
            case .warning:
                md += "\(num). **⚠️ WARNING:** \(step.text)\n"
            case .caution:
                md += "\(num). **⚡ CAUTION:** \(step.text)\n"
            case .decision:
                let q = step.question ?? step.text
                md += "\(num). **🔀 DECISION:** \(q)\n"
                for option in step.branchOptions {
                    md += "   - → \(option.label)\n"
                }
            case .action:
                md += "\(num). \(step.text)\n"
            }

            if let note = step.note, !note.isEmpty {
                md += "   > *\(note)*\n"
            }

            if let ref = step.referenceFileName, !ref.isEmpty {
                md += "   📎 Reference: \(ref)\n"
            }

            if let duration = step.timerDuration, duration > 0 {
                md += "   ⏱ Timer: \(duration.formattedDuration)\n"
            }

            md += "\n"
        }

        return md
    }

    // MARK: - HTML

    static func exportHTML(checklist: Checklist) -> String {
        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>\(escapeHTML(checklist.title))</title>
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; color: #333; }
        h1 { border-bottom: 2px solid #007AFF; padding-bottom: 8px; }
        .meta { color: #666; font-size: 0.9em; margin-bottom: 20px; }
        .emergency { background: #FFE5E5; border-left: 4px solid #FF3B30; padding: 10px; margin: 10px 0; font-weight: bold; color: #FF3B30; }
        .equipment { background: #F5F5F7; padding: 15px; border-radius: 8px; margin: 15px 0; }
        .equipment h2 { margin-top: 0; }
        .equipment li { margin: 5px 0; }
        .step { padding: 12px 15px; margin: 8px 0; border-radius: 8px; border-left: 4px solid #007AFF; background: #F9F9FB; }
        .step-num { font-weight: bold; color: #007AFF; margin-right: 8px; }
        .step.warning { border-left-color: #FF3B30; background: #FFF5F5; }
        .step.caution { border-left-color: #FF9500; background: #FFF8F0; }
        .step.decision { border-left-color: #5AC8FA; background: #F0FAFF; }
        .step-note { font-style: italic; color: #666; margin-top: 5px; font-size: 0.9em; }
        .branch { margin-left: 20px; color: #5AC8FA; }
        .timer { color: #007AFF; font-size: 0.85em; }
        .reference { color: #5856D6; font-size: 0.85em; }
        @media print { body { max-width: 100%; } .step { break-inside: avoid; } }
        </style>
        </head>
        <body>
        <h1>\(escapeHTML(checklist.title))</h1>
        <div class="meta">
        Version \(escapeHTML(checklist.versionNumber)) &bull;
        \(escapeHTML(checklist.category?.name ?? "Uncategorized")) &bull;
        Updated \(checklist.lastUpdatedDate.formatted(date: .abbreviated, time: .omitted))
        </div>
        """

        if checklist.isEmergency {
            html += "<div class=\"emergency\">EMERGENCY PROCEDURE</div>\n"
        }

        if let notes = checklist.preparationNotes, !notes.isEmpty {
            html += "<h2>Preparation</h2>\n<p>\(escapeHTML(notes))</p>\n"
        }

        let equipment = checklist.requiredEquipment
        let inventoryItems = checklist.safeEquipmentItems
        if !equipment.isEmpty || !inventoryItems.isEmpty {
            html += "<div class=\"equipment\"><h2>Required Equipment</h2><ul>\n"
            for item in inventoryItems {
                html += "<li>\(escapeHTML(item.name))"
                if !item.storageLocation.isEmpty {
                    html += " — <em>\(escapeHTML(item.storageLocation))</em>"
                }
                html += "</li>\n"
            }
            for item in equipment {
                html += "<li>\(escapeHTML(item))</li>\n"
            }
            html += "</ul></div>\n"
        }

        html += "<h2>Steps</h2>\n"
        for (index, step) in checklist.orderedSteps.enumerated() {
            let num = index + 1
            let cssClass: String
            switch step.stepType {
            case .warning: cssClass = "step warning"
            case .caution: cssClass = "step caution"
            case .decision: cssClass = "step decision"
            case .action: cssClass = "step"
            }

            html += "<div class=\"\(cssClass)\">"
            html += "<span class=\"step-num\">\(num).</span> "

            switch step.stepType {
            case .warning:
                html += "<strong>WARNING:</strong> \(escapeHTML(step.text))"
            case .caution:
                html += "<strong>CAUTION:</strong> \(escapeHTML(step.text))"
            case .decision:
                let q = step.question ?? step.text
                html += "<strong>DECISION:</strong> \(escapeHTML(q))"
                for option in step.branchOptions {
                    html += "<div class=\"branch\">→ \(escapeHTML(option.label))</div>"
                }
            case .action:
                html += escapeHTML(step.text)
            }

            if let note = step.note, !note.isEmpty {
                html += "<div class=\"step-note\">\(escapeHTML(note))</div>"
            }

            if let ref = step.referenceFileName, !ref.isEmpty {
                html += "<div class=\"reference\">📎 \(escapeHTML(ref))</div>"
            }

            if let duration = step.timerDuration, duration > 0 {
                html += "<div class=\"timer\">⏱ \(duration.formattedDuration)</div>"
            }

            html += "</div>\n"
        }

        html += "</body></html>"
        return html
    }

    // MARK: - PDF

    #if canImport(UIKit)
    static func exportPDF(checklist: Checklist) throws -> Data {
        let htmlString = exportHTML(checklist: checklist)
        let formatter = UIMarkupTextPrintFormatter(markupText: htmlString)

        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        // US Letter size
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 36

        let printableRect = CGRect(x: margin, y: margin, width: pageWidth - 2 * margin, height: pageHeight - 2 * margin)
        let paperRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        renderer.setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, paperRect, nil)
        defer { UIGraphicsEndPDFContext() }

        guard renderer.numberOfPages > 0 else {
            throw ExportError.pdfRenderedEmpty
        }

        for page in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: page, in: UIGraphicsGetPDFContextBounds())
        }

        let output = pdfData as Data
        guard !output.isEmpty else { throw ExportError.pdfGenerationFailed }
        return output
    }
    #endif

    // MARK: - Helpers

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
