import Foundation

enum Fechas {
    static let calendario: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "es_BO")
        c.timeZone = .current
        return c
    }()

    static let meses = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
                        "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

    static func hoy() -> Date { calendario.startOfDay(for: .now) }
    static func dia(_ d: Date) -> Date { calendario.startOfDay(for: d) }

    /// Suma meses respetando fin de mes (31 ene + 1 mes = 28/29 feb).
    static func sumarMeses(_ d: Date, _ n: Int) -> Date {
        calendario.date(byAdding: .month, value: n, to: dia(d)) ?? d
    }

    static func sumarDias(_ d: Date, _ n: Int) -> Date {
        calendario.date(byAdding: .day, value: n, to: dia(d)) ?? d
    }

    /// Días desde hoy hasta la fecha (negativo si ya pasó).
    static func diasHasta(_ d: Date) -> Int {
        calendario.dateComponents([.day], from: hoy(), to: dia(d)).day ?? 0
    }

    static func crear(_ anio: Int, _ mes: Int, _ dia: Int) -> Date? {
        var c = DateComponents()
        c.year = anio; c.month = mes; c.day = dia
        guard let f = calendario.date(from: c) else { return nil }
        // Rechaza fechas como 31 de febrero (Calendar las corre al mes siguiente)
        let comp = calendario.dateComponents([.year, .month, .day], from: f)
        return comp.month == mes && comp.day == dia ? f : nil
    }

    static func partes(_ d: Date) -> (anio: Int, mes: Int, dia: Int) {
        let c = calendario.dateComponents([.year, .month, .day], from: d)
        return (c.year ?? 0, c.month ?? 1, c.day ?? 1)
    }

    /// "6 de noviembre" (agrega el año si no es el actual, o si `conAnio` es true).
    static func larga(_ d: Date?, conAnio: Bool = false) -> String {
        guard let d else { return "—" }
        let p = partes(d)
        let mostrarAnio = conAnio || p.anio != partes(.now).anio
        return "\(p.dia) de \(meses[p.mes - 1])" + (mostrarAnio ? " de \(p.anio)" : "")
    }

    /// "17/10/2026"
    static func corta(_ d: Date?) -> String {
        guard let d else { return "—" }
        let p = partes(d)
        return String(format: "%02d/%02d/%04d", p.dia, p.mes, p.anio)
    }

    /// "2026-10-17" (nombres de archivo)
    static func iso(_ d: Date) -> String {
        let p = partes(d)
        return String(format: "%04d-%02d-%02d", p.anio, p.mes, p.dia)
    }

    static func hora(_ d: Date) -> String {
        let c = calendario.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// "Vence hoy", "Venció hace 2 días", "En 5 días"
    static func relativo(_ dias: Int) -> String {
        switch dias {
        case ..<(-1): return "Venció hace \(-dias) días"
        case -1: return "Venció ayer"
        case 0: return "Vence hoy"
        case 1: return "Vence mañana"
        default: return "En \(dias) días"
        }
    }
}
