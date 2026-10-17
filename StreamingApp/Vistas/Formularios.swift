import SwiftUI
import SwiftData

/// Agregar una persona a un perfil.
struct NuevaPersonaView: View {
    let perfil: Perfil
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var telefono = "+591"
    @State private var nombre = ""
    @State private var meses = 1
    @State private var fechaExacta = false
    @State private var vencimiento = Fechas.sumarMeses(Fechas.hoy(), 1)
    @State private var dispositivos: [String] = []

    private var telefonoValido: Bool { Importador.normalizarTelefono(telefono) != nil }
    private var fechaFinal: Date { fechaExacta ? vencimiento : Fechas.sumarMeses(Fechas.hoy(), meses) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Teléfono", text: $telefono)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    TextField("Nombre (opcional)", text: $nombre)
                } header: {
                    Text("\(perfil.cuenta?.plataforma ?? "") › \(perfil.nombre)")
                } footer: {
                    if perfil.libres == 0 {
                        Text("Este perfil ya tiene \(perfil.activos.count) de \(perfil.maxClientes) personas.")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Pagó por") {
                    Picker("Tiempo", selection: $meses) {
                        ForEach([1, 2, 3, 6, 12], id: \.self) { Text("\($0) m").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .disabled(fechaExacta)
                    Toggle("Elegir fecha exacta", isOn: $fechaExacta)
                    if fechaExacta {
                        DatePicker("Vence", selection: $vencimiento, displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "es_BO"))
                    } else {
                        LabeledContent("Vence", value: Fechas.larga(fechaFinal, conAnio: true))
                    }
                }

                Section("Dispositivos") {
                    SelectorDispositivos(seleccion: $dispositivos)
                }
            }
            .navigationTitle("Nueva persona")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Agregar") {
                        Acciones.nuevoCliente(ctx, perfil: perfil, telefono: telefono, nombre: nombre,
                                              vencimiento: fechaFinal, dispositivos: dispositivos)
                        dismiss()
                    }
                    .disabled(!telefonoValido)
                }
            }
        }
    }
}

/// Crear o editar una cuenta con sus perfiles.
struct CuentaFormView: View {
    let cuenta: Cuenta?
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query private var todas: [Cuenta]

    @State private var d = Acciones.DatosCuenta()
    @State private var tienePago = true
    @State private var fechaPago = Fechas.sumarMeses(Fechas.hoy(), 1)
    @State private var tieneCierre = false
    @State private var fechaCierre = Fechas.hoy()
    @State private var perfiles: [FilaPerfil] = []
    @State private var eliminados: [Perfil] = []
    @State private var cargado = false

    struct FilaPerfil: Identifiable {
        let id = UUID()
        var perfil: Perfil?
        var nombre: String
        var cupos: Int
    }

    static let plataformasComunes = ["Netflix", "Disney+", "Max", "Prime Video", "Spotify", "YouTube Premium",
                                     "Crunchyroll", "Paramount+", "Apple TV+", "Vix"]

    private var plataformasSugeridas: [String] {
        Array(Set(Self.plataformasComunes + todas.map(\.plataforma))).sorted()
    }

    private var valido: Bool {
        !d.plataforma.trimmingCharacters(in: .whitespaces).isEmpty &&
        !d.correo.trimmingCharacters(in: .whitespaces).isEmpty &&
        !perfiles.contains { $0.nombre.trimmingCharacters(in: .whitespaces).isEmpty } &&
        (d.ultimos4.isEmpty || d.ultimos4.count == 4)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cuenta") {
                    HStack {
                        TextField("Plataforma", text: $d.plataforma)
                        Menu {
                            ForEach(plataformasSugeridas, id: \.self) { p in Button(p) { d.plataforma = p } }
                        } label: { Image(systemName: "chevron.down.circle") }
                    }
                    TextField("Correo", text: $d.correo)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Contraseña", text: $d.contrasena)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                }

                Section("Pago") {
                    Toggle("Tiene fecha de pago", isOn: $tienePago)
                    if tienePago {
                        DatePicker("Se paga el", selection: $fechaPago, displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "es_BO"))
                    }
                    TextField("Banco (ej. Banco Sol)", text: $d.banco)
                    TextField("Últimos 4 dígitos de la tarjeta", text: $d.ultimos4)
                        .keyboardType(.numberPad)
                        .onChange(of: d.ultimos4) { _, v in
                            let limpio = String(v.filter(\.isNumber).prefix(4))
                            if limpio != v { d.ultimos4 = limpio }
                        }
                }

