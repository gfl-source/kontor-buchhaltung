import Foundation
import Testing

@testable import Kontor

struct BelegIntegritaetTests {
    @Test func fehlendeBelegeWerdenErkannt() throws {
        try mitTemporaerenBelegen { _ in
            let ctx = try testKontext()
            ctx.insert(
                ExpenseEntry(
                    datum: tag(2026, 1, 5), bezeichnung: "Figma", anbieter: "Figma",
                    brutto: dez("35"), vst: 0, steuerart: .reverseCharge,
                    belegPfad: "2026/fehlt.pdf"))
            ctx.insert(
                Income(
                    kunde: "Kunde A", rnNetto: dez("100"), ust: dez("19"),
                    rechnungsdatum: tag(2026, 1, 10), belegPfad: "2026/rechnung.pdf"))
            try legeDateiAn("2026/rechnung.pdf")

            let bericht = try BelegIntegritaet.bericht(ctx)
            #expect(bericht.fehlendeBelege.map(\.pfad) == ["2026/fehlt.pdf"])
            #expect(bericht.verwaisteDateien.isEmpty)
        }
    }

    @Test func verwaisteDateienWerdenErkannt() throws {
        try mitTemporaerenBelegen { _ in
            let ctx = try testKontext()
            ctx.insert(PurchaseEntry(datum: tag(2026, 2, 1), bezeichnung: "Maus", preis: dez("50"), belegPfad: "2026/maus.pdf"))
            try legeDateiAn("2026/maus.pdf")
            try legeDateiAn("2026/verwaist.pdf")

            let bericht = try BelegIntegritaet.bericht(ctx)
            #expect(bericht.fehlendeBelege.isEmpty)
            #expect(bericht.verwaisteDateien == ["2026/verwaist.pdf"])
        }
    }

    @Test func saubererBestandIstLeer() throws {
        try mitTemporaerenBelegen { _ in
            let ctx = try testKontext()
            ctx.insert(
                ExpenseEntry(
                    datum: tag(2026, 3, 1), bezeichnung: "Hosting", anbieter: "Provider",
                    brutto: dez("19"), vst: dez("3.03"), steuerart: .inland19,
                    belegPfad: "2026/hosting.pdf"))
            ctx.insert(
                Income(
                    kunde: "Kunde B", rnNetto: dez("200"), ust: dez("38"),
                    rechnungsdatum: tag(2026, 3, 2), belegPfad: "2026/rechnung-b.pdf"))
            ctx.insert(PurchaseEntry(datum: tag(2026, 3, 3), bezeichnung: "Tastatur", preis: dez("90"), belegPfad: "2026/tastatur.pdf"))
            try legeDateiAn("2026/hosting.pdf")
            try legeDateiAn("2026/rechnung-b.pdf")
            try legeDateiAn("2026/tastatur.pdf")

            let bericht = try BelegIntegritaet.bericht(ctx)
            #expect(bericht.istLeer)
            #expect(bericht.fehlendeBelege.isEmpty)
            #expect(bericht.verwaisteDateien.isEmpty)
        }
    }

    private func legeDateiAn(_ relativ: String) throws {
        let url = Belege.url(fuer: relativ)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: url)
    }
}
