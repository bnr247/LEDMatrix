import SwiftUI

struct DeviceListView: View {
    @StateObject private var manager = MatrixManager()

    var body: some View {
        NavigationStack {
            List {
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
                        Text("Устройства не найдены")
                            .foregroundColor(.secondary)
                    }

                    ForEach(manager.discoveredDevices) { device in
                        NavigationLink(destination: MatrixControlView(manager: manager, device: device)) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(device.name)
                                        .font(.headline)
                                    Text(device.ipAddress)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }

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
        }
    }
}

struct ManualIPView: View {
    @ObservedObject var manager: MatrixManager
    @State private var ipAddress: String = ""

    var body: some View {
        Form {
            Section(header: Text("Введите IP адрес матрицы")) {
                TextField("192.168.1.50", text: $ipAddress)
                    .keyboardType(.decimalPad)
            }
            
            if !ipAddress.isEmpty {
                NavigationLink(destination: MatrixControlView(manager: manager, device: LEDMatrixDevice(name: "LedMatrix-Manual", ipAddress: ipAddress))) {
                    Text("Подключиться")
                }
            } else {
                Button("Подключиться") {}
                    .disabled(true)
            }
        }
        .navigationTitle("Ручное подключение")
    }
}
