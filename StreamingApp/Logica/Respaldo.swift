import Foundation
import SwiftData

/// Respaldo completo en JSON. Como todo vive solo en el iPhone, conviene guardarlo
/// de vez en cuando en iCloud Drive o mandártelo por WhatsApp.
@MainActor
enum Respaldo {
    struct ClienteR: Codable {
        var telefono: String; var nombre: String; var fechaVencimiento: Date
        var activo: Bool; var dispositivos: [String]; var creado: Date
    }
    struct PerfilR: Codable { var posicion: Int; var nombre: String; var maxClientes: Int; var clientes: [ClienteR] }
    struct CuentaR: Codable {
        var plataforma: String; var correo: String; var contrasena: String
        var fechaPago: Date?; var banco: String; var ultimos4: String; var fechaCierreSesion: Date?
        var activa: Bool; var notas: String; var creado: Date; var perfiles: [PerfilR]
    }
    struct RegistroR: Codable { var fecha: Date; var accion: String; var descripcion: String }
    struct Archivo: Codable { var version = 1; var generado: Date; var cuentas: [CuentaR]; var historial: [RegistroR] }

    enum ErrorRespaldo: LocalizedError {
        case formato
        var errorDescription: String? { "El archivo no es un respaldo válido de esta app." }
    }

    /// Escribe el respaldo en Documentos/Respaldos y devuelve la URL para compartir.
    static func crear(_ ctx: ModelContext) throws -> URL {
        let cuentas = try ctx.fetch(FetchDescriptor<Cuenta>())
        let historial = try ctx.fetch(FetchDescriptor<Registro>(sortBy: [SortDescriptor(\.fecha)]))
        let archivo = Archivo(
            generado: .now,
            cuentas: cuentas.map { c in
                CuentaR(plataforma: c.plataforma, correo: c.correo, contrasena: c.contrasena, fechaPago: c.fechaPago,
                        banco: c.banco, ultimos4: c.ultimos4, fechaCierreSesion: c.fechaCierreSesion,
                        activa: c.activa, notas: c.notas, creado: c.creado,
                        perfiles: c.perfilesOrdenados.map { p in
                            PerfilR(posicion: p.posicion, nombre: p.nombre, maxClientes: p.maxClientes,
                                    clientes: p.clientes.map {
                                        ClienteR(telefono: $0.telefono, nombre: $0.nombre, fechaVencimiento: $0.fechaVencimiento,
                                                 activo: $0.activo, dispositivos: $0.dispositivos, creado: $0.creado)
                                    })
                        })
            },
            historial: historial.map { RegistroR(fecha: $0.fecha, accion: $0.accion, descripcion: $0.descripcion) })

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let carpeta = Bitacora.carpetaDocumentos.appendingPathComponent("Respaldos", isDirectory: true)
        try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        let url = carpeta.appendingPathComponent("respaldo-\(Fechas.iso(.now))-\(Fechas.hora(.now).replacingOccurrences(of: ":", with: "")).json")
        try enc.encode(archivo).write(to: url, options: .atomic)
        return url
    }

    /// Reemplaza TODOS los datos por los del respaldo. Devuelve cuántas cuentas se restauraron.
    static func restaurar(desde url: URL, en ctx: ModelContext) throws -> Int {
        let acceso = url.startAccessingSecurityScopedResource()
        defer { if acceso { url.stopAccessingSecurityScopedResource() } }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let archivo = try? dec.decode(Archivo.self, from: Data(contentsOf: url)) else { throw ErrorRespaldo.formato }

        for c in try ctx.fetch(FetchDescriptor<Cuenta>()) { ctx.delete(c) }
        for r in try ctx.fetch(FetchDescriptor<Registro>()) { ctx.delete(r) }

        for c in archivo.cuentas {
            let cuenta = Cuenta(plataforma: c.plataforma, correo: c.correo, contrasena: c.contrasena, fechaPago: c.fechaPago,
                                banco: c.banco, ultimos4: c.ultimos4, fechaCierreSesion: c.fechaCierreSesion, notas: c.notas)
            cuenta.activa = c.activa
            cuenta.creado = c.creado
            ctx.insert(cuenta)
            for p in c.perfiles {
                let perfil = Perfil(posicion: p.posicion, nombre: p.nombre, maxClientes: p.maxClientes)
                cuenta.perfiles.append(perfil)
                for cl in p.clientes {
                    let cliente = Cliente(telefono: cl.telefono, nombre: cl.nombre, fechaVencimiento: cl.fechaVencimiento,
                                          dispositivos: cl.dispositivos)
                    cliente.activo = cl.activo
                    cliente.creado = cl.creado
                    perfil.clientes.append(cliente)
                }
            }
        }
        for r in archivo.historial {
            let reg = Registro(accion: r.accion, descripcion: r.descripcion)
            reg.fecha = r.fecha
            ctx.insert(reg)
        }
        Bitacora.registrar(ctx, "RESTAURAR",
                           "Se restauró el respaldo del \(Fechas.corta(archivo.generado)) (\(archivo.cuentas.count) cuentas)")
        return archivo.cuentas.count
    }
}
