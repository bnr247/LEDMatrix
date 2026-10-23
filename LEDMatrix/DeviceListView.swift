import SwiftUI

struct DeviceListView: View {
    @StateObject private var manager = MatrixManager()
    @State private var manualIP: String = ""
    @State private var showManualInput = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Устройства в сети")) {
                    if manager.isScanning {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Поиск устройств LedMatrix-...")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if manager.discoveredDevices.isEmpty && !manager.isScanning {
                        Text("Устройства не найдены")
                            .foregroundColor(.secondary)
                    }

                    ForEach(manager.discoveredDevices) { device in
                        Button(action: {
                            Task {
                                await manager.fetchSettings(for: device)
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(device.name)
                                        .font(.headline)
                                    Text(device.ipAddress)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }

                Section {
                    Button("Добавить по IP вручную") {
                        showManualInput.toggle()
                    }
                }
            }
            .navigationTitle("LED Матрица")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        manager.startScanning()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showManualInput) {
                ManualIPView(manager: manager, isPresented: $showManualInput)
            }
            .sheet(item: $manager.selectedDevice) { device in
                MatrixControlView(manager: manager, device: device)
            }
            .onAppear {
                manager.startScanning()
            }
        }
    }
}

struct ManualIPView: View {
    @ObservedObject var manager: MatrixManager // Исправлено: добавлен символ @
    @Binding var isPresented: Bool
    @State var ipAddress: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Введите IP адрес матрицы")) {
                    TextField("192.168.1.50", text: $ipAddress)
                        .keyboardType(.decimalPad)
                }
                Button("Подключиться") {
                    let device = LEDMatrixDevice(name: "LedMatrix-Manual", ipAddress: ipAddress)
                    Task {
                        await manager.fetchSettings(for: device)
                        isPresented = false
                    }
                }
                .disabled(ipAddress.isEmpty)
            }
            .navigationTitle("Ручное подключение")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { isPresented = false }
                }
            }
        }
    }
}
