import SwiftUI
import SwiftData
import UIKit

/// Detalle de una persona: renovar, dispositivos, mover de perfil, contacto.
struct ClienteDetalleView: View {
    @Bindable var cliente: Cliente
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Query private var cuentas: [Cuenta]

    @State private var telefono = ""
    @State private var nombre = ""
    @State private var nuevoVencimiento = Date.now
    @State private var editandoFecha = false
    @State private var nuevosDispositivos: [String] = []
    @State private var agregandoDispositivos = false
    @State private var confirmarNoRenovo = false
    @State private var confirmarEliminar = false

    private var datosCambiados: Bool {
        telefono != cliente.telefono || nombre != cliente.nombre
    }

    /// Perfiles con lugar libre de la misma plataforma (para mover).
    private var destinos: [Perfil] {
        cuentas.filter { $0.activa && $0.plataforma == cliente.cuenta?.plataforma }
            .flatMap(\.perfilesOrdenados)
            .filter { $0 != cliente.perfil && $0.libres > 0 }
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Cuenta", value: "\(cliente.cuenta?.plataforma ?? "") · \(cliente.cuenta?.correo ?? "")")
                LabeledContent("Perfil", value: cliente.perfil?.nombre ?? "—")
                HStack {
                    Text("Vence")
                    Spacer()
                    Text(Fechas.larga(cliente.fechaVencimiento, conAnio: true))
                    if cliente.activo { BadgeDias(dias: cliente.diasRestantes) }
                }
                if !cliente.activo {
                    Label("No renovó · fuera de la lista", systemImage: "xmark.circle").foregroundStyle(.red)
                }
            }

            Section("Renovación") {
                if cliente.activo {
                    Button { Acciones.renovar(ctx, cliente) } label: {
                        Label("Renovó 1 mes → \(Fechas.larga(Fechas.sumarMeses(cliente.fechaVencimiento, 1)))",
                              systemImage: "checkmark.circle.fill")
                    }
                    .tint(.green)
                    Menu {
                        ForEach([2, 3, 6, 12], id: \.self) { m in
                            Button("\(m) meses → \(Fechas.larga(Fechas.sumarMeses(cliente.fechaVencimiento, m)))") {
                                Acciones.renovar(ctx, cliente, meses: m)
                            }
                        }
                        Button("1 mes desde hoy → \(Fechas.larga(Fechas.sumarMeses(Fechas.hoy(), 1)))") {
                            Acciones.renovar(ctx, cliente, meses: 1, desdeHoy: true)
                        }
                    } label: {
                        Label("Renovó por más tiempo…", systemImage: "calendar.badge.plus")
                    }
                    Button {
                        nuevoVencimiento = cliente.fechaVencimiento
                        editandoFecha = true
                    } label: {
                        Label("Cambiar fecha a mano", systemImage: "calendar")
                    }
                    Button(role: .destructive) { confirmarNoRenovo = true } label: {
                        Label("No renovó", systemImage: "xmark.circle.fill")
                    }
                } else {
                    Button { Acciones.renovar(ctx, cliente, meses: 1, desdeHoy: true) } label: {
                        Label("Volvió: reactivar 1 mes desde hoy", systemImage: "arrow.uturn.backward.circle.fill")
                    }
                }
            }

            Section {
                ForEach(Array(cliente.dispositivos.enumerated()), id: \.offset) { item in
                    Label(item.element, systemImage: icono(item.element))
                }
                .onDelete { indices in
                    for i in indices.sorted(by: >) { Acciones.quitarDispositivo(ctx, cliente, en: i) }
                }
                Button {
                    nuevosDispositivos = []
                    agregandoDispositivos = true
                } label: {
                    Label("Agregar dispositivo", systemImage: "plus.circle")
                }
            } header: {
                Text("Dispositivos (\(cliente.dispositivos.count))")
            } footer: {
                if !cliente.dispositivos.isEmpty { Text("Desliza ← sobre un dispositivo para quitarlo.") }
            }

