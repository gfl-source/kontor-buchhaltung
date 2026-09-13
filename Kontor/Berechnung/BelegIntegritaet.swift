import Foundation
import SwiftData

struct FehlenderBeleg: Hashable, Identifiable {
    var typ: String
    var bezeichnung: String
    var pfad: String

    var id: String { "\(typ)|\(bezeichnung)|\(pfad)" }
}

struct IntegritaetsBericht: Hashable {
    var fehlendeBelege: [FehlenderBeleg]
    var verwaisteDateien: [String]

    var istLeer: Bool { fehlendeBelege.isEmpty && verwaisteDateien.isEmpty }
}

enum BelegIntegritaet {
    static func bericht(_ context: ModelContext) throws -> IntegritaetsBericht {
        let referenzen = try referenzen(context)
        let dateien = Set(dateienImBelegeOrdner())
        let referenzPfade = Set(referenzen.map(\.pfad))

        let fehlende = referenzen
            .filter { !dateien.contains($0.pfad) }
            .map { FehlenderBeleg(typ: $0.typ, bezeichnung: $0.bezeichnung, pfad: $0.pfad) }
            .sorted { a, b in
                if a.pfad != b.pfad { return a.pfad < b.pfad }
                if a.typ != b.typ { return a.typ < b.typ }
                return a.bezeichnung < b.bezeichnung
            }

        let verwaiste = dateien
            .filter { !referenzPfade.contains($0) }
            .sorted()

        return IntegritaetsBericht(fehlendeBelege: fehlende, verwaisteDateien: verwaiste)
    }

    private static func referenzen(_ context: ModelContext) throws -> [FehlenderBeleg] {
        var alle: [FehlenderBeleg] = []

        let ausgaben = try context.fetch(FetchDescriptor<ExpenseEntry>())
        alle.append(
            contentsOf: ausgaben.compactMap { eintrag in
                guard let pfad = belegPfad(eintrag.belegPfad) else { return nil }
                return FehlenderBeleg(typ: "Ausgabe", bezeichnung: eintrag.bezeichnung, pfad: pfad)
            })

        let einnahmen = try context.fetch(FetchDescriptor<Income>())
        alle.append(
            contentsOf: einnahmen.compactMap { eintrag in
                guard let pfad = belegPfad(eintrag.belegPfad) else { return nil }
                return FehlenderBeleg(typ: "Einnahme", bezeichnung: eintrag.kunde, pfad: pfad)
            })

        let anschaffungen = try context.fetch(FetchDescriptor<PurchaseEntry>())
        alle.append(
            contentsOf: anschaffungen.compactMap { eintrag in
                guard let pfad = belegPfad(eintrag.belegPfad) else { return nil }
                return FehlenderBeleg(typ: "Anschaffung", bezeichnung: eintrag.bezeichnung, pfad: pfad)
            })

        return alle
    }

    private static func belegPfad(_ pfad: String?) -> String? {
        guard let pfad, !pfad.isEmpty else { return nil }
        return pfad
    }

    private static func dateienImBelegeOrdner() -> [String] {
        let basis = Belege.basis.standardizedFileURL
        let fm = FileManager.default
        guard let en = fm.enumerator(at: basis, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }

        let basisPfad = basis.path.hasSuffix("/") ? basis.path : basis.path + "/"
        var dateien: [String] = []
        for case let datei as URL in en {
            guard (try? datei.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            let pfad = datei.standardizedFileURL.path
            guard pfad.hasPrefix(basisPfad) else { continue }
            let relativ = String(pfad.dropFirst(basisPfad.count))
            guard !relativ.isEmpty else { continue }
            dateien.append(relativ.replacingOccurrences(of: "\\", with: "/"))
        }
        return dateien.sorted()
    }
}
