import Foundation
import SwiftData

/// Bitácora de cambios. Cada cambio:
///  - se guarda como `Registro` (pestaña Notas de la app)
///  - se agrega al bloc de notas del día: Archivos › En mi iPhone › Cuentas Streaming › Notas › cambios-AAAA-MM-DD.txt
///  - y se reescribe estado-actual.txt con todas las cuentas en el formato de Notas.
@MainActor
enum Bitacora {
    static var carpetaDocumentos: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var carpetaNotas: URL { carpetaDocumentos.appendingPathComponent("Notas", isDirectory: true) }
    static var archivoEstado: URL { carpetaNotas.appendingPathComponent("estado-actual.txt") }
    static func archivoDelDia(_ d: Date = .now) -> URL {
        carpetaNotas.appendingPathComponent("cambios-\(Fechas.iso(d)).txt")
    }

    static func registrar(_ ctx: ModelContext, _ accion: String, _ descripcion: String,
                          actualizarArchivos: Bool = true) {
        ctx.insert(Registro(accion: accion, descripcion: descripcion))
        agregarLinea("[\(Fechas.hora(.now))] \(accion): \(descripcion)\n")
        if actualizarArchivos { guardarYActualizar(ctx) }
    }

    /// Guarda en la base de datos, regenera estado-actual.txt y reprograma los avisos.
    static func guardarYActualizar(_ ctx: ModelContext) {
        do { try ctx.save() } catch { print("[Bitacora] Error al guardar:", error) }
        regenerarEstado(ctx)
        Notificaciones.reprogramar(ctx)
    }

    static func regenerarEstado(_ ctx: ModelContext) {
        let cuentas = (try? ctx.fetch(FetchDescriptor<Cuenta>())) ?? []
        let texto = "Estado al \(Fechas.corta(.now)) \(Fechas.hora(.now))\n\n" + Formato.texto(cuentas.filter(\.activa))
        crearCarpeta()
        try? texto.write(to: archivoEstado, atomically: true, encoding: .utf8)
    }

    static func archivosDeNotas() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: carpetaNotas, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "txt" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private static func agregarLinea(_ linea: String) {
        crearCarpeta()
        let url = archivoDelDia()
        guard let datos = linea.data(using: .utf8) else { return }
        if let h = try? FileHandle(forWritingTo: url) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: datos)
        } else {
            try? datos.write(to: url)
        }
    }

    private static func crearCarpeta() {
        try? FileManager.default.createDirectory(at: carpetaNotas, withIntermediateDirectories: true)
    }
}
