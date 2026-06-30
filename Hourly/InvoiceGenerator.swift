import UIKit

enum InvoiceGenerator {
    static func make(client: String, sessions: [WorkSession]) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Invoice-\(client).pdf")
        let total = sessions.reduce(0) { $0 + $1.amount }

        try? renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            var y: CGFloat = 40
            let title = NSAttributedString(string: "Invoice", attributes: [.font: UIFont.boldSystemFont(ofSize: 28)])
            title.draw(at: CGPoint(x: 40, y: y)); y += 50

            let clientLine = NSAttributedString(string: "Bill to: \(client)", attributes: [.font: UIFont.systemFont(ofSize: 14)])
            clientLine.draw(at: CGPoint(x: 40, y: y)); y += 20

            let dateLine = NSAttributedString(string: "Date: \(Date().formatted(date: .abbreviated, time: .omitted))", attributes: [.font: UIFont.systemFont(ofSize: 14)])
            dateLine.draw(at: CGPoint(x: 40, y: y)); y += 40

            for s in sessions.sorted(by: { $0.start < $1.start }) {
                let line = "\(s.start.formatted(date: .abbreviated, time: .omitted))   \(String(format: "%.2f", s.hours))h × $\(String(format: "%.2f", s.rate))   = $\(String(format: "%.2f", s.amount))"
                NSAttributedString(string: line, attributes: [.font: UIFont.systemFont(ofSize: 12)]).draw(at: CGPoint(x: 40, y: y))
                y += 20
            }
            y += 20
            NSAttributedString(string: "Total: $\(String(format: "%.2f", total))", attributes: [.font: UIFont.boldSystemFont(ofSize: 18)]).draw(at: CGPoint(x: 40, y: y))
        }
        return url
    }
}
