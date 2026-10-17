import SwiftUI
import SwiftData
import UIKit

/// Historial de cambios agrupado por día, más acceso a los blocs de notas .txt.
struct NotasView: View {
    @Query(sort: \Registro.fecha, order: .reverse) private var registros: [Registro]
    @Query private var cuentas: [Cuenta]
    @State private var busqueda = ""

    private var filtrados: [Registro] {
        let q = busqueda.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return registros }
        return registros.filter { $0.descripcion.lowercased().contains(q) || $0.accion.lowercased().contains(q) }
    }

    private var porDia: [(Date, [Registro])] {
        Dictionary(grouping: filtrados) { Fechas.dia($0.fecha) }
            .sorted { $0.key > $1.key }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        TextoView(titulo: "Estado actual", texto: Formato.texto(cuentas.filter(\.activa)))
                    } label: {
                        Label("Estado actual (formato Notas)", systemImage: "doc.text")
                    }
                    NavigationLink {
                        ArchivosNotasView()
                    } label: {
                        Label("Blocs de notas guardados", systemImage: "folder")
                    }
                }

                if registros.isEmpty {
                    ContentUnavailableView("Sin cambios todavía", systemImage: "note.text",
                                           description: Text("Cada renovación, baja o dispositivo nuevo aparecerá aquí."))
                        .listRowBackground(Color.clear)
                }

                ForEach(porDia, id: \.0) { grupo in
                    Section(encabezado(grupo.0)) {
                        ForEach(grupo.1) { r in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(titulo(r.accion)).font(.subheadline.bold()).foregroundStyle(color(r.accion))
                                    Spacer()
                                    Text(Fechas.hora(r.fecha)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                }
                                Text(r.descripcion).font(.subheadline).textSelection(.enabled)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Notas")
            .searchable(text: $busqueda, prompt: "Buscar en el historial")
        }
    }

    private func encabezado(_ d: Date) -> String {
        switch Fechas.diasHasta(d) {
        case 0: return "Hoy"
        case -1: return "Ayer"
        default: return Fechas.larga(d)
        }
    }

    private func titulo(_ accion: String) -> String {
        [
            "RENOVO": "Renovó", "NO_RENOVO": "No renovó", "NUEVO_CLIENTE": "Persona nueva",
            "AGREGAR_DISPOSITIVO": "Dispositivo agregado", "QUITAR_DISPOSITIVO": "Dispositivo quitado",
            "PAGO_CUENTA": "Cuenta pagada", "CERRAR_SESIONES": "Sesiones cerradas", "MOVER_CLIENTE": "Cambio de perfil",
            "EDITAR_CLIENTE": "Persona editada", "ELIMINAR_CLIENTE": "Persona eliminada", "NUEVA_CUENTA": "Cuenta nueva",
            "EDITAR_CUENTA": "Cuenta editada", "ELIMINAR_CUENTA": "Cuenta eliminada", "IMPORTAR": "Importado",
            "RESTAURAR": "Respaldo restaurado",
        ][accion] ?? accion
    }

    private func color(_ accion: String) -> Color {
        switch accion {
        case "RENOVO", "PAGO_CUENTA", "NUEVO_CLIENTE": return .green
        case "NO_RENOVO", "ELIMINAR_CLIENTE", "ELIMINAR_CUENTA": return .red
        case "AGREGAR_DISPOSITIVO", "QUITAR_DISPOSITIVO": return .blue
        default: return .primary
        }
    }
}

/// Lista de los .txt guardados en Archivos › En mi iPhone › Cuentas Streaming › Notas.
struct ArchivosNotasView: View {
    @State private var archivos: [URL] = []

    var body: some View {
        List {
            Section {
                ForEach(archivos, id: \.self) { url in
                    NavigationLink {
                        TextoView(titulo: url.deletingPathExtension().lastPathComponent,
                                  texto: (try? String(contentsOf: url, encoding: .utf8)) ?? "")
                    } label: {
                        Label(url.lastPathComponent, systemImage: "doc.plaintext")
                    }
                }
            } footer: {
                Text("También los encuentras en la app Archivos › En mi iPhone › Cuentas Streaming › Notas.")
            }
        }
        .navigationTitle("Blocs de notas")
        .onAppear { archivos = Bitacora.archivosDeNotas() }
        .overlay {
            if archivos.isEmpty { ContentUnavailableView("Aún no hay archivos", systemImage: "doc") }
        }
    }
}

/// Muestra un texto con botones para copiar y compartir.
struct TextoView: View {
    let titulo: String
    let texto: String
    @State private var copiado = false

    var body: some View {
        ScrollView {
            Text(texto)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(titulo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    UIPasteboard.general.string = texto
                    copiado = true
                } label: { Image(systemName: copiado ? "checkmark" : "doc.on.doc") }
                ShareLink(item: texto)
            }
        }
    }
}