            Section("Contacto") {
                if let url = Formato.enlaceWhatsApp(cliente) {
                    Button { openURL(url) } label: { Label("Recordar pago por WhatsApp", systemImage: "message.fill") }
                }
                if let cuenta = cliente.cuenta, let url = Formato.enlaceWhatsApp(cliente, mensaje: Formato.datosAcceso(cliente)) {
                    Button { openURL(url) } label: {
                        Label("Enviar datos de \(cuenta.plataforma) por WhatsApp", systemImage: "paperplane.fill")
                    }
                }
                Button { UIPasteboard.general.string = Formato.datosAcceso(cliente) } label: {
                    Label("Copiar datos de acceso", systemImage: "doc.on.doc")
                }
            }

            Section("Datos") {
                TextField("Teléfono", text: $telefono).keyboardType(.phonePad)
                TextField("Nombre (opcional)", text: $nombre)
                if datosCambiados {
                    Button("Guardar cambios") { Acciones.editarCliente(ctx, cliente, telefono: telefono, nombre: nombre) }
                }
            }

            if cliente.activo {
                Section {
                    if destinos.isEmpty {
                        Text("No hay perfiles con lugar libre en \(cliente.cuenta?.plataforma ?? "esta plataforma").")
                            .foregroundStyle(.secondary)
                    } else {
                        Menu {
                            ForEach(destinos) { p in
                                Button("\(p.cuenta?.correo ?? "") › \(p.nombre) (\(p.libres) libre\(p.libres == 1 ? "" : "s"))") {
                                    Acciones.mover(ctx, cliente, a: p)
                                }
                            }
                        } label: {
                            Label("Mover a otro perfil", systemImage: "arrow.left.arrow.right")
                        }
                    }
                }
            }

            Section {
                Button("Eliminar (si se cargó por error)", role: .destructive) { confirmarEliminar = true }
            }
        }
        .navigationTitle(cliente.telefono)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { telefono = cliente.telefono; nombre = cliente.nombre }
        .onChange(of: cliente.telefono) { _, nuevo in telefono = nuevo }
        .sheet(isPresented: $editandoFecha) {
            NavigationStack {
                Form {
                    DatePicker("Vence", selection: $nuevoVencimiento, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, Locale(identifier: "es_BO"))
                }
                .navigationTitle("Fecha de vencimiento")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { editandoFecha = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Guardar") {
                            Acciones.cambiarVencimiento(ctx, cliente, a: nuevoVencimiento)
                            editandoFecha = false
                        }
                    }
                }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $agregandoDispositivos) {
            NavigationStack {
                Form { SelectorDispositivos(seleccion: $nuevosDispositivos) }
                    .navigationTitle("Agregar dispositivo")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { agregandoDispositivos = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Agregar") {
                                Acciones.agregarDispositivos(ctx, cliente, nuevosDispositivos)
                                agregandoDispositivos = false
                            }
                            .disabled(nuevosDispositivos.isEmpty)
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog("¿\(cliente.telefono) no renovó?", isPresented: $confirmarNoRenovo, titleVisibility: .visible) {
            Button("Sí, quitar de la lista", role: .destructive) { Acciones.noRenovo(ctx, cliente) }
        }
        .confirmationDialog("¿Eliminar a \(cliente.telefono)?", isPresented: $confirmarEliminar, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                let c = cliente
                dismiss()
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    Acciones.eliminarCliente(ctx, c)
                }
            }
        } message: {
            Text("Si simplemente no renovó, usa \"No renovó\" para conservar su historial.")
        }
    }

    private func icono(_ d: String) -> String {
        let t = d.lowercased()
        if t.contains("tv") { return "tv" }
        if t.contains("cel") || t.contains("phone") { return "iphone" }
        if t.contains("tablet") || t.contains("ipad") { return "ipad" }
        if t.contains("laptop") || t.contains("pc") || t.contains("compu") { return "laptopcomputer" }
        if t.contains("consola") || t.contains("play") || t.contains("xbox") { return "gamecontroller" }
        return "display"
    }
}
