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

## Instalar en tu iPhone

Necesitas **una Mac con Xcode 16 o superior** (solo para instalarla; después la app no depende de la computadora).

1. Clona o descarga este repositorio y abre `StreamingApp.xcodeproj`.
2. En Xcode: selecciona el proyecto › target **StreamingApp** › *Signing & Capabilities* › en **Team** elige tu Apple ID (Xcode › Settings › Accounts para agregarlo).
3. Si Xcode dice que el *Bundle Identifier* ya existe, cámbialo por algo único (ej. `com.tunombre.cuentasstreaming`).
4. Conecta el iPhone por cable, elígelo arriba como destino y presiona ▶︎.
5. En el iPhone: *Ajustes › Privacidad y seguridad › Modo de desarrollador* → activar (pide reiniciar). Luego *Ajustes › General › VPN y gestión de dispositivos* → confiar en tu Apple ID.

**Duración de la instalación:** con un Apple ID gratuito la app deja de abrir a los 7 días y hay que volver a darle ▶︎ desde la Mac (tus datos no se borran). Con el Apple Developer Program (99 USD/año) dura un año.

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
