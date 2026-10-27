import SwiftUI

struct DeviceListView: View {
    @StateObject private var manager = MatrixManager()
    @State private var deviceToRename: LEDMatrixDevice?
    @State private var newName: String = ""

    var body: some View {
        NavigationStack {
            List {
                // СЕКЦИЯ 1: Добавленные пользователем устройства
                if !manager.savedDevices.isEmpty {
                    Section(header: Text("Мои устройства")) {
                        ForEach(manager.savedDevices) { device in
                            HStack {
                                NavigationLink(destination: MatrixControlView(manager: manager, device: device)) {
                                    VStack(alignment: .leading) {
                                        Text(device.name)
                                            .font(.headline)
                                        Text(device.ipAddress)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                
                                Button(action: {
                                    newName = device.name
                                    deviceToRename = device
                                }) {
                                    Image(systemName: "pencil.line")
                                        .foregroundColor(.accentColor)
                                        .padding(.leading, 8)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .onDelete { indexSet in
                            manager.removeDevice(at: indexSet)
                        }
                    }
                }
                
                // СЕКЦИЯ 2: Найденные новые устройства в сети
                Section(header: Text("Устройства в сети")) {
                    if manager.isScanning {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Поиск устройств LedMatrix...")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if manager.discoveredDevices.isEmpty && !manager.isScanning {
                        Text("Новые устройства не найдены")
                            .foregroundColor(.secondary)
                    }

                    ForEach(manager.discoveredDevices) { device in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.name)
                                    .font(.headline)
                                Text(device.ipAddress)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            Button("Добавить") {
                                manager.saveDevice(device)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }

                // СЕКЦИЯ 3: Ручное добавление
                Section {
                    NavigationLink(destination: ManualIPView(manager: manager)) {
                        Text("Добавить по IP вручную")
                    }
                }
            }
            .navigationTitle("Список устройств")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        manager.startScanning()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                manager.startScanning()
            }
            // Диалоговое окно для переименования устройства
            .alert("Переименовать устройство", isPresented: Binding(
                get: { deviceToRename != nil },
                set: { if !$0 { deviceToRename = nil } }
            )) {
                TextField("Название устройства", text: $newName)
                Button("Сохранить") {
                    if let device = deviceToRename {
                        manager.renameDevice(ipAddress: device.ipAddress, newName: newName)
                    }
                    deviceToRename = nil
                }
                Button("Отмена", role: .cancel) { deviceToRename = nil }
            }
        }
    }
}

struct ManualIPView: View {
    @ObservedObject var manager: MatrixManager
    @State private var ipAddress: String = ""
    @State private var customName: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            Section(header: Text("Параметры матрицы")) {
                TextField("Название матрицы (например, Гостиная)", text: $customName)
                TextField("192.168.1.50", text: $ipAddress)
                    .keyboardType(.numbersAndPunctuation)
            }
            
            Button("Сохранить и подключиться") {
                let name = customName.isEmpty ? "LedMatrix-Manual" : customName
                let newDevice = LEDMatrixDevice(name: name, ipAddress: ipAddress)
                
                manager.saveDevice(newDevice)
                dismiss()
            }
            .disabled(ipAddress.isEmpty)
        }
        .navigationTitle("Ручное подключение")
    }
}
