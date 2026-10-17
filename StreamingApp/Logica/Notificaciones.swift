import Foundation
import SwiftData
import UserNotifications

/// Avisos locales (funcionan sin internet):
///  - el día que vence cada persona
///  - un día antes de pagar cada cuenta
@MainActor
enum Notificaciones {
    nonisolated static let claveActivas = "notificacionesActivas"
    nonisolated static let claveHora = "horaAvisos"

    static var activas: Bool {
        UserDefaults.standard.object(forKey: claveActivas) as? Bool ?? true
    }
    static var hora: Int {
        let h = UserDefaults.standard.integer(forKey: claveHora)
        return (6...22).contains(h) ? h : 9
    }

    static func pedirPermiso() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    static func reprogramar(_ ctx: ModelContext) {
        let centro = UNUserNotificationCenter.current()
        centro.removeAllPendingNotificationRequests()
        guard activas else { return }

        let hoy = Fechas.hoy()
        let ahora = Date.now
        var avisos: [(fecha: Date, id: String, titulo: String, cuerpo: String)] = []

        let clientes = (try? ctx.fetch(FetchDescriptor<Cliente>(predicate: #Predicate<Cliente> { $0.activo }))) ?? []
        // Agrupa por día para no mandar 10 avisos el mismo día
        let porDia = Dictionary(grouping: clientes.filter { $0.cuenta?.activa == true && $0.fechaVencimiento >= hoy }) {
            Fechas.dia($0.fechaVencimiento)
        }
        for (dia, lista) in porDia {
            let titulo = lista.count == 1 ? "Hoy vence \(lista[0].telefono)" : "Hoy vencen \(lista.count) personas"
            let cuerpo = lista.prefix(5).map { "\($0.cuenta?.plataforma ?? "") › \($0.perfil?.nombre ?? "") › \($0.telefono)" }
                .joined(separator: "\n")
            avisos.append((alaHora(dia), "venc-\(Fechas.iso(dia))", titulo, cuerpo))
        }

        let cuentas = (try? ctx.fetch(FetchDescriptor<Cuenta>(predicate: #Predicate<Cuenta> { $0.activa }))) ?? []
        for c in cuentas {
            guard let pago = c.fechaPago, pago >= hoy else { continue }
            let tarjeta = c.tarjeta.isEmpty ? "" : " con \(c.tarjeta)"
            avisos.append((alaHora(Fechas.sumarDias(pago, -1)), "pago-\(c.plataforma)-\(c.correo)",
                           "Mañana pagas \(c.plataforma)", "\(c.correo)\(tarjeta)"))
        }

        // iOS permite 64 avisos pendientes por app
        for a in avisos.filter({ $0.fecha > ahora }).sorted(by: { $0.fecha < $1.fecha }).prefix(60) {
            let contenido = UNMutableNotificationContent()
            contenido.title = a.titulo
            contenido.body = a.cuerpo
            contenido.sound = .default
            let comp = Fechas.calendario.dateComponents([.year, .month, .day, .hour, .minute], from: a.fecha)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comp, repeats: false)
            centro.add(UNNotificationRequest(identifier: a.id, content: contenido, trigger: trigger))
        }
    }

    private static func alaHora(_ dia: Date) -> Date {
        Fechas.calendario.date(bySettingHour: hora, minute: 0, second: 0, of: dia) ?? dia
    }
}
