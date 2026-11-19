//
//  DivoomUniversalGridView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 07.11.2026.
//

import SwiftUI

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

    // Первые кадры уже загруженной страницы — ячейки показывают их сразу.
    @State private var revealedImages: [String: UIImage] = [:]
    // Следующая страница грузится заранее, пока пользователь листает текущую.
    @State private var prefetchedItems: [DivoomFileItem] = []
    @State private var prefetchedImages: [String: UIImage] = [:]
    @State private var prefetchedNextStart = 1
    @State private var isPrefetching = false
    @State private var isAwaitingNextPage = false
    @State private var prefetchGeneration = 0
    private let nearEndThreshold = 15
    
    @State private var isShowingSettingsSheet = false
    @State private var scrollPositionId: String? = nil
    // Позиция последней показанной ячейки: нужна, чтобы вставить уже
    // подготовленную страницу, даже если пользователь остановился у края.
    @State private var scrollTracker = GridScrollTracker()
    
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
                                            image: revealedImages[item.FileId ?? ""]
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .id(item.id)
                                    .onAppear {
                                        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
                                        scrollTracker.lastVisibleIndex = index
                                        // Половина страницы — начинаем грузить следующую заранее.
                                        if index >= items.count / 2 {
                                            Task { await prefetchNextPage() }
                                        }
                                        // Почти конец — подключаем уже подготовленную страницу.
                                        if index >= items.count - nearEndThreshold {
                                            Task { await ensureNextPage() }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 2) // Аккуратные отступы от краев экрана, как в iOS Фото
                                        
                            if isLoadingMore {
                                ProgressView()
                                    .tint(manager.accentColor)
                                    .padding(.vertical, 20)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .safeAreaPadding(.bottom, 80) // Системный отступ под таббар/индикатор
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
        // .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $isShowingSettingsSheet) {
            gallerySettingsSheet
                .presentationDetents([.height(260)])
                .presentationBackground(manager.backgroundColor)
        }
        .task(id: fileSortOption) {
            if items.isEmpty {
                await loadInitialItems()
            }
        }
    }
    
    private var gallerySettingsSheet: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(manager.secondaryTextColor.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
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
        .tint(manager.accentColor)
        .presentationCornerRadius(24)
    }
    
    private func loadInitialItems() async {
        isLoading = true
        errorMessage = nil
        prefetchGeneration += 1
        let generation = prefetchGeneration

        currentStart = 1
        hasMorePages = true
        items.removeAll()
        revealedImages.removeAll()
        prefetchedItems.removeAll()
        prefetchedImages.removeAll()
        isPrefetching = false
        isAwaitingNextPage = false

        do {
            let result = try await fetchItems(currentStart, currentStart + pageSize - 1, fileSortOption)
            guard generation == prefetchGeneration else { return }

            items = result.items
            isLoading = false

            if result.items.isEmpty {
                hasMorePages = false
            } else {
                currentStart = 1 + result.items.count
                // Текущую страницу показываем сразу, кадры грузим порциями по порядку.
                Task { await loadFirstFramesProgressively(for: result.items, generation: generation) }
                Task { await prefetchNextPage(generation: generation) }
            }
        } catch {
            guard generation == prefetchGeneration else { return }
            errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Подгружает метаданные и первые кадры следующей страницы заранее.
    private func prefetchNextPage(generation: Int? = nil) async {
        let gen = generation ?? prefetchGeneration
        guard !isPrefetching, hasMorePages, prefetchedItems.isEmpty else { return }
        isPrefetching = true

        let start = currentStart
        let result: (items: [DivoomFileItem], curListNum: Int)
        do {
            result = try await fetchItems(start, start + pageSize - 1, fileSortOption)
        } catch {
            if gen == prefetchGeneration { isPrefetching = false }
            return
        }
        guard gen == prefetchGeneration else { return }

        if result.items.isEmpty {
            hasMorePages = false
            isPrefetching = false
            return
        }

        let existing = Set(items.map(\.id)).union(prefetchedItems.map(\.id))
        let unique = result.items.filter { !existing.contains($0.id) }
        let images = await loadFirstFrames(for: unique)
        guard gen == prefetchGeneration else { return }

        prefetchedItems = unique
        prefetchedImages = images
        prefetchedNextStart = start + result.items.count
        isPrefetching = false

        // Пользователь уже запросил следующую страницу, но предзагрузка была
        // ещё не готова. Вставляем её сразу по завершении — без повторного
        // скролла и дерганья списка.
        let shouldAppend = isAwaitingNextPage || scrollTracker.lastVisibleIndex >= items.count - nearEndThreshold
        if shouldAppend {
            isAwaitingNextPage = false
            _ = appendPrefetchedPage()
        }
    }

    /// Если следующая страница уже подготовлена — вставляем её без ожидания.
    private func appendPrefetchedPage() -> Bool {
        guard !prefetchedItems.isEmpty else { return false }

        let page = prefetchedItems
        let images = prefetchedImages
        let nextStart = prefetchedNextStart
        let generation = prefetchGeneration

        items.append(contentsOf: page)
        revealedImages.merge(images) { _, new in new }
        prefetchedItems.removeAll()
        prefetchedImages.removeAll()
        currentStart = nextStart
        isAwaitingNextPage = false

        Task { await prefetchNextPage(generation: generation) }
        return true
    }

    private func ensureNextPage() async {
        if appendPrefetchedPage() { return }

        // Запоминаем намерение: как только предзагрузка закончится, страница
        // будет вставлена автоматически, даже если ячейки больше не появятся.
        isAwaitingNextPage = true
        if isPrefetching { return }
        await loadMoreItems()
    }

    private func loadMoreItems() async {
        guard !isLoadingMore, !isPrefetching, hasMorePages, prefetchedItems.isEmpty else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let generation = prefetchGeneration
        let start = currentStart
        do {
            let result = try await fetchItems(start, start + pageSize - 1, fileSortOption)
            guard generation == prefetchGeneration else { return }

            if result.items.isEmpty {
                hasMorePages = false
                return
            }

            let existing = Set(items.map(\.id)).union(prefetchedItems.map(\.id))
            let unique = result.items.filter { !existing.contains($0.id) }
            let images = await loadFirstFrames(for: unique)
            guard generation == prefetchGeneration else { return }

            items.append(contentsOf: unique)
            revealedImages.merge(images) { _, new in new }
            currentStart = start + result.items.count
            isAwaitingNextPage = false
            Task { await prefetchNextPage(generation: generation) }
        } catch {}
    }

    private func refreshItems() async {
        isLoading = true
        prefetchGeneration += 1
        let generation = prefetchGeneration

        currentStart = 1
        hasMorePages = true
        items.removeAll()
        revealedImages.removeAll()
        prefetchedItems.removeAll()
        prefetchedImages.removeAll()
        isPrefetching = false
        isAwaitingNextPage = false

        do {
            let result = try await fetchItems(currentStart, currentStart + pageSize - 1, fileSortOption)
            guard generation == prefetchGeneration else { return }

            items = result.items

            if result.items.isEmpty {
                hasMorePages = false
            } else {
                currentStart = 1 + result.items.count
                Task { await loadFirstFramesProgressively(for: result.items, generation: generation) }
                Task { await prefetchNextPage(generation: generation) }
            }
        } catch {}
        isLoading = false
    }

    /// Показываем текущую страницу сразу, но подгружаем её первые кадры
    /// небольшими порциями строго сверху вниз — без ожидания всех 30 файлов
    /// и без хаотичного заполнения ячеек.
    private func loadFirstFramesProgressively(for list: [DivoomFileItem], generation: Int) async {
        let targets = list.enumerated().compactMap { index, item -> (order: Int, fileId: String)? in
            guard let fileId = item.FileId, !fileId.isEmpty,
                  revealedImages[fileId] == nil else { return nil }
            return (index, fileId)
        }
        guard !targets.isEmpty else { return }

        let batchSize = 6
        var cursor = 0

        while cursor < targets.count {
            let end = min(cursor + batchSize, targets.count)
            let batch = Array(targets[cursor..<end])
            let fileIds = Dictionary(uniqueKeysWithValues: batch.map { ($0.order, $0.fileId) })

            let ordered = await withTaskGroup(
                of: (Int, UIImage?).self,
                returning: [(String, UIImage)].self
            ) { group in
                for target in batch {
                    group.addTask {
                        let image = await DivoomAnimationLoader.loadFirstFrame(from: target.fileId)
                        return (target.order, image)
                    }
                }

                var collected: [Int: UIImage] = [:]
                for await (order, image) in group {
                    if let image { collected[order] = image }
                }

                return collected.keys.sorted().compactMap { order in
                    guard let image = collected[order], let fileId = fileIds[order] else { return nil }
                    return (fileId, image)
                }
            }

            guard generation == prefetchGeneration else { return }
            for (fileId, image) in ordered {
                revealedImages[fileId] = image
            }
            cursor = end
        }
    }

    /// Быстрая загрузка первых кадров для скрытой следующей страницы.
    private func loadFirstFrames(for list: [DivoomFileItem]) async -> [String: UIImage] {
        let targets = list.compactMap { item -> String? in
            guard let fileId = item.FileId, !fileId.isEmpty, revealedImages[fileId] == nil else { return nil }
            return fileId
        }
        guard !targets.isEmpty else { return [:] }

        var loaded: [String: UIImage] = [:]
        let batchSize = 12
        var index = 0

        while index < targets.count {
            let end = min(index + batchSize, targets.count)
            let batch = targets[index..<end]

            let batchLoaded = await withTaskGroup(
                of: (String, UIImage?).self,
                returning: [String: UIImage].self
            ) { group in
                for fileId in batch {
                    group.addTask {
                        let image = await DivoomAnimationLoader.loadFirstFrame(from: fileId)
                        return (fileId, image)
                    }
                }
                var result: [String: UIImage] = [:]
                for await (fileId, image) in group {
                    if let image { result[fileId] = image }
                }
                return result
            }
            loaded.merge(batchLoaded) { _, new in new }
            index = end
        }

        return loaded
    }
}
