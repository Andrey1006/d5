
import Foundation
import UIKit

enum PDFReportBuilder {
    static func buildProjectReport(project: Project, settings: ThresholdSettings) throws -> URL {
        let report = BalanceCalculator.report(loads: project.loads, context: project.context, thresholds: settings)
        let maxPhase = PhaseLine.allCases.map { report.ampsByPhase[$0] ?? 0 }.max() ?? 0
        let suggestedBreaker = BalanceCalculator.suggestedBreakerAmps(forPhaseCurrentAmps: maxPhase)
        let suggestedCable = suggestedBreaker.flatMap { BalanceCalculator.suggestedCopperCableMm2(forBreakerAmps: $0) }
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: format)
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let margin: CGFloat = 40
            var y = margin
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.black
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.black
            ]
            let monoAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]

            func draw(_ text: String, _ attrs: [NSAttributedString.Key: Any] = bodyAttrs) {
                let s = NSAttributedString(string: text + "\n", attributes: attrs)
                let h = s.boundingRect(with: CGSize(width: page.width - margin * 2, height: 900), options: [.usesLineFragmentOrigin], context: nil).height
                s.draw(in: CGRect(x: margin, y: y, width: page.width - margin * 2, height: h))
                y += h + 4
            }

            draw("Zeuphase Check — \(project.name)", titleAttrs)
            draw("Date: \(Date().formatted(date: .long, time: .shortened))")
            draw("\(project.context.gridLabel) · U line \(Int(project.context.lineToLineVoltageVolts)) V · U L-N \(Int(project.context.lineToNeutralVoltageVolts)) V · cos φ \(String(format: "%.2f", project.context.defaultPowerFactor))")
            if let lim = project.context.maxCurrentPerPhaseAmps {
                draw("Per-phase limit: \(BalanceCalculator.formatA(lim))")
            }
            y += 8
            draw("Imbalance: \(BalanceCalculator.formatPercent(report.imbalancePercent)) · status: \(String(describing: report.status))")
            draw("Neutral (ideal): \(BalanceCalculator.formatA(report.neutralCurrentAmps))")
            if let suggestedBreaker {
                var line = "Suggested breaker (rough): \(Int(suggestedBreaker)) A"
                if let suggestedCable {
                    line += " · Cu cable (rough): \(String(format: "%.1f", suggestedCable)) mm²"
                }
                draw(line)
            }
            y += 8
            draw("Currents by phase:", titleAttrs)
            for p in PhaseLine.allCases {
                let a = report.ampsByPhase[p] ?? 0
                draw("  \(p.rawValue): \(BalanceCalculator.formatA(a))", monoAttrs)
            }
            y += 8
            draw("Loads (\(project.loads.count)):", titleAttrs)
            for load in project.loads.sorted(by: { $0.name < $1.name }) {
                let i = BalanceCalculator.resolvedLineCurrentAmps(for: load, context: project.context)
                let on = load.isIncluded ? "" : " [off]"
                let conn = load.connectionKind == .threePhaseBalanced ? "3φ" : "1φ \(load.phase.rawValue)"
                draw("  • \(load.name)\(on) — \(conn) — \(BalanceCalculator.formatA(i)) — \(load.category.title)", monoAttrs)
            }
            if !report.warnings.isEmpty {
                y += 8
                draw("Warnings:", titleAttrs)
                for w in report.warnings {
                    draw("  ⚠ \(w)", monoAttrs)
                }
            }
            y += 16
            draw("Indicative calculation only. Verify with measurements and applicable codes on site.", [
                .font: UIFont.italicSystemFont(ofSize: 9),
                .foregroundColor: UIColor.darkGray
            ])
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ZeuphaseCheck_\(project.name.replacingOccurrences(of: "/", with: "_")).pdf")
        try data.write(to: url, options: [.atomic])
        return url
    }
}
