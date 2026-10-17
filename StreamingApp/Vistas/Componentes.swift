import SwiftUI
import SwiftData
import UIKit

/// Etiqueta de color según los días que faltan.
struct BadgeDias: View {
    let dias: Int

    var body: some View {
        Text(texto)
            .font(.caption.weight(.semibold).monospacedDigit())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var texto: String {
        switch dias {
        case ..<0: return "Vencido \(-dias)d"
        case 0: return "Hoy"
        case 1: return "Mañana"
        default: return "\(dias) días"
        }
    }

    private var color: Color {
        switch dias {
        case ..<0: return .red
        case 0...3: return .orange
        case 4...7: return .yellow
        default: return .secondary
        }
    }
}

/// Fila de una persona: teléfono, vencimiento, dispositivos.
struct ClienteFila: View {
    let cliente: Cliente
    var mostrarCuenta = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(cliente.telefono).font(.body.monospacedDigit())
                if !cliente.nombre.isEmpty {
                    Text(cliente.nombre).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if cliente.activo { BadgeDias(dias: cliente.diasRestantes) }
            }
            if mostrarCuenta, let cuenta = cliente.cuenta {
                Text("\(cuenta.plataforma) · \(cliente.perfil?.nombre ?? "") · \(cuenta.correo)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            HStack(spacing: 6) {
                Label(Fechas.larga(cliente.fechaVencimiento), systemImage: "calendar")
                if !cliente.dispositivos.isEmpty {
                    Label(cliente.dispositivos.joined(separator: ", "), systemImage: "tv")
                        .lineLimit(1)
                }
            }
            .font(.caption).foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 2)
    }
}

/// Acciones rápidas sobre una persona: deslizar a la derecha = renovó, a la izquierda = no renovó.
/// Mantener presionado muestra más opciones.
struct AccionesCliente: ViewModifier {
    let cliente: Cliente
    @Environment(\.modelContext) private var ctx
    @Environment(\.openURL) private var openURL
    @State private var confirmarNoRenovo = false

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button { Acciones.renovar(ctx, cliente) } label: { Label("Renovó", systemImage: "checkmark.circle.fill") }
                    .tint(.green)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if cliente.activo {
                    Button { confirmarNoRenovo = true } label: { Label("No renovó", systemImage: "xmark.circle.fill") }
                        .tint(.red)
                }
                if let url = Formato.enlaceWhatsApp(cliente) {
                    Button { openURL(url) } label: { Label("WhatsApp", systemImage: "message.fill") }
                        .tint(.teal)
                }
            }
            .contextMenu {
                Section("Renovó") {
                    ForEach([1, 2, 3, 6], id: \.self) { m in
                        Button("\(m) mes\(m == 1 ? "" : "es")") { Acciones.renovar(ctx, cliente, meses: m) }
                    }
                    Button("1 mes desde hoy") { Acciones.renovar(ctx, cliente, meses: 1, desdeHoy: true) }
                }
                if let url = Formato.enlaceWhatsApp(cliente) {
                    Button { openURL(url) } label: { Label("Recordar por WhatsApp", systemImage: "message") }
                }
                Button {
                    UIPasteboard.general.string = Formato.datosAcceso(cliente)
                } label: { Label("Copiar datos de acceso", systemImage: "doc.on.doc") }
                if cliente.activo {
                    Button(role: .destructive) { confirmarNoRenovo = true } label: {
                        Label("No renovó", systemImage: "xmark.circle")
                    }
                }
            }
            .confirmationDialog("¿\(cliente.telefono) no renovó?", isPresented: $confirmarNoRenovo, titleVisibility: .visible) {
                Button("Sí, quitar de la lista", role: .destructive) { Acciones.noRenovo(ctx, cliente) }
            } message: {
                Text("Se libera su lugar en \(cliente.perfil?.nombre ?? "el perfil"). Queda guardado en \"No renovaron\" por si vuelve.")
            }
    }
}

extension View {
    func accionesCliente(_ c: Cliente) -> some View { modifier(AccionesCliente(cliente: c)) }
}

/// Botones rápidos para elegir dispositivos.
struct SelectorDispositivos: View {
    @Binding var seleccion: [String]
    @State private var otro = ""
    static let comunes = ["TV", "Smart TV", "Celular", "Tablet", "Laptop", "PC", "TV Box", "Consola"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 8) {
                ForEach(Self.comunes + seleccion.filter { !Self.comunes.contains($0) }, id: \.self) { d in
                    let marcado = seleccion.contains(d)
                    Button {
                        if marcado { seleccion.removeAll { $0 == d } } else { seleccion.append(d) }
                    } label: {
                        Text(d).font(.subheadline)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(marcado ? Color.accentColor : Color.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(marcado ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                TextField("Otro dispositivo", text: $otro)
                    .submitLabel(.done)
                    .onSubmit(agregarOtro)
                Button("Añadir", action: agregarOtro).disabled(otro.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.vertical, 4)
    }

    private func agregarOtro() {
        let t = otro.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !seleccion.contains(t) else { return }
        seleccion.append(t)
        otro = ""
    }
}

/// Distribuye vistas en filas que saltan de línea (para los chips).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let filas = acomodar(ancho: proposal.width ?? .infinity, subviews)
        let alto = filas.map(\.alto).reduce(0, +) + spacing * CGFloat(max(0, filas.count - 1))
        let ancho = filas.map(\.ancho).max() ?? 0
        return CGSize(width: proposal.width ?? ancho, height: alto)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for fila in acomodar(ancho: bounds.width, subviews) {
            var x = bounds.minX
            for i in fila.indices {
                let t = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(t))
                x += t.width + spacing
            }
            y += fila.alto + spacing
        }
    }

    private struct Fila { var indices: [Int] = []; var ancho: CGFloat = 0; var alto: CGFloat = 0 }

    private func acomodar(ancho maximo: CGFloat, _ subviews: Subviews) -> [Fila] {
        var filas: [Fila] = [Fila()]
        for (i, v) in subviews.enumerated() {
            let t = v.sizeThatFits(.unspecified)
            let extra = filas[filas.count - 1].indices.isEmpty ? t.width : t.width + spacing
            if filas[filas.count - 1].ancho + extra > maximo && !filas[filas.count - 1].indices.isEmpty {
                filas.append(Fila())
            }
            let ultima = filas.count - 1
            filas[ultima].ancho += filas[ultima].indices.isEmpty ? t.width : t.width + spacing
            filas[ultima].alto = max(filas[ultima].alto, t.height)
            filas[ultima].indices.append(i)
        }
        return filas
    }
}
