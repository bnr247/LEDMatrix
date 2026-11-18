// MARK: - ВКЛАДКА: ЧАСЫ

import SwiftUI

struct ClockSettingsView: View {
    @ObservedObject var manager: MatrixManager

    @Environment(\.scenePhase) private var scenePhase

    /// Индекс текущего лица в карусели. Прошивка хранит ID шрифта, а порядок
    /// массива /clockfaces стабилен, поэтому индекс и ID синхронизируются.
    @State private var selectedFaceIndex: Int = 0
    /// Цвет всегда редактирует один выбранный элемент. По умолчанию это фон,
    /// чтобы пикер был доступен сразу после открытия вкладки.
    @State private var selection: ClockPreviewSelection = .background
    @State private var isPreviewActive = false

    private var faces: [ClockFace] { manager.clockFaces }
    private var currentFace: ClockFace? {
        faces.indices.contains(selectedFaceIndex) ? faces[selectedFaceIndex] : nil
    }

    /// Все растровые стили цифр из /clockfonts, включая дополнительные стили
    /// одного шрифта (например, у Huge Bold их два).
    private var styleMap: [Int: ClockFontStyle] {
        var map: [Int: ClockFontStyle] = [:]
        for font in manager.clockFonts {
            for style in font.styles {
                map[style.id] = style
            }
            if font.styles.isEmpty, !font.digits.isEmpty {
                map[font.fontStyleId] = ClockFontStyle(
                    id: font.fontStyleId,
                    name: font.fontStyleName,
                    width: font.width,
                    height: font.height,
                    digits: font.digits
                )
            }
        }
        return map
    }

