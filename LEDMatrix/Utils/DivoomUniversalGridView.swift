//
//  DivoomUniversalGridView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 07.11.2026.
//

import SwiftUI

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
        
    @State private var loadedAnimations: [String: UIImage] = [:]
    @State private var firstBytes: [String: UInt8] = [:]
    @State private var rawSpeeds: [String: UInt16] = [:]
        
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.15))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
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
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black)
            
            Divider()
                .background(Color.secondary.opacity(0.3))

            Group {
                if isLoading && items.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Загрузка галереи...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage, items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Повторить") {
                            Task { await loadInitialItems() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    Text("Нет элементов")
                        .foregroundColor(.secondary)
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
                                        AnimatedImageView(manager: manager, item: item, image: loadedAnimations[item.FileId ?? ""])
                                    }
                                    .buttonStyle(.plain)
                                    .id(item.id)
                                    .onAppear {
                                        if let index = items.firstIndex(where: { $0.id == item.id }),
                                           index >= items.count - 8
                                        {
                                            Task { await loadMoreItems() }
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
                    .background(.black)
                    .refreshable {
                        await refreshItems()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
        // .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $isShowingSettingsSheet) {
            gallerySettingsSheet
                .presentationDetents([.height(260)])
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
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            Text("Настройки галереи")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Элементов в ряду:")
                        .font(.subheadline)
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
        .presentationCornerRadius(24)
    }
    
    private func loadInitialItems() async {
        isLoading = true
        errorMessage = nil
        currentStart = 1
        hasMorePages = true
        items.removeAll()
        
        let endNum = currentStart + pageSize - 1
        do {
            let result = try await fetchItems(currentStart, endNum, fileSortOption)
            items = result.items
            isLoading = false
            
            if result.items.isEmpty {
                hasMorePages = false
            } else {
                currentStart = items.count + 1
            }
            
            fetchAnimations(for: result.items)
        } catch {
            errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func loadMoreItems() async {
        guard !isLoadingMore, hasMorePages else { return }
        isLoadingMore = true
            
        currentStart = items.count + 1
        let endNum = currentStart + pageSize - 1
        
        do {
            let result = try await fetchItems(currentStart, endNum, fileSortOption)
            if !result.items.isEmpty {
                let existingIds = Set(items.map { $0.id })
                let uniqueNewItems = result.items.filter { !existingIds.contains($0.id) }
                
                if !uniqueNewItems.isEmpty {
                    items.append(contentsOf: uniqueNewItems)
                    fetchAnimations(for: uniqueNewItems)
                }
                
                if result.items.isEmpty {
                    hasMorePages = false
                }
            } else {
                hasMorePages = false
            }
                
            isLoadingMore = false
        } catch {
            isLoadingMore = false
        }
    }
    
    private func refreshItems() async {
        currentStart = 1
        hasMorePages = true
        let endNum = currentStart + pageSize - 1
        
        do {
            let result = try await fetchItems(currentStart, endNum, fileSortOption)
            items = result.items
            
            if result.items.isEmpty {
                hasMorePages = false
            } else {
                currentStart = items.count + 1
            }
            
            fetchAnimations(for: result.items)
        } catch {}
    }
    
    private func fetchAnimations(for list: [DivoomFileItem]) {
        for item in list {
            guard let fileId = item.FileId, !fileId.isEmpty else { continue }
            Task.detached(priority: .background) {
                if let result = await DivoomAnimationLoader.loadAndCreateAnimation(from: fileId) {
                    await MainActor.run {
                        self.loadedAnimations[fileId] = result.image
                        self.firstBytes[fileId] = result.firstByte
                        self.rawSpeeds[fileId] = result.rawSpeed
                    }
                }
            }
        }
    }
}
