import Foundation
import SwiftData

/// Una cuenta de una plataforma (Netflix, Disney+, ...).
@Model
final class Cuenta {
    var plataforma: String
    var correo: String
    var contrasena: String
    /// Día en que se debe pagar la cuenta.
    var fechaPago: Date?
    /// Banco de la tarjeta con la que se paga (ej. "Banco Sol").
    var banco: String
    /// Solo los últimos 4 dígitos de la tarjeta.
    var ultimos4: String
    /// Última vez que se cerró sesión en todos los perfiles.
    var fechaCierreSesion: Date?
    var activa: Bool
    var notas: String
    var creado: Date

    @Relationship(deleteRule: .cascade, inverse: \Perfil.cuenta)
    var perfiles: [Perfil] = []

    init(plataforma: String, correo: String, contrasena: String, fechaPago: Date? = nil,
         banco: String = "", ultimos4: String = "", fechaCierreSesion: Date? = nil, notas: String = "") {
        self.plataforma = plataforma
        self.correo = correo
        self.contrasena = contrasena
        self.fechaPago = fechaPago
        self.banco = banco
        self.ultimos4 = ultimos4
        self.fechaCierreSesion = fechaCierreSesion
        self.activa = true
        self.notas = notas
        self.creado = .now
    }

    var perfilesOrdenados: [Perfil] { perfiles.sorted { $0.posicion < $1.posicion } }

    var tarjeta: String {
        [banco, ultimos4].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var ocupados: Int { perfiles.reduce(0) { $0 + $1.activos.count } }
    var capacidad: Int { perfiles.reduce(0) { $0 + $1.maxClientes } }

    /// Personas que ya no renovaron (para poder reactivarlas).
    var exClientes: [Cliente] {
        perfiles.flatMap { $0.clientes.filter { !$0.activo } }
            .sorted { $0.actualizado > $1.actualizado }
    }
}

/// Uno de los perfiles de la cuenta (Marianela, Veronica, ...). Lo comparten hasta `maxClientes` personas.
@Model
final class Perfil {
    var posicion: Int
    var nombre: String
    var maxClientes: Int
    var cuenta: Cuenta?

    @Relationship(deleteRule: .cascade, inverse: \Cliente.perfil)
    var clientes: [Cliente] = []

    init(posicion: Int, nombre: String, maxClientes: Int = 2) {
        self.posicion = posicion
        self.nombre = nombre
        self.maxClientes = maxClientes
    }

    var activos: [Cliente] {
        clientes.filter(\.activo).sorted { $0.fechaVencimiento < $1.fechaVencimiento }
    }
    var libres: Int { max(0, maxClientes - activos.count) }
}

/// Persona que paga por un lugar en un perfil.
@Model
final class Cliente {
    var telefono: String
    var nombre: String
    var fechaVencimiento: Date
    /// `false` = no renovó (sale de la lista pero queda guardado).
    var activo: Bool
    var dispositivos: [String]
    var creado: Date
    var actualizado: Date
    var perfil: Perfil?

    init(telefono: String, nombre: String = "", fechaVencimiento: Date, dispositivos: [String] = []) {
        self.telefono = telefono
        self.nombre = nombre
        self.fechaVencimiento = fechaVencimiento
        self.activo = true
        self.dispositivos = dispositivos
        self.creado = .now
        self.actualizado = .now
    }

    var cuenta: Cuenta? { perfil?.cuenta }
    var diasRestantes: Int { Fechas.diasHasta(fechaVencimiento) }

    /// "Netflix prueba@gmail.com › Camila › +591..."
    var etiqueta: String {
        let base = "\(cuenta?.plataforma ?? "?") \(cuenta?.correo ?? "") › \(perfil?.nombre ?? "?") › \(telefono)"
        return nombre.isEmpty ? base : "\(base) (\(nombre))"
    }
}

/// Historial de cambios (también se escribe en los blocs de notas .txt).
@Model
final class Registro {
    var fecha: Date
    var accion: String
    var descripcion: String

    init(accion: String, descripcion: String) {
        self.fecha = .now
        self.accion = accion
        self.descripcion = descripcion
    }
}
