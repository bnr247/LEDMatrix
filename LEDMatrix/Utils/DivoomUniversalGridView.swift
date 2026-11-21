//
//  DivoomUniversalGridView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 07.11.2026.
//

import OSLog
import SwiftUI

private let divoomGridPerfLog = Logger(subsystem: "com.stanislavleonov.LedMatrix", category: "divoom.grid")

/// Скролл-позиция нужна только внутренней логике пагинации. Храним её в
/// reference-типе, чтобы обновление индекса не перерисовывало всю сетку.
private final class GridScrollTracker {
    var lastVisibleIndex = 0
}

struct DivoomUniversalGridView: View {
    let title: String
    @ObservedObject var manager: MatrixManager
        
    let fetchItems: (_ startNum: Int, _ endNum: Int, _ fileSort: Int) async throws -> (items: [DivoomFileItem], curListNum: Int)
    let onPlayTapped: ((_ sortOrder: Int) -> Void)?
        
    @AppStorage("divoom_grid_columns") private var gridColumnsCount: Int = 2
    @AppStorage("divoom_file_sort") private var fileSortOption: Int = 1
        
    @State private var items: [DivoomFileItem] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String? = nil
        
    @State private var hasMorePages = true
    @State private var currentStart = 1
    private let pageSize = 30
        
    // Ячейки добавляются сразу после metadata. Полные анимации приходят
    // порциями и вставляются по мере готовности — никто не ждёт все 30 файлов
    // и не видит статичную заглушку вместо анимации.
    @State private var loadedAnimations: [String: UIImage] = [:]
    @State private var loadGeneration = 0
    @State private var isFetchingPage = false
    @State private var scrollTracker = GridScrollTracker()
    private let nearEndThreshold = 15
        
