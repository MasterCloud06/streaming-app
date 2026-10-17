import Foundation
import SwiftData

/// Lee el texto copiado de Notas del iPhone y lo convierte en cuentas.
///
/// Reconoce cada línea por su contenido (no depende de la sangría, que Notas a veces pierde):
///  - Línea sin número y sin "@"            → plataforma (Netflix, Disney+, ...)
///  - "N. correo@... - clave - ..."         → cuenta
///  - "N. +591... - 1 de noviembre [- TV]"  → persona del perfil actual
///  - "N. Nombre"                            → perfil
enum Importador {
    struct ClienteLeido { var telefono: String; var vencimiento: Date; var dispositivos: [String] }
    struct PerfilLeido { var nombre: String; var clientes: [ClienteLeido] = [] }
    struct CuentaLeida {
        var correo: String; var contrasena: String
        var fechaPago: Date?; var banco: String; var ultimos4: String; var cierre: Date?
        var perfiles: [PerfilLeido] = []
    }
    struct PlataformaLeida { var nombre: String; var cuentas: [CuentaLeida] = [] }

    struct Resultado {
        var plataformas: [PlataformaLeida] = []
        var avisos: [String] = []
        var totalCuentas: Int { plataformas.reduce(0) { $0 + $1.cuentas.count } }
        var totalPerfiles: Int { plataformas.flatMap(\.cuentas).reduce(0) { $0 + $1.perfiles.count } }
        var totalPersonas: Int {
            plataformas.flatMap(\.cuentas).flatMap(\.perfiles).reduce(0) { $0 + $1.clientes.count }
        }
    }

    static let mesesPorNombre: [String: Int] = [
        "enero": 1, "febrero": 2, "marzo": 3, "abril": 4, "mayo": 5, "junio": 6, "julio": 7,
        "agosto": 8, "septiembre": 9, "setiembre": 9, "octubre": 10, "noviembre": 11, "diciembre": 12,
    ]

    // MARK: - Limpieza de texto

