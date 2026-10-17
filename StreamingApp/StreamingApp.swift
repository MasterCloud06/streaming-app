import SwiftUI
import SwiftData

@main
struct CuentasStreamingApp: App {
    let contenedor: ModelContainer = {
        do {
            return try ModelContainer(for: Cuenta.self, Perfil.self, Cliente.self, Registro.self)
        } catch {
            fatalError("No se pudo abrir la base de datos: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RaizView()
        }
        .modelContainer(contenedor)
    }
}

struct RaizView: View {
    @Environment(\.modelContext) private var ctx

    var body: some View {
        TabView {
            PendientesView()
                .tabItem { Label("Pendientes", systemImage: "bell.badge") }
            CuentasView()
                .tabItem { Label("Cuentas", systemImage: "rectangle.stack.person.crop") }
            NotasView()
                .tabItem { Label("Notas", systemImage: "note.text") }
            AjustesView()
                .tabItem { Label("Más", systemImage: "ellipsis.circle") }
        }
        .task {
            if Notificaciones.activas { _ = await Notificaciones.pedirPermiso() }
            Bitacora.regenerarEstado(ctx)
            Notificaciones.reprogramar(ctx)
        }
    }
}
