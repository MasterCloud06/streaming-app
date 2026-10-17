import Foundation

/// Textos listos para copiar o compartir.
enum Formato {
    /// Mismo formato que se usaba en Notas:
    ///
    ///     Netflix
    ///
    ///     1. correo - contraseña - 6 de noviembre - Banco Sol 4264 - 17/10/2026
    ///        1. Marianela
    ///           1. +591... - 1 de noviembre - TV Sala
    static func texto(_ cuentas: [Cuenta], mostrarContrasena: Bool = true) -> String {
        let ordenadas = cuentas.sorted {
            ($0.plataforma.lowercased(), $0.fechaPago ?? .distantFuture) < ($1.plataforma.lowercased(), $1.fechaPago ?? .distantFuture)
        }
        var bloques: [String] = []
        var plataformaActual: String? = nil
        var indice = 0
        var lineas: [String] = []

        for c in ordenadas {
            if c.plataforma != plataformaActual {
                if !lineas.isEmpty { bloques.append(lineas.joined(separator: "\n")) }
                lineas = [c.plataforma, ""]
                plataformaActual = c.plataforma
                indice = 0
            }
            indice += 1
            let tarjeta = c.tarjeta.isEmpty ? "—" : c.tarjeta
            lineas.append("\(indice). \(c.correo) - \(mostrarContrasena ? c.contrasena : "••••••") - " +
                          "\(Fechas.larga(c.fechaPago)) - \(tarjeta) - \(Fechas.corta(c.fechaCierreSesion))")
            for (j, p) in c.perfilesOrdenados.enumerated() {
                lineas.append("   \(j + 1). \(p.nombre)")
                for (k, cl) in p.activos.enumerated() {
                    var partes = [cl.nombre.isEmpty ? cl.telefono : "\(cl.telefono) (\(cl.nombre))",
                                  Fechas.larga(cl.fechaVencimiento)]
                    if !cl.dispositivos.isEmpty { partes.append(cl.dispositivos.joined(separator: ", ")) }
                    lineas.append("      \(k + 1). \(partes.joined(separator: " - "))")
                }
            }
            lineas.append("")
        }
        if !lineas.isEmpty { bloques.append(lineas.joined(separator: "\n")) }
        return bloques.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    /// Datos de acceso para enviar a la persona.
    static func datosAcceso(_ cl: Cliente) -> String {
        guard let cuenta = cl.cuenta else { return "" }
        return """
        \(cuenta.plataforma)
        Correo: \(cuenta.correo)
        Contraseña: \(cuenta.contrasena)
        Perfil: \(cl.perfil?.nombre ?? "")
        Vence: \(Fechas.larga(cl.fechaVencimiento, conAnio: true))
        """
    }

    /// Recordatorio de pago para WhatsApp.
    static func recordatorio(_ cl: Cliente) -> String {
        let plataforma = cl.cuenta?.plataforma ?? ""
        let perfil = cl.perfil?.nombre ?? ""
        let d = cl.diasRestantes
        let cuando: String
        switch d {
        case ..<0: cuando = "venció el \(Fechas.larga(cl.fechaVencimiento))"
        case 0: cuando = "vence hoy"
        case 1: cuando = "vence mañana"
        default: cuando = "vence el \(Fechas.larga(cl.fechaVencimiento))"
        }
        return "Hola 👋 Tu perfil \(perfil) de \(plataforma) \(cuando). ¿Deseas renovar?"
    }

    /// Enlace de WhatsApp con el recordatorio escrito.
    static func enlaceWhatsApp(_ cl: Cliente, mensaje: String? = nil) -> URL? {
        let numero = cl.telefono.filter(\.isNumber)
        guard !numero.isEmpty else { return nil }
        var c = URLComponents(string: "https://wa.me/\(numero)")
        c?.queryItems = [URLQueryItem(name: "text", value: mensaje ?? recordatorio(cl))]
        return c?.url
    }
}
