import SwiftUI
import SwiftData

/// Todas las cuentas agrupadas por plataforma. La búsqueda encuentra por correo, plataforma o teléfono.
struct CuentasView: View {
    @Query(sort: [SortDescriptor(\Cuenta.plataforma), SortDescriptor(\Cuenta.correo)]) private var cuentas: [Cuenta]
    @State private var busqueda = ""
    @State private var mostrarNueva = false
    @State private var mostrarInactivas = false

    private var filtradas: [Cuenta] {
        let q = busqueda.trimmingCharacters(in: .whitespaces).lowercased()
        let digitos = q.filter(\.isNumber)
        return cuentas.filter { c in
            guard c.activa || mostrarInactivas else { return false }
            guard !q.isEmpty else { return true }
            if c.correo.lowercased().contains(q) || c.plataforma.lowercased().contains(q) { return true }
            return c.perfiles.contains { p in
                p.nombre.lowercased().contains(q) ||
                p.activos.contains { cl in
                    cl.nombre.lowercased().contains(q) || (digitos.count >= 3 && cl.telefono.filter(\.isNumber).contains(digitos))
                }
            }
        }
    }

    private var plataformas: [(String, [Cuenta])] {
        Dictionary(grouping: filtradas, by: \.plataforma).sorted { $0.key.lowercased() < $1.key.lowercased() }
            .map { ($0.key, $0.value) }
    }

    /// Personas que coinciden con la búsqueda por teléfono o nombre (para ir directo a ellas).
    private var personasEncontradas: [Cliente] {
        let q = busqueda.trimmingCharacters(in: .whitespaces).lowercased()
        let digitos = q.filter(\.isNumber)
        guard q.count >= 3 else { return [] }
        return cuentas.filter(\.activa).flatMap(\.perfiles).flatMap(\.activos).filter {
            (digitos.count >= 3 && $0.telefono.filter(\.isNumber).contains(digitos)) || $0.nombre.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if cuentas.isEmpty {
                    ContentUnavailableView {
                        Label("Sin cuentas", systemImage: "rectangle.stack.badge.plus")
                    } description: {
                        Text("Agrega una cuenta con + o importa tu nota desde la pestaña Más.")
                    }
                    .listRowBackground(Color.clear)
                }

                if !personasEncontradas.isEmpty {
                    Section("Personas") {
                        ForEach(personasEncontradas) { cl in
                            NavigationLink(value: cl) { ClienteFila(cliente: cl, mostrarCuenta: true) }
                                .accionesCliente(cl)
                        }
                    }
                }

                ForEach(plataformas, id: \.0) { grupo in
                    Section(grupo.0) {
                        ForEach(grupo.1) { c in
                            NavigationLink(value: c) { CuentaFila(cuenta: c) }
                        }
                    }
                }
            }
            .navigationTitle("Cuentas")
            .searchable(text: $busqueda, prompt: "Correo, plataforma o teléfono")
            .navigationDestination(for: Cuenta.self) { CuentaDetalleView(cuenta: $0) }
            .navigationDestination(for: Cliente.self) { ClienteDetalleView(cliente: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { mostrarNueva = true } label: { Label("Nueva cuenta", systemImage: "plus") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Toggle("Mostrar cuentas desactivadas", isOn: $mostrarInactivas)
                    } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                }
            }
            .sheet(isPresented: $mostrarNueva) { CuentaFormView(cuenta: nil) }
        }
    }
}

struct CuentaFila: View {
    let cuenta: Cuenta

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(cuenta.correo).font(.body).lineLimit(1)
                Spacer()
                Text("\(cuenta.ocupados)/\(cuenta.capacidad)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(cuenta.ocupados < cuenta.capacidad ? .green : .secondary)
            }
            HStack(spacing: 8) {
                Label("Pago \(Fechas.larga(cuenta.fechaPago))", systemImage: "creditcard")
                if let p = cuenta.fechaPago, Fechas.diasHasta(p) <= 3 { BadgeDias(dias: Fechas.diasHasta(p)) }
            }
            .font(.caption).foregroundStyle(.secondary)
            if !cuenta.activa {
                Text("Desactivada").font(.caption2.bold()).foregroundStyle(.red)
            }
        }
    }
}