    @State private var isShowingSettingsSheet = false
    @State private var scrollPositionId: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    isShowingSettingsSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Вид и сортировка")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .if(!manager.currentTheme.usesSystemAppearance) { content in
                        content
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(manager.fieldBackgroundColor)
                            .foregroundColor(manager.appTextColor)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(manager.cardBorderColor, lineWidth: 1)
                            )
                    }
                }
                .themedButtonStyle(manager, .borderless)
                
                Spacer()
                
                if let playAction = onPlayTapped {
                    Button(action: {
                        playAction(fileSortOption)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.rectangle.fill")
                            Text("Воспроизвести")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .if(!manager.currentTheme.usesSystemAppearance) { content in
                            content
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(manager.cardBackgroundColor)
                                .foregroundColor(manager.accentColor)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(manager.accentColor.opacity(0.5), lineWidth: 1)
                                )
                        }
                    }
                    .themedButtonStyle(manager, .bordered)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(manager.backgroundColor)
            
            Rectangle()
                .fill(manager.dividerColor)
                .frame(height: 0.5)

            Group {
                if isLoading && items.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(manager.accentColor)
                        Text("Загрузка галереи...")
                            .font(.subheadline)
                            .foregroundColor(manager.secondaryTextColor)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage, items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(manager.warningColor)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundColor(manager.appTextColor)
                        Button("Повторить") {
                            Task { await loadInitialItems() }
                        }
                        .buttonStyle(.bordered)
                        .tint(manager.accentColor)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    Text("Нет элементов")
                        .foregroundColor(manager.secondaryTextColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { _ in
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: gridColumnsCount), spacing: 2) {
                                ForEach(items) { item in
                                    NavigationLink(destination: DivoomFeedView(
                                        title: title,
                                        manager: manager,
                                        initialItems: items,
                                        initialImages: loadedAnimations,
                                        selectedItemId: item.id,
                                        fetchMoreItems: { start, end in
                                            let result = try await fetchItems(start, end, fileSortOption)
                                            return result.items
                                        },
                                        onScrollPositionChanged: { feedId in
                                            if let feedId = feedId {
                                                scrollPositionId = feedId
                                            }
                                        }
                                    )) {
                                        AnimatedImageView(
                                            manager: manager,
                                            item: item,
                                            image: loadedAnimations[item.FileId ?? ""]
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .id(item.id)
                                    .onAppear {
                                        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
                                        scrollTracker.lastVisibleIndex = index
                                        // Половина страницы — подгружаем metadata следующей,
                                        // но показываем metadata сразу, не дожидаясь анимаций.
                                        if index >= items.count - nearEndThreshold {
                                            Task { await loadNextPage() }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                                         
                            if isLoadingMore {
                                ProgressView()
                                    .tint(manager.accentColor)
                                    .padding(.vertical, 20)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .safeAreaPadding(.bottom, 80)
                        .scrollPosition(id: $scrollPositionId)
                    }
                    .background(manager.backgroundColor)
                    .refreshable {
                        await refreshItems()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(manager.backgroundColor)
        .sheet(isPresented: $isShowingSettingsSheet) {
            gallerySettingsSheet
                .presentationDetents([.height(260)])
                .if(!manager.currentTheme.usesSystemAppearance) { content in
                    content.presentationBackground(manager.backgroundColor)
                }
        }
        .task(id: fileSortOption) {
            if items.isEmpty {
                await loadInitialItems()
            }
        }
    }
    
    private var gallerySettingsSheet: some View {
        VStack(spacing: 20) {
            if !manager.currentTheme.usesSystemAppearance {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(manager.secondaryTextColor.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
            }
            
            Text("Настройки галереи")
                .font(.headline)
                .foregroundColor(manager.appTextColor)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Элементов в ряду:")
                        .font(.subheadline)
                        .foregroundColor(manager.appTextColor)
                    Spacer()
                    Picker("Колонки", selection: $gridColumnsCount) {
                        Text("2").tag(2)
                        Text("3").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                
                HStack {
                    Text("Сортировка:")
                        .font(.subheadline)
                        .foregroundColor(manager.appTextColor)
                    Spacer()
                    Picker("Сортировка", selection: $fileSortOption) {
                        Text("Популярные").tag(1)
                        Text("Новые").tag(0)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .if(!manager.currentTheme.usesSystemAppearance) { content in
            content
                .tint(manager.accentColor)
                .presentationCornerRadius(24)
        }
    }
    
    // MARK: - Загрузка данных

    private func loadInitialItems() async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil
        currentStart = 1
        hasMorePages = true
        items.removeAll()
        loadedAnimations.removeAll()
        isFetchingPage = false
        isLoadingMore = false
        scrollTracker.lastVisibleIndex = 0

        do {
            let fetchStarted = Date()
            let result = try await fetchItems(1, pageSize, fileSortOption)
            let fetchMs = Int(Date().timeIntervalSince(fetchStarted) * 1000)
            divoomGridPerfLog.debug("metadata initial fetch=\(fetchMs)ms count=\(result.items.count)")
            guard generation == loadGeneration else { return }

            // Метаданные сразу идут в UI. Картинки появятся по мере загрузки.
            items = result.items
            currentStart = 1 + result.items.count
            applyPageSize(result)
            isLoading = false

            if !result.items.isEmpty {
                Task {
                    await revealAnimations(for: result.items, generation: generation)
                }
            }
        } catch {
            guard generation == loadGeneration else { return }
            errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Короткая страница — норма для галереи: часть элементов может быть
    /// недоступна, но нумерация `StartNum` продолжается. Останавливаемся только когда
    /// сервер вернул пустой ответ.
    private func applyPageSize(_ result: (items: [DivoomFileItem], curListNum: Int)) {
        if result.items.isEmpty {
            hasMorePages = false
        }
    }

    /// Metadata следующей страницы вставляем в сетку сразу после ответа.
    /// Анимации грузятся отдельной задачей и появляются постепенно —
    /// пользователь не ждёт, пока скачаются все 30 файлов.
    private func loadNextPage() async {
        guard !isFetchingPage, hasMorePages, !isLoading else { return }
        isFetchingPage = true
        isLoadingMore = true
        defer {
            isFetchingPage = false
            isLoadingMore = false
        }

        let generation = loadGeneration
        let start = currentStart
        let result: (items: [DivoomFileItem], curListNum: Int)
        do {
            let fetchStarted = Date()
            result = try await fetchItems(start, start + pageSize - 1, fileSortOption)
            let fetchMs = Int(Date().timeIntervalSince(fetchStarted) * 1000)
            divoomGridPerfLog.debug("metadata next start=\(start) fetch=\(fetchMs)ms count=\(result.items.count)")
        } catch {
            return
        }
        guard generation == loadGeneration else { return }

        if result.items.isEmpty {
            hasMorePages = false
            return
        }

        let existing = Set(items.map(\.id))
        let unique = result.items.filter { !existing.contains($0.id) }
        if !unique.isEmpty {
            items.append(contentsOf: unique)
            Task {
                await revealAnimations(for: unique, generation: generation)
            }
        }
        currentStart = start + result.items.count
        applyPageSize(result)
    }

    private func refreshItems() async {
        await loadInitialItems()
    }

    /// Сразу грузим полную анимацию и показываем ячейку, как только она готова.
    /// Никакого промежуточного статичного кадра: metadata появляется мгновенно,
    /// анимации — по мере загрузки, без ожидания всей страницы.
    private func revealAnimations(for list: [DivoomFileItem], generation: Int) async {
        let targets = list.compactMap { item -> String? in
            guard let fileId = item.FileId, !fileId.isEmpty,
                  loadedAnimations[fileId] == nil else { return nil }
            return fileId
        }
        guard !targets.isEmpty else { return }

        let uniqueTargetCount = Set(targets).count
        divoomGridPerfLog.debug("animations start items=\(list.count) targets=\(targets.count) unique=\(uniqueTargetCount) missingFileId=\(list.count - targets.count)")
        let batchStarted = Date()
        defer {
            let totalMs = Int(Date().timeIntervalSince(batchStarted) * 1000)
            let missing = list.filter { item in
                guard let fileId = item.FileId, !fileId.isEmpty else { return true }
                return loadedAnimations[fileId] == nil
            }
            let missingIds = missing.compactMap(\.FileId).prefix(5)
            divoomGridPerfLog.debug(
                "animations batch count=\(targets.count) loaded=\(loadedAnimations.count) missing=\(missing.count) ids=\(missingIds) total=\(totalMs)ms"
            )
        }

        await withTaskGroup(of: (String, UIImage?).self) { group in
            var iterator = targets.makeIterator()

            func scheduleNext() {
                guard let fileId = iterator.next() else { return }
                group.addTask {
                    let result = await DivoomAnimationLoader.loadAndCreateAnimation(from: fileId)
                    return (fileId, result?.image)
                }
            }

            for _ in 0..<min(DivoomAnimationLoader.animationFetchConcurrency, targets.count) {
                scheduleNext()
            }

            for await (fileId, image) in group {
                guard generation == loadGeneration else {
                    group.cancelAll()
                    return
                }
                if let image {
                    await MainActor.run {
                        loadedAnimations[fileId] = image
                    }
                }
                scheduleNext()
            }
        }
    }
}
