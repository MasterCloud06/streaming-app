import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

/// Pestaña "Más": importar desde Notas, exportar, respaldo y avisos.
struct AjustesView: View {
    @Environment(\.modelContext) private var ctx
    @Query private var cuentas: [Cuenta]
    @AppStorage("diasAviso") private var diasAviso = 3
    @AppStorage(Notificaciones.claveActivas) private var avisosActivos = true
    @AppStorage(Notificaciones.claveHora) private var horaAvisos = 9

    @State private var respaldoURL: URL?
    @State private var elegirRespaldo = false
    @State private var archivoRestaurar: URL?
    @State private var mensaje: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Pasar datos") {
                    NavigationLink {
                        ImportarView()
                    } label: {
                        Label("Importar desde Notas del iPhone", systemImage: "square.and.arrow.down")
                    }
                    ShareLink(item: Formato.texto(cuentas.filter(\.activa))) {
                        Label("Exportar todo en formato de Notas", systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    Stepper("Avisar \(diasAviso) día\(diasAviso == 1 ? "" : "s") antes", value: $diasAviso, in: 0...15)
                    Toggle("Notificaciones", isOn: $avisosActivos)
                    if avisosActivos {
                        Picker("Hora del aviso", selection: $horaAvisos) {
                            ForEach(6...22, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                        }
                    }
                } header: {
                    Text("Avisos")
                } footer: {
                    Text("Te avisa el día que vence cada persona y un día antes de pagar cada cuenta. Funciona sin internet.")
                }

                Section {
                    Button {
                        do { respaldoURL = try Respaldo.crear(ctx) } catch { mensaje = error.localizedDescription }
                    } label: {
                        Label("Crear respaldo", systemImage: "externaldrive.badge.plus")
                    }
                    if let url = respaldoURL {
                        ShareLink(item: url) {
                            Label("Guardar o enviar \(url.lastPathComponent)", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button(role: .destructive) { elegirRespaldo = true } label: {
                        Label("Restaurar un respaldo…", systemImage: "arrow.counterclockwise")
                    }
                } header: {
                    Text("Respaldo")
                } footer: {
                    Text("Todo se guarda solo en este iPhone. Crea un respaldo de vez en cuando y guárdalo en iCloud Drive o envíatelo por WhatsApp; si cambias o pierdes el teléfono, lo restauras aquí.")
                }

                Section {
                    LabeledContent("Cuentas", value: "\(cuentas.filter(\.activa).count)")
                    LabeledContent("Personas activas",
                                   value: "\(cuentas.filter(\.activa).reduce(0) { $0 + $1.ocupados })")
                } footer: {
                    Text("Los blocs de notas de cambios están en Archivos › En mi iPhone › Cuentas Streaming › Notas.")
                }
            }
            .navigationTitle("Más")
            .onChange(of: avisosActivos) { _, activo in
                Task {
                    if activo { _ = await Notificaciones.pedirPermiso() }
                    Notificaciones.reprogramar(ctx)
                }
            }
            .onChange(of: horaAvisos) { _, _ in Notificaciones.reprogramar(ctx) }
            .fileImporter(isPresented: $elegirRespaldo, allowedContentTypes: [.json]) { resultado in
                if case .success(let url) = resultado { archivoRestaurar = url }
            }
            .confirmationDialog("¿Restaurar este respaldo?", isPresented: Binding(
                get: { archivoRestaurar != nil }, set: { if !$0 { archivoRestaurar = nil } }), titleVisibility: .visible
            ) {
                Button("Reemplazar todos mis datos", role: .destructive) {
                    guard let url = archivoRestaurar else { return }
                    do {
                        let n = try Respaldo.restaurar(desde: url, en: ctx)
                        mensaje = "Se restauraron \(n) cuentas."
                    } catch {
                        mensaje = error.localizedDescription
                    }
                }
            } message: {
                Text("Se borrará lo que hay ahora en la app y se cargará el respaldo. Si no estás seguro, crea primero un respaldo de lo actual.")
            }
            .alert(mensaje ?? "", isPresented: Binding(get: { mensaje != nil }, set: { if !$0 { mensaje = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }
}

/// Pegar el texto de la nota → revisar → importar.
struct ImportarView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var texto = ""
    @State private var resultado: Importador.Resultado?
    @State private var resumen: String?

    var body: some View {
        Form {
            Section {
                TextEditor(text: $texto)
                    .frame(minHeight: 200)
                    .font(.system(.footnote, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    if let t = UIPasteboard.general.string { texto = t }
                } label: { Label("Pegar", systemImage: "doc.on.clipboard") }
            } header: {
                Text("Texto de la nota")
            } footer: {
                Text("En Notas: mantén presionado → Seleccionar todo → Copiar. Luego toca Pegar.")
            }

            Section {
                Button("Revisar") { resultado = Importador.analizar(texto) }
                    .disabled(texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let r = resultado {
                Section("Se encontró") {
                    LabeledContent("Plataformas", value: "\(r.plataformas.count)")
                    LabeledContent("Cuentas", value: "\(r.totalCuentas)")
                    LabeledContent("Perfiles", value: "\(r.totalPerfiles)")
                    LabeledContent("Personas", value: "\(r.totalPersonas)")
                }
                ForEach(Array(r.plataformas.enumerated()), id: \.offset) { item in
                    Section(item.element.nombre) {
                        ForEach(Array(item.element.cuentas.enumerated()), id: \.offset) { c in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(c.element.correo).font(.subheadline.bold())
                                Text("Pago \(Fechas.larga(c.element.fechaPago)) · \(c.element.banco) \(c.element.ultimos4)")
                                    .font(.caption).foregroundStyle(.secondary)
                                ForEach(Array(c.element.perfiles.enumerated()), id: \.offset) { p in
                                    Text("\(p.element.nombre): " + p.element.clientes.map {
                                        "\($0.telefono) (\(Fechas.larga($0.vencimiento)))"
                                    }.joined(separator: ", "))
                                    .font(.caption)
                                }
                            }
                        }
                    }
                }
                if !r.avisos.isEmpty {
                    Section("Revisa esto") {
                        ForEach(r.avisos, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) }
                    }
                }
                Section {
                    Button("Importar \(r.totalCuentas) cuenta\(r.totalCuentas == 1 ? "" : "s")") {
                        let res = Importador.guardar(r, en: ctx)
                        resumen = "Se importaron \(res.creadas) cuentas." +
                            (res.omitidas.isEmpty ? "" : "\nYa existían: \(res.omitidas.joined(separator: ", "))")
                    }
                    .disabled(r.totalCuentas == 0)
                }
            }
        }
        .navigationTitle("Importar desde Notas")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Listo", isPresented: Binding(get: { resumen != nil }, set: { if !$0 { resumen = nil; dismiss() } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resumen ?? "")
        }
    }
}