    var body: some View {
        Form {
            previewSection
            appearanceSection
            separatorSection
        }
        .themedForm(manager)
        .task {
            await loadClockData()
        }
        .onAppear {
            syncSelectedFace()
            isPreviewActive = manager.settings.clockPreviewActive
        }
        .onDisappear {
            disablePreview()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                disablePreview()
            }
        }
        .onChange(of: manager.settings.clockPreviewActive) { _, active in
            // Устройство могло выйти из превью само (например, при смене
            // режима экрана) — глаз должен показывать реальное состояние.
            isPreviewActive = active
        }
        .onChange(of: selectedFaceIndex) { oldIndex, newIndex in
            handleFaceChange(from: oldIndex, to: newIndex)
        }
        .onChange(of: manager.clockFaces.count) { _, newCount in
            if newCount > 0, selectedFaceIndex >= newCount {
                selectedFaceIndex = 0
            }
        }
    }

    // MARK: - Превью

    private var previewSection: some View {
        Section {
            VStack(spacing: 12) {
                HStack {
                    Text(currentFace?.name ?? "Загрузка циферблатов...")
                        .font(.headline)
                        .foregroundColor(manager.appTextColor)
                    Spacer()
                    Button(action: togglePreview) {
                        Image(systemName: isPreviewActive ? "eye.fill" : "eye")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isPreviewActive ? manager.accentColor : manager.secondaryTextColor)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle().fill(
                                    isPreviewActive
                                        ? manager.accentColor.opacity(0.16)
                                        : manager.secondaryTextColor.opacity(0.10)
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(faces.isEmpty)
                    .accessibilityLabel("Показывать циферблат на устройстве")
                }

                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if faces.isEmpty {
                            ProgressView()
                                .tint(manager.accentColor)
                        } else {
                            TabView(selection: $selectedFaceIndex) {
                                ForEach(Array(faces.enumerated()), id: \.element.id) { index, face in
                                    ClockFacePreviewCanvas(
                                        face: face,
                                        styles: styleMap,
                                        settings: manager.settings,
                                        selection: selection,
                                        accentColor: manager.accentColor,
                                        panelColor: manager.matrixPanelColor,
                                        onSelect: { newSelection in
                                            withAnimation(.easeInOut(duration: 0.12)) {
                                                selection = newSelection
                                            }
                                        }
                                    )
                                    .tag(index)
                                }
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(manager.cardBorderColor, lineWidth: 1)
                    )

                if faces.count > 1 {
                    HStack(spacing: 5) {
                        ForEach(faces.indices, id: \.self) { index in
                            Circle()
                                .fill(index == selectedFaceIndex
                                      ? manager.accentColor
                                      : manager.secondaryTextColor.opacity(0.28))
                                .frame(width: 5, height: 5)
                        }
                    }
                }

                HStack {
                    Text("Цвет: \(selection.title)")
                        .foregroundColor(manager.appTextColor)
                    Spacer()
                    if let face = currentFace {
                        ColorPicker(
                            "",
                            selection: colorBinding(for: selection, face: face),
                            supportsOpacity: false
                        )
                        .labelsHidden()
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(manager.fieldBackgroundColor)
                )

                Text("Нажмите на цифру, разделитель или фон, чтобы выбрать элемент для изменения цвета")
                    .font(.caption2)
                    .foregroundColor(manager.secondaryTextColor)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 6)
        } header: {
            Text("Предпросмотр")
                .foregroundColor(manager.accentColor)
        }
        .listRowBackground(manager.cardBackgroundColor)
    }

    // MARK: - Внешний вид

    private var appearanceSection: some View {
        Section(header: Text("Внешний вид").foregroundColor(manager.accentColor)) {
            Picker("Анимация", selection: manager.clockAnimationTypeBinding) {
                Text("Стандартный").tag(ClockAnimationType.fading)
                Text("Слайд").tag(ClockAnimationType.slideUp)
                Text("Вспышка").tag(ClockAnimationType.flash)
                Text("Помехи").tag(ClockAnimationType.tvStatic)
            }

            Picker("Эффект", selection: manager.clockColorEffectBinding) {
                Text("Нет").tag(ClockColorEffect.off)
                Text("Обмен цветом").tag(ClockColorEffect.swap)
                Text("Спектр").tag(ClockColorEffect.spectrum)
                Text("Радуга").tag(ClockColorEffect.rainbow)
                Text("Случайный цвет").tag(ClockColorEffect.randomColor)
            }

            if manager.settings.clockColorEffect?.usesSpeed == true {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Скорость эффекта")
                        Spacer()
                        Text("\(manager.settings.clockEffectSpeed)")
                            .foregroundColor(manager.secondaryTextColor)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(manager.settings.clockEffectSpeed) },
                            set: { newValue in
                                // Во время перетаскивания обновляем только UI,
                                // а на устройство шлём после отпускания.
                                manager.settings.clockEffectSpeed = Int(newValue)
                            }
                        ),
                        in: 1 ... 100,
                        step: 5,
                        onEditingChanged: { editing in
                            if !editing {
                                Task {
                                    await manager.updateClockEffectSpeed(manager.settings.clockEffectSpeed)
                                }
                            }
                        }
                    )
                    .tint(manager.accentColor)
                }
            }
        }
        .listRowBackground(manager.cardBackgroundColor)
    }

    private var separatorSection: some View {
        Section {
            Toggle("Показывать разделитель", isOn: Binding(
                get: { manager.settings.showColon },
                set: { newValue in Task { await manager.toggleClockShowColon(newValue) } }
            ))
            .tint(manager.accentColor)
        }
        .listRowBackground(manager.cardBackgroundColor)
    }

    // MARK: - Данные

    private func loadClockData() async {
        if manager.clockFaces.isEmpty {
            async let faces = manager.fetchClockFaces()
            async let fonts = manager.fetchClockFonts()
            let (loadedFaces, loadedFonts) = await (faces, fonts)
            manager.clockFaces = loadedFaces
            manager.clockFonts = loadedFonts
        }
        syncSelectedFace()
    }

    private func syncSelectedFace() {
        guard !faces.isEmpty else { return }
        if let index = faces.firstIndex(where: { $0.id == manager.settings.currentClockFontId }) {
            if index != selectedFaceIndex {
                selectedFaceIndex = index
            }
        } else if selectedFaceIndex >= faces.count {
            selectedFaceIndex = 0
        }
    }

    // MARK: - Выбор и цвета

    private func handleFaceChange(from oldIndex: Int, to newIndex: Int) {
        guard faces.indices.contains(newIndex) else { return }
        let face = faces[newIndex]
        // Программная синхронизация при открытии экрана не должна ничего слать.
        guard face.id != manager.settings.currentClockFontId else { return }

        let direction = newIndex >= oldIndex ? 1 : -1
        Task {
            await manager.selectClockFace(face.id, direction: isPreviewActive ? direction : 0)
        }
    }

    private func colorBinding(for selection: ClockPreviewSelection, face: ClockFace) -> Binding<Color> {
        Binding(
            get: { Color(hex: colorHex(for: selection, face: face)) },
            set: { newColor in
                Task {
                    await manager.updateClockColor(for: selection, color: newColor)
                }
            }
        )
    }

    private func colorHex(for selection: ClockPreviewSelection, face: ClockFace) -> String {
        switch selection {
        case .digit(let type):
            guard let digit = face.digit(type: type) else { return "#FFFFFF" }
            return ClockPalette.hex(for: digit.colorSlot, settings: manager.settings, fallback: digit.colorHex)
        case .separator:
            return ClockPalette.hex(for: "separator", settings: manager.settings, fallback: face.separatorColorHex)
        case .background:
            return ClockPalette.hex(for: face.bgColorSlot, settings: manager.settings, fallback: face.bgColorHex)
        }
    }

    // MARK: - Живой предпросмотр

    private func togglePreview() {
        let newValue = !isPreviewActive
        isPreviewActive = newValue
        Task {
            if newValue, let face = currentFace {
                manager.settings.currentClockFontId = face.id
            }
            await manager.setClockPreview(newValue)
        }
    }

    private func disablePreview() {
        guard isPreviewActive else { return }
        isPreviewActive = false
        Task {
            await manager.setClockPreview(false)
        }
    }
}

