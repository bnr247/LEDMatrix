//
//  DivoomFeedView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 07.11.2026.
//

import OSLog
import SwiftUI
import UIKit

private let divoomFeedPerfLog = Logger(subsystem: "com.stanislavleonov.LedMatrix", category: "divoom.feed")

struct DivoomFeedView: View {
    let title: String
    @ObservedObject var manager: MatrixManager
    
    let initialItems: [DivoomFileItem]
    /// Уже загруженные сеткой полные анимации — фид показывает их сразу,
    /// а не начинает загрузку заново с плейсхолдеров.
    let initialImages: [String: UIImage]
    let selectedItemId: String
    let fetchMoreItems: (_ startNum: Int, _ endNum: Int) async throws -> [DivoomFileItem]
    let onScrollPositionChanged: ((String?) -> Void)? // <--- Добавлено
    
    init(
        title: String,
        manager: MatrixManager,
        initialItems: [DivoomFileItem],
        initialImages: [String: UIImage] = [:],
        selectedItemId: String,
        fetchMoreItems: @escaping (_ startNum: Int, _ endNum: Int) async throws -> [DivoomFileItem],
        onScrollPositionChanged: ((String?) -> Void)? = nil
    ) {
        self.title = title
        self.manager = manager
        self.initialItems = initialItems
        self.initialImages = initialImages
        self.selectedItemId = selectedItemId
        self.fetchMoreItems = fetchMoreItems
        self.onScrollPositionChanged = onScrollPositionChanged
    }
    