                Section {
                    Toggle("Ya cerré sesión en todos los perfiles", isOn: $tieneCierre)
                    if tieneCierre {
                        DatePicker("Fecha", selection: $fechaCierre, displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "es_BO"))
                    }
                }

                Section {
                    ForEach($perfiles) { $fila in
                        HStack {
                            TextField("Nombre del perfil", text: $fila.nombre)
                            Stepper("\(fila.cupos)", value: $fila.cupos, in: 1...10)
                                .fixedSize()
                        }
                        .deleteDisabled(!(fila.perfil?.activos.isEmpty ?? true))
                    }
                    .onDelete { idx in
                        for i in idx { if let p = perfiles[i].perfil { eliminados.append(p) } }
                        perfiles.remove(atOffsets: idx)
                    }
                    .onMove { perfiles.move(fromOffsets: $0, toOffset: $1) }
                    Button {
                        perfiles.append(FilaPerfil(perfil: nil, nombre: "Perfil \(perfiles.count + 1)", cupos: 2))
                    } label: { Label("Agregar perfil", systemImage: "plus") }
                    .disabled(perfiles.count >= 10)
                } header: {
                    HStack { Text("Perfiles"); Spacer(); Text("Personas por perfil") }
                } footer: {
                    Text("Solo se pueden quitar perfiles sin personas activas.")
                }

                Section("Notas") {
                    TextField("Opcional", text: $d.notas, axis: .vertical)
                }
            }
            .navigationTitle(cuenta == nil ? "Nueva cuenta" : "Editar cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: guardar).disabled(!valido)
                }
            }
            .onAppear(perform: cargar)
        }
    }

    private func cargar() {
        guard !cargado else { return }
        cargado = true
        guard let c = cuenta else {
            perfiles = (1...5).map { FilaPerfil(perfil: nil, nombre: "Perfil \($0)", cupos: 2) }
            return
        }
        d = Acciones.DatosCuenta(plataforma: c.plataforma, correo: c.correo, contrasena: c.contrasena,
                                 fechaPago: c.fechaPago, banco: c.banco, ultimos4: c.ultimos4,
                                 fechaCierreSesion: c.fechaCierreSesion, notas: c.notas)
        tienePago = c.fechaPago != nil
        if let p = c.fechaPago { fechaPago = p }
        tieneCierre = c.fechaCierreSesion != nil
        if let f = c.fechaCierreSesion { fechaCierre = f }
        perfiles = c.perfilesOrdenados.map { FilaPerfil(perfil: $0, nombre: $0.nombre, cupos: $0.maxClientes) }
    }

    private func guardar() {
        var datos = d
        datos.fechaPago = tienePago ? fechaPago : nil
        datos.fechaCierreSesion = tieneCierre ? fechaCierre : nil
        let nombres = perfiles.map { ($0.nombre.trimmingCharacters(in: .whitespaces), $0.cupos) }
        if let c = cuenta {
            Acciones.editarCuenta(ctx, c, datos,
                                  perfiles: zip(perfiles, nombres).map { ($0.perfil, $1.0, $1.1) },
                                  eliminar: eliminados)
        } else {
            datos.perfiles = nombres.map { (nombre: $0.0, cupos: $0.1) }
            Acciones.crearCuenta(ctx, datos)
        }
        dismiss()
    }
}
