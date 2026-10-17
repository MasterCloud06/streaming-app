import SwiftUI
import SwiftData

/// Pantalla de inicio: quién venció, quién vence pronto y qué cuentas hay que pagar.
struct PendientesView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Cliente> { $0.activo }, sort: \Cliente.fechaVencimiento) private var clientes: [Cliente]
    @Query private var cuentas: [Cuenta]
    @AppStorage("diasAviso") private var diasAviso = 3
    @State private var confirmarPago: Cuenta?

    private var vigentes: [Cliente] { clientes.filter { $0.cuenta?.activa == true } }
    private var vencidos: [Cliente] { vigentes.filter { $0.diasRestantes < 0 } }
    private var porVencer: [Cliente] { vigentes.filter { (0...diasAviso).contains($0.diasRestantes) } }
    private var porPagar: [Cuenta] {
        cuentas.filter { c in c.activa && c.fechaPago.map { Fechas.diasHasta($0) <= diasAviso } == true }
            .sorted { ($0.fechaPago ?? .distantFuture) < ($1.fechaPago ?? .distantFuture) }
    }
    private var cuposLibres: Int {
        cuentas.filter(\.activa).flatMap(\.perfiles).reduce(0) { $0 + $1.libres }
    }

    var body: some View {
        NavigationStack {
            List {
                if vencidos.isEmpty && porVencer.isEmpty && porPagar.isEmpty {
                    ContentUnavailableView("Todo al día", systemImage: "checkmark.seal",
                                           description: Text("Nadie vence en los próximos \(diasAviso) días."))
                        .listRowBackground(Color.clear)
                }

                if !vencidos.isEmpty {
                    Section {
                        ForEach(vencidos) { filaCliente($0) }
                    } header: {
                        Label("Vencidos (\(vencidos.count))", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                if !porVencer.isEmpty {
                    Section {
                        ForEach(porVencer) { filaCliente($0) }
                    } header: {
                        Label("Vencen en \(diasAviso) días o menos", systemImage: "clock")
                    } footer: {
                        Text("Desliza → si renovó, ← si no renovó. Mantén presionado para más opciones.")
                    }
                }

                if !porPagar.isEmpty {
                    Section("Cuentas por pagar") {
                        ForEach(porPagar) { c in
                            NavigationLink(value: c) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(c.plataforma).font(.headline)
                                        Spacer()
                                        if let p = c.fechaPago { BadgeDias(dias: Fechas.diasHasta(p)) }
                                    }
                                    Text(c.correo).font(.subheadline).foregroundStyle(.secondary)
                                    Text("\(Fechas.larga(c.fechaPago)) · \(c.tarjeta.isEmpty ? "sin tarjeta" : c.tarjeta)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button { confirmarPago = c } label: { Label("Pagué", systemImage: "creditcard") }
                                    .tint(.green)
                            }
                        }
                    }
                }

                if cuposLibres > 0 {
                    Section {
                        Label("\(cuposLibres) lugar\(cuposLibres == 1 ? "" : "es") libre\(cuposLibres == 1 ? "" : "s") para vender",
                              systemImage: "person.badge.plus")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Pendientes")
            .navigationDestination(for: Cuenta.self) { CuentaDetalleView(cuenta: $0) }
            .navigationDestination(for: Cliente.self) { ClienteDetalleView(cliente: $0) }
            .confirmationDialog("¿Pagaste la cuenta?", isPresented: Binding(
                get: { confirmarPago != nil }, set: { if !$0 { confirmarPago = nil } }), titleVisibility: .visible
            ) {
                Button("Sí, pasar el pago al próximo mes") {
                    if let c = confirmarPago { Acciones.pagarCuenta(ctx, c) }
                }
            } message: {
                if let c = confirmarPago { Text("\(c.plataforma) · \(c.correo)") }
            }
        }
    }

    private func filaCliente(_ c: Cliente) -> some View {
        NavigationLink(value: c) { ClienteFila(cliente: c, mostrarCuenta: true) }
            .accionesCliente(c)
    }
}
