import SwiftUI
import SwiftData
import UIKit

/// Una cuenta con sus 5 perfiles y las personas de cada perfil.
struct CuentaDetalleView: View {
    @Bindable var cuenta: Cuenta
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var verContrasena = false
    @State private var perfilParaAgregar: Perfil?
    @State private var editar = false
    @State private var confirmarPago = false
    @State private var confirmarCierre = false
    @State private var confirmarEliminar = false
    @State private var copiado = false

    var body: some View {
        List {
            Section {
                fila("Correo", cuenta.correo, copiable: true)
                HStack {
                    Text("Contraseña").foregroundStyle(.secondary)
                    Spacer()
                    Text(verContrasena ? cuenta.contrasena : String(repeating: "•", count: 8))
                        .font(.body.monospaced())
                    Button { verContrasena.toggle() } label: {
                        Image(systemName: verContrasena ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    Button { copiar(cuenta.contrasena) } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.borderless)
                }
                HStack {
                    Text("Pago").foregroundStyle(.secondary)
                    Spacer()
                    Text(Fechas.larga(cuenta.fechaPago))
                    if let p = cuenta.fechaPago { BadgeDias(dias: Fechas.diasHasta(p)) }
                }
                fila("Tarjeta", cuenta.tarjeta.isEmpty ? "—" : cuenta.tarjeta)
                fila("Sesiones cerradas", Fechas.corta(cuenta.fechaCierreSesion))
                if !cuenta.notas.isEmpty { fila("Notas", cuenta.notas) }
            }

            Section {
                Button { confirmarPago = true } label: {
                    Label("Pagué la cuenta", systemImage: "creditcard.fill")
                }
                Button { confirmarCierre = true } label: {
                    Label("Cerré sesión en todos los perfiles", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            ForEach(cuenta.perfilesOrdenados) { perfil in
                Section {
                    ForEach(perfil.activos) { cl in
                        NavigationLink(value: cl) { ClienteFila(cliente: cl) }
                            .accionesCliente(cl)
                    }
                    if perfil.libres > 0 {
                        Button { perfilParaAgregar = perfil } label: {
                            Label("Agregar persona", systemImage: "person.badge.plus")
                        }
                    }
                } header: {
                    HStack {
                        Text("\(perfil.posicion). \(perfil.nombre)")
                        Spacer()
                        Text("\(perfil.activos.count)/\(perfil.maxClientes)")
                            .foregroundStyle(perfil.libres > 0 ? .green : .secondary)
                    }
                }
            }

            if !cuenta.exClientes.isEmpty {
                Section {
                    ForEach(cuenta.exClientes) { cl in
                        NavigationLink(value: cl) {
                            VStack(alignment: .leading) {
                                Text(cl.telefono).font(.body.monospacedDigit())
                                Text("\(cl.perfil?.nombre ?? "") · venció \(Fechas.larga(cl.fechaVencimiento))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button { Acciones.renovar(ctx, cl, meses: 1, desdeHoy: true) } label: {
                                Label("Volvió", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.green)
                        }
                    }
                } header: {
                    Text("No renovaron")
                } footer: {
                    Text("Desliza → si alguien vuelve: se reactiva por 1 mes desde hoy.")
                }
            }
        }
        .navigationTitle(cuenta.plataforma)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { editar = true } label: { Label("Editar cuenta y perfiles", systemImage: "pencil") }
                    Button { copiar(Formato.texto([cuenta])) } label: {
                        Label("Copiar en formato de Notas", systemImage: "doc.on.clipboard")
                    }
                    ShareLink(item: Formato.texto([cuenta])) { Label("Compartir", systemImage: "square.and.arrow.up") }
                    Divider()
                    Button {
                        cuenta.activa.toggle()
                        Bitacora.registrar(ctx, "EDITAR_CUENTA",
                                           "\(cuenta.plataforma) \(cuenta.correo): \(cuenta.activa ? "reactivada" : "desactivada")")
                    } label: {
                        Label(cuenta.activa ? "Desactivar cuenta" : "Reactivar cuenta",
                              systemImage: cuenta.activa ? "pause.circle" : "play.circle")
                    }
                    Button(role: .destructive) { confirmarEliminar = true } label: {
                        Label("Eliminar cuenta", systemImage: "trash")
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .overlay(alignment: .bottom) {
            if copiado {
                Text("Copiado").font(.subheadline.bold())
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $perfilParaAgregar) { NuevaPersonaView(perfil: $0) }
        .sheet(isPresented: $editar) { CuentaFormView(cuenta: cuenta) }
        .confirmationDialog("¿Pagaste \(cuenta.plataforma)?", isPresented: $confirmarPago, titleVisibility: .visible) {
            Button("Sí, próximo pago: \(Fechas.larga(Fechas.sumarMeses(cuenta.fechaPago ?? Fechas.hoy(), 1)))") {
                Acciones.pagarCuenta(ctx, cuenta)
            }
        }
        .confirmationDialog("¿Cerraste sesión en todos los perfiles hoy?", isPresented: $confirmarCierre,
                            titleVisibility: .visible) {
            Button("Sí, registrar \(Fechas.corta(.now))") { Acciones.cerrarSesiones(ctx, cuenta) }
        }
        .confirmationDialog("¿Eliminar esta cuenta?", isPresented: $confirmarEliminar, titleVisibility: .visible) {
            Button("Eliminar con todos sus perfiles y personas", role: .destructive) {
                // Primero se cierra la pantalla para no mostrar una cuenta ya borrada
                let c = cuenta
                dismiss()
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    Acciones.eliminarCuenta(ctx, c)
                }
            }
        } message: {
            Text("No se puede deshacer. Si solo dejaste de usarla, mejor desactívala.")
        }
    }

    private func fila(_ titulo: String, _ valor: String, copiable: Bool = false) -> some View {
        HStack {
            Text(titulo).foregroundStyle(.secondary)
            Spacer()
            Text(valor).multilineTextAlignment(.trailing).textSelection(.enabled)
            if copiable {
                Button { copiar(valor) } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless)
            }
        }
    }

    private func copiar(_ texto: String) {
        UIPasteboard.general.string = texto
        withAnimation { copiado = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { copiado = false }
        }
    }
}