    @State private var items: [DivoomFileItem] = []
    @State private var loadedAnimations: [String: UIImage] = [:]
    @State private var loadedAvatars: [String: UIImage] = [:]
    @State private var isLoadingMore = false
    @State private var hasMorePages = true
    @State private var currentStart = 1
    @State private var scrollPositionId: String? = nil
    // Привязка позиции к верхнему краю делает snap предсказуемым: активным
    // считается именно верхний пост, а не ближайший по центру.
    @State private var isRestoringPosition = false
    @State private var lastSnappedId: String? = nil
    @State private var hapticTask: Task<Void, Never>?
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)
    @State private var loadGeneration = 0
    private let pageSize = 30
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(items) { item in
                        DivoomFeedItemView(
                            manager: manager,
                            item: item,
                            animationImage: loadedAnimations[item.FileId ?? ""],
                            avatarImage: loadedAvatars[item.UserHeaderId ?? ""]
                        )
                        .id(item.id)
                        .onAppear {
                            if item.id == items.last?.id {
                                Task { await loadMore() }
                            }
                        }
                    }
                    
                    if isLoadingMore {
                        ProgressView()
                            .tint(manager.accentColor)
                            .padding()
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $scrollPositionId, anchor: .top)
            .onChange(of: scrollPositionId) { _, newId in
                guard !isRestoringPosition else { return }
                onScrollPositionChanged?(newId)

                // Смена верхнего поста означает, что порог перелистывания
                // пройден. Небольшая задержка отсекает дрожание/откат пальца:
                // стук и добирание до верха срабатывают только один раз.
                guard newId != lastSnappedId else { return }
                lastSnappedId = newId

                hapticTask?.cancel()
                if let newId {
                    hapticTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(110))
                        guard !Task.isCancelled, scrollPositionId == newId else { return }
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                            proxy.scrollTo(newId, anchor: .top)
                        }
                        feedbackGenerator.impactOccurred()
                    }
                }

                if let id = newId, let item = items.first(where: { $0.id == id }), let galleryId = item.GalleryId, !galleryId.isEmpty {
                    Task {
                        await manager.addDivoomWatch(galleryId: galleryId, classify: item.Classify)
                    }
                }
            }
            .onAppear { feedbackGenerator.prepare() }
            .background(manager.backgroundColor)
            .ignoresSafeArea(edges: .bottom)
            .themedNavigationTitle(title, manager: manager)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if items.isEmpty {
                    loadGeneration += 1
                    // Анимации из сетки уже готовы: посты отображаются сразу,
                    // повторно качать и разбирать их не нужно.
                    var images = initialImages
                    let passedCount = images.count
                    var cacheHits = 0
                    for item in initialItems {
                        guard let fileId = item.FileId, images[fileId] == nil,
                              let cached = DivoomAnimationLoader.cachedAnimation(for: fileId) else { continue }
                        images[fileId] = cached
                        cacheHits += 1
                    }
                    divoomFeedPerfLog.debug(
                        "init items=\(initialItems.count) passed=\(passedCount) cacheHits=\(cacheHits) missing=\(initialItems.count - images.count)"
                    )
                    loadedAnimations = images
                    items = initialItems
                    currentStart = initialItems.count + 1
                    prefetchAnimations(for: initialItems)
                    preloadAvatars(for: initialItems)
                    
                    isRestoringPosition = true
                    lastSnappedId = selectedItemId
                    scrollPositionId = selectedItemId
                    
                    try? await Task.sleep(for: .milliseconds(50))
                    withAnimation(.none) {
                        proxy.scrollTo(selectedItemId, anchor: .top)
                    }
                    try? await Task.sleep(for: .milliseconds(150))
                    isRestoringPosition = false
                    
                    if let initialItem = initialItems.first(where: { $0.id == selectedItemId }), let galleryId = initialItem.GalleryId, !galleryId.isEmpty {
                        await manager.addDivoomWatch(galleryId: galleryId, classify: initialItem.Classify)
                    }
                }
            }
        }
    }
    
    private func loadMore() async {
        guard !isLoadingMore, hasMorePages else { return }
        isLoadingMore = true
        
        let endNum = currentStart + pageSize - 1
        do {
            let fetched = try await fetchMoreItems(currentStart, endNum)
            if fetched.isEmpty {
                hasMorePages = false
            } else {
                items.append(contentsOf: fetched)
                currentStart += fetched.count
                prefetchAnimations(for: fetched)
                preloadAvatars(for: fetched)
            }
        } catch {}
        
        isLoadingMore = false
    }
    
    /// Посты добавляются в список сразу. Полные анимации приходят по одной и
    /// сразу подставляются в ячейку — нет ожидания всей пачки и нет
    /// промежуточного статичного кадра вместо анимации.
    private func prefetchAnimations(for list: [DivoomFileItem]) {
        let targets = list.compactMap { item -> String? in
            guard let fileId = item.FileId, !fileId.isEmpty,
                  loadedAnimations[fileId] == nil else { return nil }
            return fileId
        }
        guard !targets.isEmpty else { return }

        let generation = loadGeneration
        let started = Date()
        let concurrency = DivoomAnimationLoader.animationFetchConcurrency
        Task.detached(priority: .utility) {
            await withTaskGroup(of: (String, UIImage?).self) { group in
                var iterator = targets.makeIterator()

                func scheduleNext() {
                    guard let fileId = iterator.next() else { return }
                    group.addTask {
                        let result = await DivoomAnimationLoader.loadAndCreateAnimation(from: fileId)
                        return (fileId, result?.image)
                    }
                }

                for _ in 0..<min(concurrency, targets.count) { scheduleNext() }

                for await (fileId, image) in group {
                    guard !Task.isCancelled else {
                        group.cancelAll()
                        return
                    }
                    if let image {
                        await MainActor.run {
                            guard generation == self.loadGeneration else { return }
                            self.loadedAnimations[fileId] = image
                        }
                    }
                    scheduleNext()
                }
            }
            let totalMs = Int(Date().timeIntervalSince(started) * 1000)
            await MainActor.run {
                let missing = list.filter { item in
                    guard let fileId = item.FileId, !fileId.isEmpty else { return true }
                    return loadedAnimations[fileId] == nil
                }
                let missingIds = missing.compactMap(\.FileId).prefix(5)
                divoomFeedPerfLog.debug(
                    "animations batch count=\(targets.count) loaded=\(loadedAnimations.count) missing=\(missing.count) ids=\(missingIds) total=\(totalMs)ms"
                )
            }
        }
    }
    
    /// Аватар — крошечная иконка 36pt, полный разбор сотен кадров здесь
    /// не нужен. Берём только первый кадр.
    private func preloadAvatars(for list: [DivoomFileItem]) {
        let headerIds = Array(Set(list.compactMap { item -> String? in
            guard let headerId = item.UserHeaderId, !headerId.isEmpty,
                  loadedAvatars[headerId] == nil else { return nil }
            return headerId
        }))
        guard !headerIds.isEmpty else { return }

        let generation = loadGeneration
        Task.detached(priority: .background) {
            await withTaskGroup(of: (String, UIImage?).self) { group in
                var iterator = headerIds.makeIterator()

                func scheduleNext() {
                    guard let headerId = iterator.next() else { return }
                    group.addTask {
                        (headerId, await DivoomAnimationLoader.loadFirstFrame(from: headerId))
                    }
                }

                for _ in 0..<min(4, headerIds.count) { scheduleNext() }

                for await (headerId, image) in group {
                    guard !Task.isCancelled else {
                        group.cancelAll()
                        return
                    }
                    if let image {
                        await MainActor.run {
                            guard generation == self.loadGeneration else { return }
                            self.loadedAvatars[headerId] = image
                        }
                    }
                    scheduleNext()
                }
            }
        }
    }
}

/// Карточка поста
