import Foundation
import SwiftData

/// Todas las acciones que cambian datos pasan por aquí para quedar en la bitácora.
@MainActor
enum Acciones {

    // MARK: - Personas

    static func nuevoCliente(_ ctx: ModelContext, perfil: Perfil, telefono: String, nombre: String,
                             vencimiento: Date, dispositivos: [String]) {
        let tel = Importador.normalizarTelefono(telefono) ?? telefono.trimmingCharacters(in: .whitespaces)
        let cl = Cliente(telefono: tel, nombre: nombre.trimmingCharacters(in: .whitespaces),
                         fechaVencimiento: Fechas.dia(vencimiento), dispositivos: dispositivos)
        perfil.clientes.append(cl)
        let disp = dispositivos.isEmpty ? "" : " (\(dispositivos.joined(separator: ", ")))"
        Bitacora.registrar(ctx, "NUEVO_CLIENTE",
                           "\(perfil.cuenta?.plataforma ?? "") \(perfil.cuenta?.correo ?? "") › \(perfil.nombre): " +
                           "se agregó \(tel) hasta el \(Fechas.larga(vencimiento, conAnio: true))\(disp)")
    }

    /// ✅ Renovó: suma meses desde su vencimiento actual (o desde hoy).
    static func renovar(_ ctx: ModelContext, _ cl: Cliente, meses: Int = 1, desdeHoy: Bool = false) {
        let antes = cl.fechaVencimiento
        let nueva = Fechas.sumarMeses(desdeHoy ? Fechas.hoy() : antes, meses)
        let volvio = !cl.activo
        cl.fechaVencimiento = nueva
        cl.activo = true
        cl.actualizado = .now
        Bitacora.registrar(ctx, "RENOVO",
                           "\(cl.etiqueta): \(volvio ? "volvió y " : "")renovó \(meses) mes\(meses == 1 ? "" : "es"). " +
                           "\(Fechas.larga(antes, conAnio: true)) → \(Fechas.larga(nueva, conAnio: true))")
    }

    static func cambiarVencimiento(_ ctx: ModelContext, _ cl: Cliente, a fecha: Date) {
        let antes = cl.fechaVencimiento
        cl.fechaVencimiento = Fechas.dia(fecha)
        cl.actualizado = .now
        Bitacora.registrar(ctx, "EDITAR_CLIENTE",
                           "\(cl.etiqueta): vencimiento \(Fechas.larga(antes, conAnio: true)) → \(Fechas.larga(fecha, conAnio: true))")
    }

    /// ❌ No renovó: sale de la lista y libera el lugar. Queda guardado por si vuelve.
    static func noRenovo(_ ctx: ModelContext, _ cl: Cliente) {
        guard cl.activo else { return }
        cl.activo = false
        cl.actualizado = .now
        Bitacora.registrar(ctx, "NO_RENOVO",
                           "\(cl.etiqueta): no renovó (vencía el \(Fechas.larga(cl.fechaVencimiento, conAnio: true))). Se liberó el lugar.")
    }

    static func editarCliente(_ ctx: ModelContext, _ cl: Cliente, telefono: String, nombre: String) {
        let tel = Importador.normalizarTelefono(telefono) ?? telefono.trimmingCharacters(in: .whitespaces)
        let nom = nombre.trimmingCharacters(in: .whitespaces)
        var cambios: [String] = []
        if tel != cl.telefono { cambios.append("teléfono \(cl.telefono) → \(tel)") }
        if nom != cl.nombre { cambios.append("nombre \(cl.nombre.isEmpty ? "—" : cl.nombre) → \(nom.isEmpty ? "—" : nom)") }
        guard !cambios.isEmpty else { return }
        let etiquetaAntes = cl.etiqueta
        cl.telefono = tel
        cl.nombre = nom
        cl.actualizado = .now
        Bitacora.registrar(ctx, "EDITAR_CLIENTE", "\(etiquetaAntes): \(cambios.joined(separator: "; "))")
    }

    static func mover(_ ctx: ModelContext, _ cl: Cliente, a destino: Perfil) {
        let antes = cl.etiqueta
        cl.perfil = destino
        cl.actualizado = .now
        Bitacora.registrar(ctx, "MOVER_CLIENTE",
                           "\(antes) → \(destino.cuenta?.plataforma ?? "") \(destino.cuenta?.correo ?? "") › \(destino.nombre)")
    }

    static func eliminarCliente(_ ctx: ModelContext, _ cl: Cliente) {
        let etiqueta = cl.etiqueta
        cl.perfil?.clientes.removeAll { $0 == cl }
        ctx.delete(cl)
        Bitacora.registrar(ctx, "ELIMINAR_CLIENTE", "\(etiqueta): eliminado")
    }

    // MARK: - Dispositivos

    static func agregarDispositivos(_ ctx: ModelContext, _ cl: Cliente, _ nombres: [String]) {
        let limpios = nombres.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !limpios.isEmpty else { return }
        cl.dispositivos.append(contentsOf: limpios)
        cl.actualizado = .now
        Bitacora.registrar(ctx, "AGREGAR_DISPOSITIVO", "\(cl.etiqueta): agregó \(limpios.joined(separator: ", "))")
    }

    static func quitarDispositivo(_ ctx: ModelContext, _ cl: Cliente, en indice: Int) {
        guard cl.dispositivos.indices.contains(indice) else { return }
        let nombre = cl.dispositivos.remove(at: indice)
        cl.actualizado = .now
        Bitacora.registrar(ctx, "QUITAR_DISPOSITIVO", "\(cl.etiqueta): quitó \(nombre)")
    }