// MARK: - Палитра

private enum ClockPalette {
    /// Сохранённый цвет слота важнее дизайнерского значения из разметки: именно
    /// его показывает устройство после смены цвета в приложении.
    static func hex(for slot: String, settings: MatrixSettings, fallback: String) -> String {
        switch slot {
        case "background":
            return settings.bgColorHex.isEmpty ? fallback : settings.bgColorHex
        case "hours_1":
            return settings.hoursColor1Hex.isEmpty ? fallback : settings.hoursColor1Hex
        case "hours_2":
            return settings.hoursColor2Hex.isEmpty ? fallback : settings.hoursColor2Hex
        case "minutes_1":
            return settings.minutesColor1Hex.isEmpty ? fallback : settings.minutesColor1Hex
        case "minutes_2":
            return settings.minutesColor2Hex.isEmpty ? fallback : settings.minutesColor2Hex
        case "separator":
            return settings.colonColorHex.isEmpty ? fallback : settings.colonColorHex
        default:
            return fallback
        }
    }

    static func blend(_ from: Color, _ to: Color, amount: CGFloat) -> Color {
        let a = UIColor(from).rgbComponents()
        let b = UIColor(to).rgbComponents()
        let t = max(0, min(1, amount))
        return Color(
            .sRGB,
            red: (Double(a.0) * (1 - t) + Double(b.0) * t) / 255,
            green: (Double(a.1) * (1 - t) + Double(b.1) * t) / 255,
            blue: (Double(a.2) * (1 - t) + Double(b.2) * t) / 255
        )
    }
}

// MARK: - 16×16 превью циферблата

