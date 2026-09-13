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
        let dateien = Set(try dateienImBelegeOrdner())
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
        try referenzen(
            context,
            descriptor: FetchDescriptor<ExpenseEntry>(
                predicate: #Predicate<ExpenseEntry> { eintrag in
                    if let pfad = eintrag.belegPfad { return !pfad.isEmpty }
                    return false
                }),
            typ: "Ausgabe",
            bezeichnung: \.bezeichnung,
            pfad: \.belegPfad
        )
            + referenzen(
                context,
                descriptor: FetchDescriptor<Income>(
                    predicate: #Predicate<Income> { eintrag in
                        if let pfad = eintrag.belegPfad { return !pfad.isEmpty }
                        return false
                    }),
                typ: "Einnahme",
                bezeichnung: \.kunde,
                pfad: \.belegPfad
            )
            + referenzen(
                context,
                descriptor: FetchDescriptor<PurchaseEntry>(
                    predicate: #Predicate<PurchaseEntry> { eintrag in
                        if let pfad = eintrag.belegPfad { return !pfad.isEmpty }
                        return false
                    }),
                typ: "Anschaffung",
                bezeichnung: \.bezeichnung,
                pfad: \.belegPfad
            )
    }

    private static func belegPfad(_ pfad: String?) -> String? {
        guard let pfad, !pfad.isEmpty else { return nil }
        return pfad
    }

    private static func referenzen<T: PersistentModel>(
        _ context: ModelContext,
        descriptor: FetchDescriptor<T>,
        typ: String,
        bezeichnung: KeyPath<T, String>,
        pfad: KeyPath<T, String?>
    ) throws -> [FehlenderBeleg] {
        try context.fetch(descriptor).compactMap { eintrag in
            guard let pfad = belegPfad(eintrag[keyPath: pfad]) else { return nil }
            return FehlenderBeleg(typ: typ, bezeichnung: eintrag[keyPath: bezeichnung], pfad: pfad)
        }
    }

    private static func dateienImBelegeOrdner() throws -> [String] {
        let basis = Belege.basis.standardizedFileURL
        let fm = FileManager.default
        var istOrdner = ObjCBool(false)
        guard fm.fileExists(atPath: basis.path, isDirectory: &istOrdner), istOrdner.boolValue else { return [] }
        let unterpfade = try fm.subpathsOfDirectory(atPath: basis.path)
        var dateien: [String] = []
        for unterpfad in unterpfade {
            var istOrdner = ObjCBool(false)
            let url = basis.appendingPathComponent(unterpfad)
            guard fm.fileExists(atPath: url.path, isDirectory: &istOrdner), !istOrdner.boolValue else { continue }
            dateien.append(unterpfad.replacingOccurrences(of: "\\", with: "/"))
        }
        return dateien.sorted()
    }
}
