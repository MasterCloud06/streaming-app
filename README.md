# Cuentas Streaming (iOS)

App para administrar la venta de cuentas de streaming **100 % en el iPhone, sin internet ni computadora**. Reemplaza la nota de Notas: en vez de escribir, tocas.

## Qué hace

- **Pendientes** (pantalla de inicio): quién venció, quién vence en los próximos días y qué cuentas toca pagar.
- **Deslizar →** = renovó (+1 mes desde su vencimiento). **Deslizar ←** = no renovó (sale de la lista y libera el lugar). Mantener presionado: renovar 2/3/6 meses, renovar desde hoy, recordar por WhatsApp, copiar datos de acceso.
- **Cuentas**: plataforma, correo, contraseña (oculta, con botón copiar), fecha de pago, banco + últimos 4 dígitos, fecha en que se cerró sesión. Botones "Pagué la cuenta" y "Cerré sesión en todos los perfiles".
- **Perfiles**: 5 por cuenta (configurable), 2 personas por perfil (configurable), con teléfono, vencimiento y dispositivos.
- **Dispositivos**: se agregan con botones (TV, Smart TV, Celular, Tablet, Laptop…) o escribiendo otro.
- **Mover** a una persona a otro perfil con lugar libre; **"No renovaron"**: si alguien vuelve, deslizas y se reactiva.
- **Bloc de notas de cambios**: cada acción se escribe en `cambios-AAAA-MM-DD.txt` y se actualiza `estado-actual.txt` (todo en tu formato de Notas). Están en **Archivos › En mi iPhone › Cuentas Streaming › Notas** y en la pestaña Notas.
- **Importar desde Notas**: copias toda tu nota, la pegas, revisas lo que entendió y la importas.
- **Avisos** sin internet: el día que vence cada persona y un día antes de pagar cada cuenta.
- **Respaldo** en JSON para guardar en iCloud Drive o enviarte por WhatsApp, y restaurarlo si cambias de teléfono.

## Instalar en tu iPhone sin Mac (SideStore, gratis)

Cada cambio en `main` se compila solo en GitHub y se publica en [Releases](../../releases/latest) como `CuentasStreaming.ipa`.

**Una sola vez, con una PC Windows (64 bits) y cable USB:**

1. En el iPhone instala **LocalDevVPN** desde el App Store, ábrelo y toca *Connect* (acepta la configuración VPN).
2. En la PC instala **iTunes** desde la web de Apple y **iloader** (`.msi`) desde https://github.com/nab138/iloader/releases.
3. Conecta el iPhone por cable, confía en la PC, abre iloader, inicia sesión con tu Apple ID, elige el iPhone y toca **Install SideStore (Stable)**.
4. En el iPhone: *Ajustes › Privacidad y seguridad › Modo de desarrollador* → activar (se reinicia). Luego *Ajustes › General › VPN y gestión de dispositivos* → tu Apple ID → *Confiar*.
5. Con LocalDevVPN conectado, abre SideStore e inicia sesión con el mismo Apple ID.

**Instalar la app (ya sin PC):**

- En SideStore › *Sources* › **+** pega `https://github.com/MasterCloud06/streaming-app/releases/latest/download/source.json` e instala *Cuentas Streaming*.
- O descarga `CuentasStreaming.ipa` desde Releases en Safari y en SideStore › *My Apps* › **+** elígelo desde Archivos.

**Cada 7 días:** con LocalDevVPN conectado y Wi-Fi, abre SideStore › *My Apps* y toca el contador **7 DAYS** de SideStore y de Cuentas Streaming. Tus datos no se borran al refrescar. Con Apple ID gratuito puedes tener hasta 3 apps instaladas así (SideStore cuenta como una).

> Respaldos: si la app llega a expirar, tus datos siguen ahí al reinstalarla con el mismo Apple ID, pero igual crea un respaldo desde *Más* de vez en cuando.

### Con Mac (opcional)

Abre `StreamingApp.xcodeproj` en Xcode 16+, elige tu Apple ID en *Signing & Capabilities*, conecta el iPhone y presiona ▶︎.

## Estructura

```
StreamingApp/
  StreamingApp.swift        Entrada de la app y pestañas
  Modelos/Modelos.swift     Cuenta, Perfil, Cliente, Registro (SwiftData, guardado local)
  Logica/
    Acciones.swift          Renovar, no renovó, pagar, dispositivos... (todo pasa por la bitácora)
    Bitacora.swift          Historial + blocs de notas .txt
    Importador.swift        Lee el texto de Notas del iPhone
    Formato.swift           Exporta al formato de Notas, mensajes de WhatsApp
    Fechas.swift            Fechas en español ("6 de noviembre")
    Notificaciones.swift    Avisos locales
    Respaldo.swift          Respaldo/restauración JSON
  Vistas/                   Pantallas SwiftUI
```

Requiere iOS 17 o superior.