    /// Quita caracteres invisibles que iOS pega junto a los teléfonos (‪ ‬ etc.).
    static func limpiar(_ s: String) -> String {
        var r = String(String.UnicodeScalarView(s.unicodeScalars.compactMap { u -> Unicode.Scalar? in
            switch u.value {
            case 0x200E, 0x200F, 0x202A...0x202E, 0x2066...0x2069, 0xFEFF: return nil
            case 0x00A0: return " "
            default: return u
            }
        }))
        // [correo](mailto:correo) → correo
        r = reemplazar(#"\[([^\]]+)\]\(mailto:[^)]+\)"#, en: r, con: "$1")
        return r.trimmingCharacters(in: .whitespaces)
    }

    /// "+591 7000-0001", "++591..." → "+59170000001". Devuelve nil si tiene menos de 6 dígitos.
    static func normalizarTelefono(_ t: String) -> String? {
        let limpio = limpiar(t)
        let digitos = limpio.filter(\.isNumber)
        guard digitos.count >= 6 else { return nil }
        return (limpio.hasPrefix("+") ? "+" : "") + digitos
    }

    // MARK: - Fechas

    /// "6 de noviembre", "6 noviembre", "06/11/2026", "6/11" → Date.
    /// Sin año: si la fecha quedó más de 60 días atrás se asume el año siguiente.
    static func interpretarFecha(_ texto: String, hoy: Date = Fechas.hoy()) -> Date? {
        let s = limpiar(texto).lowercased()
        var d = 0, m = 0, a: Int? = nil

        if let g = grupos(#"^(\d{1,2})\s*(?:de\s+)?([a-záéíóú]+)(?:\s*(?:de(?:l)?\s+)?(\d{4}))?$"#, en: s),
           let mes = mesesPorNombre[g[2]] {
            d = Int(g[1]) ?? 0; m = mes; a = Int(g[3])
        } else if let g = grupos(#"^(\d{1,2})[/.-](\d{1,2})(?:[/.-](\d{2,4}))?$"#, en: s) {
            d = Int(g[1]) ?? 0; m = Int(g[2]) ?? 0
            if let y = Int(g[3]) { a = y < 100 ? 2000 + y : y }
        } else {
            return nil
        }

        if a == nil {
            let anioHoy = Fechas.partes(hoy).anio
            guard let candidata = Fechas.crear(anioHoy, m, d) else { return nil }
            let diasAtras = Fechas.calendario.dateComponents([.day], from: candidata, to: hoy).day ?? 0
            a = diasAtras > 60 ? anioHoy + 1 : anioHoy
        }
        return Fechas.crear(a!, m, d)
    }

    // MARK: - Análisis

    static func analizar(_ texto: String, hoy: Date = Fechas.hoy()) -> Resultado {
        var res = Resultado()
        var iPlat: Int? = nil, iCuenta: Int? = nil, iPerfil: Int? = nil

        for (n, bruta) in texto.components(separatedBy: .newlines).enumerated() {
            let linea = limpiar(bruta)
            if linea.isEmpty { continue }
            let num = n + 1

            let numerada = grupos(#"^(?:[-*•]\s*)?\d+[.)]\s*(.+)$"#, en: linea)
            let cuerpo = numerada?[1].trimmingCharacters(in: .whitespaces)
                ?? reemplazar(#"^[-*•]\s*"#, en: linea, con: "")
            let empiezaConNumero = grupos(#"^\+*\d"#, en: cuerpo) != nil

            // Plataforma
            if numerada == nil && !cuerpo.contains("@") && !empiezaConNumero {
                res.plataformas.append(PlataformaLeida(nombre: cuerpo))
                iPlat = res.plataformas.count - 1; iCuenta = nil; iPerfil = nil
                continue
            }

            // Cuenta
            if cuerpo.contains("@") {
                if iPlat == nil {
                    res.plataformas.append(PlataformaLeida(nombre: "Sin plataforma"))
                    iPlat = res.plataformas.count - 1
                }
                let p = dividir(cuerpo, por: #"\s+-\s+"#)
                let tarjeta = p.count > 3 ? p[3] : ""
                let t = grupos(#"^(.*?)\s*(\d{4})$"#, en: tarjeta)
                var cuenta = CuentaLeida(
                    correo: p[0], contrasena: p.count > 1 ? p[1] : "",
                    fechaPago: p.count > 2 ? interpretarFecha(p[2], hoy: hoy) : nil,
                    banco: t?[1].trimmingCharacters(in: .whitespaces) ?? tarjeta,
                    ultimos4: t?[2] ?? "",
                    cierre: p.count > 4 ? interpretarFecha(p[4], hoy: hoy) : nil)
                if p.count > 2 && cuenta.fechaPago == nil {
                    res.avisos.append("Línea \(num): no entendí la fecha de pago \"\(p[2])\"")
                }
                if cuenta.correo.isEmpty { cuenta.correo = cuerpo }
                res.plataformas[iPlat!].cuentas.append(cuenta)
                iCuenta = res.plataformas[iPlat!].cuentas.count - 1; iPerfil = nil
                continue
            }

            // Persona (empieza con teléfono)
            if empiezaConNumero {
                guard let ip = iPlat, let ic = iCuenta, let ipf = iPerfil else {
                    res.avisos.append("Línea \(num): teléfono sin perfil, se ignoró")
                    continue
                }
                let p = dividir(cuerpo, por: #"\s+-\s+|\s*-\s*(?=\+|\d{1,2}\s*(?:de\s+)?[a-záéíóú]|\d{1,2}[/.]\d)"#)
                let telBruto = p[0]
                let venc = p.count > 1 ? interpretarFecha(p[1], hoy: hoy) : nil
                if venc == nil { res.avisos.append("Línea \(num): sin fecha de vencimiento válida para \(telBruto), se puso hoy") }
                let tel = normalizarTelefono(telBruto) ?? telBruto
                if normalizarTelefono(telBruto) == nil { res.avisos.append("Línea \(num): teléfono incompleto \"\(telBruto)\"") }
                let resto = p.count > 2 ? p[2...].joined(separator: " - ") : ""
                let dispositivos = dividir(resto, por: #"\s*[,/]\s*|\s+y\s+"#).filter { !$0.isEmpty }
                res.plataformas[ip].cuentas[ic].perfiles[ipf].clientes.append(
                    ClienteLeido(telefono: tel, vencimiento: venc ?? hoy, dispositivos: dispositivos))
                continue
            }

            // Perfil
            guard let ip = iPlat, let ic = iCuenta else {
                res.avisos.append("Línea \(num): perfil \"\(cuerpo)\" sin cuenta, se ignoró")
                continue
            }
            res.plataformas[ip].cuentas[ic].perfiles.append(PerfilLeido(nombre: cuerpo))
            iPerfil = res.plataformas[ip].cuentas[ic].perfiles.count - 1
        }
        return res
    }

    // MARK: - Guardar

    /// Guarda lo leído. Las cuentas que ya existen (misma plataforma + correo) se omiten.
    @MainActor
    @discardableResult
    static func guardar(_ res: Resultado, en ctx: ModelContext) -> (creadas: Int, omitidas: [String]) {
        let existentes = (try? ctx.fetch(FetchDescriptor<Cuenta>())) ?? []
        var creadas = 0
        var omitidas: [String] = []

        for plat in res.plataformas {
            for c in plat.cuentas {
                if existentes.contains(where: {
                    $0.plataforma.lowercased() == plat.nombre.lowercased() && $0.correo.lowercased() == c.correo.lowercased()
                }) {
                    omitidas.append("\(plat.nombre) \(c.correo)")
                    continue
                }
                let cuenta = Cuenta(plataforma: plat.nombre, correo: c.correo, contrasena: c.contrasena,
                                    fechaPago: c.fechaPago, banco: c.banco, ultimos4: c.ultimos4,
                                    fechaCierreSesion: c.cierre)
                ctx.insert(cuenta)
                for (i, p) in c.perfiles.enumerated() {
                    let perfil = Perfil(posicion: i + 1, nombre: p.nombre, maxClientes: max(2, p.clientes.count))
                    cuenta.perfiles.append(perfil)
                    for cl in p.clientes {
                        perfil.clientes.append(Cliente(telefono: cl.telefono, fechaVencimiento: cl.vencimiento,
                                                       dispositivos: cl.dispositivos))
                    }
                }
                creadas += 1
                Bitacora.registrar(ctx, "IMPORTAR",
                                   "\(plat.nombre) \(c.correo) importada desde Notas (\(c.perfiles.count) perfiles)",
                                   actualizarArchivos: false)
            }
        }
        Bitacora.guardarYActualizar(ctx)
        return (creadas, omitidas)
    }

    // MARK: - Regex helpers

    /// Devuelve [coincidencia completa, grupo1, grupo2, ...] ("" para grupos vacíos), o nil.
    static func grupos(_ patron: String, en s: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: patron, options: [.caseInsensitive]),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            Range(m.range(at: i), in: s).map { String(s[$0]) } ?? ""
        }
    }

    static func reemplazar(_ patron: String, en s: String, con plantilla: String) -> String {
        guard let re = try? NSRegularExpression(pattern: patron, options: [.caseInsensitive]) else { return s }
        return re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: plantilla)
    }

    static func dividir(_ s: String, por patron: String) -> [String] {
        guard !s.isEmpty, let re = try? NSRegularExpression(pattern: patron, options: [.caseInsensitive]) else {
            return s.isEmpty ? [] : [s]
        }
        var partes: [String] = []
        var inicio = s.startIndex
        for m in re.matches(in: s, range: NSRange(s.startIndex..., in: s)) {
            guard let r = Range(m.range, in: s), r.lowerBound >= inicio, !r.isEmpty else { continue }
            partes.append(String(s[inicio..<r.lowerBound]))
            inicio = r.upperBound
        }
        partes.append(String(s[inicio...]))
        return partes.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