    // MARK: - Cuentas

    static func pagarCuenta(_ ctx: ModelContext, _ c: Cuenta, meses: Int = 1) {
        let nueva = Fechas.sumarMeses(c.fechaPago ?? Fechas.hoy(), meses)
        c.fechaPago = nueva
        Bitacora.registrar(ctx, "PAGO_CUENTA",
                           "\(c.plataforma) \(c.correo) pagada. Próximo pago: \(Fechas.larga(nueva, conAnio: true))")
    }

    static func cerrarSesiones(_ ctx: ModelContext, _ c: Cuenta, fecha: Date = .now) {
        c.fechaCierreSesion = Fechas.dia(fecha)
        Bitacora.registrar(ctx, "CERRAR_SESIONES",
                           "\(c.plataforma) \(c.correo): se cerró sesión en todos los perfiles el \(Fechas.corta(fecha))")
    }

    struct DatosCuenta {
        var plataforma = ""
        var correo = ""
        var contrasena = ""
        var fechaPago: Date? = nil
        var banco = ""
        var ultimos4 = ""
        var fechaCierreSesion: Date? = nil
        var notas = ""
        /// Nombres de perfiles en orden, con cupos por perfil
        var perfiles: [(nombre: String, cupos: Int)] = []
    }

    static func crearCuenta(_ ctx: ModelContext, _ d: DatosCuenta) {
        let c = Cuenta(plataforma: d.plataforma.trimmingCharacters(in: .whitespaces),
                       correo: d.correo.trimmingCharacters(in: .whitespaces), contrasena: d.contrasena,
                       fechaPago: d.fechaPago.map(Fechas.dia), banco: d.banco.trimmingCharacters(in: .whitespaces),
                       ultimos4: d.ultimos4, fechaCierreSesion: d.fechaCierreSesion.map(Fechas.dia), notas: d.notas)
        ctx.insert(c)
        for (i, p) in d.perfiles.enumerated() {
            c.perfiles.append(Perfil(posicion: i + 1, nombre: p.nombre, maxClientes: p.cupos))
        }
        Bitacora.registrar(ctx, "NUEVA_CUENTA",
                           "\(c.plataforma) \(c.correo) con \(d.perfiles.count) perfiles (\(d.perfiles.map(\.nombre).joined(separator: ", ")))")
    }

    /// Edita la cuenta y sus perfiles. `perfiles` trae (perfil existente o nil si es nuevo, nombre, cupos).
    static func editarCuenta(_ ctx: ModelContext, _ c: Cuenta, _ d: DatosCuenta, perfiles: [(Perfil?, String, Int)],
                             eliminar: [Perfil]) {
        var cambios: [String] = []
        func cambio<T: Equatable>(_ nombre: String, _ antes: T, _ despues: T, _ texto: (T) -> String) {
            if antes != despues { cambios.append("\(nombre): \(texto(antes)) → \(texto(despues))") }
        }
        let pago = d.fechaPago.map(Fechas.dia), cierre = d.fechaCierreSesion.map(Fechas.dia)
        cambio("plataforma", c.plataforma, d.plataforma) { $0 }
        cambio("correo", c.correo, d.correo) { $0 }
        if c.contrasena != d.contrasena { cambios.append("contraseña cambiada") }
        cambio("pago", c.fechaPago, pago) { Fechas.larga($0) }
        cambio("tarjeta", c.tarjeta, [d.banco, d.ultimos4].filter { !$0.isEmpty }.joined(separator: " ")) { $0.isEmpty ? "—" : $0 }
        cambio("cierre de sesiones", c.fechaCierreSesion, cierre) { Fechas.corta($0) }

        c.plataforma = d.plataforma.trimmingCharacters(in: .whitespaces)
        c.correo = d.correo.trimmingCharacters(in: .whitespaces)
        c.contrasena = d.contrasena
        c.fechaPago = pago
        c.banco = d.banco.trimmingCharacters(in: .whitespaces)
        c.ultimos4 = d.ultimos4
        c.fechaCierreSesion = cierre
        c.notas = d.notas

        for p in eliminar {
            cambios.append("perfil \(p.nombre) eliminado")
            c.perfiles.removeAll { $0 == p }
            ctx.delete(p)
        }
        for (i, (perfil, nombre, cupos)) in perfiles.enumerated() {
            if let perfil {
                if perfil.nombre != nombre { cambios.append("perfil \(perfil.nombre) → \(nombre)") }
                if perfil.maxClientes != cupos { cambios.append("cupos de \(nombre): \(perfil.maxClientes) → \(cupos)") }
                perfil.nombre = nombre
                perfil.maxClientes = cupos
                perfil.posicion = i + 1
            } else {
                c.perfiles.append(Perfil(posicion: i + 1, nombre: nombre, maxClientes: cupos))
                cambios.append("nuevo perfil \(nombre)")
            }
        }
        guard !cambios.isEmpty else { return }
        Bitacora.registrar(ctx, "EDITAR_CUENTA", "\(c.plataforma) \(c.correo): \(cambios.joined(separator: "; "))")
    }

    static func eliminarCuenta(_ ctx: ModelContext, _ c: Cuenta) {
        let texto = "\(c.plataforma) \(c.correo) eliminada"
        ctx.delete(c)
        Bitacora.registrar(ctx, "ELIMINAR_CUENTA", texto)
    }
}