private struct ClockFacePreviewCanvas: View {
    let face: ClockFace
    let styles: [Int: ClockFontStyle]
    let settings: MatrixSettings
    let selection: ClockPreviewSelection
    let accentColor: Color
    let panelColor: Color
    let onSelect: (ClockPreviewSelection) -> Void

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let pixels = renderPixels(at: context.date)
                Canvas { canvas, size in
                    let cell = min(size.width, size.height) / 16
                    let gap = cell > 8 ? 1.0 : 0.5

                    for y in 0 ..< 16 {
                        for x in 0 ..< 16 {
                            let rect = CGRect(
                                x: CGFloat(x) * cell + gap / 2,
                                y: CGFloat(y) * cell + gap / 2,
                                width: max(0, cell - gap),
                                height: max(0, cell - gap)
                            )
                            canvas.fill(Path(rect), with: .color(pixels[y * 16 + x]))
                        }
                    }

                    if let rect = selectionRect(for: selection),
                       let cellRect = highlightRect(rect, cell: cell) {
                        let outlined = cellRect.insetBy(dx: -cell * 0.10, dy: -cell * 0.10)
                        canvas.stroke(
                            Path(roundedRect: outlined, cornerRadius: max(2, cell * 0.16)),
                            with: .color(accentColor),
                            lineWidth: max(1.5, cell * 0.14)
                        )
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { event in
                            let cell = side / 16
                            guard cell > 0 else { return }
                            let x = Int(floor(max(0, min(side - 0.001, event.location.x)) / cell))
                            let y = Int(floor(max(0, min(side - 0.001, event.location.y)) / cell))
                            onSelect(face.hitTest(x: x, y: y))
                        }
                )
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .background(panelColor)
    }

    private func renderPixels(at date: Date) -> [Color] {
        let backgroundHex = ClockPalette.hex(
            for: face.bgColorSlot,
            settings: settings,
            fallback: face.bgColorHex
        )
        var pixels = Array(repeating: Color(hex: backgroundHex), count: 256)

        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let digitValues: [String: Int] = [
            "h1": hour / 10,
            "h2": hour % 10,
            "m1": minute / 10,
            "m2": minute % 10
        ]

        for digit in face.digits {
            guard let value = digitValues[digit.type],
                  let style = styles[digit.fontStyle] else { continue }
            let color = Color(hex: ClockPalette.hex(
                for: digit.colorSlot,
                settings: settings,
                fallback: digit.colorHex
            ))

            let width = min(style.width, digit.width)
            let height = min(style.height, digit.height)
            guard width > 0, height > 0 else { continue }

            for row in 0 ..< height {
                for col in 0 ..< width {
                    guard style.pixel(digit: value, col: col, row: row) else { continue }
                    let x = digit.x + col
                    let y = digit.y + row
                    guard x >= 0, x < 16, y >= 0, y < 16 else { continue }
                    pixels[y * 16 + x] = color
                }
            }
        }

        guard settings.showColon else { return pixels }

        let separatorColor = Color(hex: ClockPalette.hex(
            for: "separator",
            settings: settings,
            fallback: face.separatorColorHex
        ))
        for part in face.separatorParts {
            for row in 0 ..< part.height {
                for col in 0 ..< part.width {
                    let x = part.x + col
                    let y = part.y + row
                    guard x >= 0, x < 16, y >= 0, y < 16 else { continue }
                    // В Super Bold точка разделителя плавно переходит из цвета
                    // лежащей под ней цифры в собственный цвет. В статичном
                    // превью показываем середину перехода.
                    pixels[y * 16 + x] = face.separatorUseUnderlying
                        ? ClockPalette.blend(pixels[y * 16 + x], separatorColor, amount: 0.5)
                        : separatorColor
                }
            }
        }

        return pixels
    }

    private func selectionRect(for selection: ClockPreviewSelection) -> CGRect? {
        switch selection {
        case .digit(let type):
            guard let digit = face.digit(type: type) else { return nil }
            return CGRect(x: digit.x, y: digit.y, width: digit.width, height: digit.height)
        case .separator(let index):
            guard face.separatorParts.indices.contains(index) else { return nil }
            let part = face.separatorParts[index]
            return CGRect(x: part.x, y: part.y, width: part.width, height: part.height)
        case .background:
            return CGRect(x: 0, y: 0, width: 16, height: 16)
        }
    }

    private func highlightRect(_ rect: CGRect, cell: CGFloat) -> CGRect? {
        guard rect.width > 0, rect.height > 0 else { return nil }
        return CGRect(
            x: rect.origin.x * cell,
            y: rect.origin.y * cell,
            width: rect.width * cell,
            height: rect.height * cell
        )
    }
}
