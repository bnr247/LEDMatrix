//
//  DivoomCategoriesView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 31.10.2026.
//

import SwiftUI

struct DivoomCategoryModel: Identifiable, Hashable {
    let id: Int
    let name: String
}

struct DivoomCategoriesView: View {
    @ObservedObject var manager: MatrixManager
    
    let categories: [DivoomCategoryModel] = [
        DivoomCategoryModel(id: 0, name: "New"),
        DivoomCategoryModel(id: 20, name: "Follow"),
        DivoomCategoryModel(id: 30, name: "Haunted 2026"),
        DivoomCategoryModel(id: 18, name: "Recommend"),
        DivoomCategoryModel(id: 3, name: "Character"),
        DivoomCategoryModel(id: 17, name: "Festival"),
        DivoomCategoryModel(id: 4, name: "Emoji"),
        DivoomCategoryModel(id: 8, name: "Pattern"),
        DivoomCategoryModel(id: 9, name: "Creative"),
        DivoomCategoryModel(id: 6, name: "Nature"),
        DivoomCategoryModel(id: 5, name: "Daily"),
        DivoomCategoryModel(id: 15, name: "Gadget"),
        DivoomCategoryModel(id: 7, name: "Icon"),
        DivoomCategoryModel(id: 16, name: "Business"),
        DivoomCategoryModel(id: 1, name: "Default"),
        DivoomCategoryModel(id: 40, name: "AI"),
        DivoomCategoryModel(id: 12, name: "Photo")
    ]
    
    @State private var selectedCategoryId: Int = 0
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
    
    @State private var alertMessage: String? = nil
    @State private var isShowingAlert = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories) { category in
                        Button(action: {
                            if selectedCategoryId != category.id {
                                selectedCategoryId = category.id
                                Task { await loadInitialItems() }
                            }
                        }) {
                            Text(category.name)
                                .font(selectedCategoryId == category.id ? .subheadline.bold() : .subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedCategoryId == category.id ? Color.accentColor : Color.secondary.opacity(0.15))
                                .foregroundColor(selectedCategoryId == category.id ? .white : .primary)
                                .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(UIColor.systemBackground))
            
            Divider()
            
            Group {
                if isLoading && items.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView()
                        Text("Загрузка категории...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else if let error = errorMessage, items.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Повторить") {
                            Task { await loadInitialItems() }
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(items) { item in
                                ZStack(alignment: .bottomLeading) {
                                    Group {
                                        if let fileId = item.FileId, let animImage = loadedAnimations[fileId] {
                                            AnimatedImageView(image: animImage)
                                                .aspectRatio(1, contentMode: .fit)
                                        } else {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.15))
                                                .overlay(ProgressView().tint(.white))
                                                .aspectRatio(1, contentMode: .fit)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    if let fileId = item.FileId,
                                       let firstByte = firstBytes[fileId],
                                       let rawSpeed = rawSpeeds[fileId]
                                    {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("Speed: \(rawSpeed)")
                                            Text("Size: \(item.FileSize ?? 0)")
                                            Text("Type: \(String(format: "%02X", firstByte)) (\(firstByte))")
                                        }
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundColor(.green)
                                        .padding(3)
                                        .background(Color.black.opacity(0.75))
                                        .cornerRadius(3)
                                        .padding(4)
                                    }
                                }
                                .background(Color.black)
                                .onAppear {
                                    if item.id == items.last?.id {
                                        Task { await loadMoreItems() }
                                    }
                                }
                            }
                        }
                        
                        if isLoadingMore {
                            ProgressView()
                                .padding()
                        }
                    }
                    .background(Color.black)
                    .refreshable {
                        await refreshItems()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    sendCategoryCommand()
                }) {
                    Image(systemName: "play.rectangle")
                }
            }
        }
        .alert("Категории", isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .task {
            if items.isEmpty {
                await loadInitialItems()
            }
        }
    }
    
    private func sendCategoryCommand() {
        let currentCategory = categories.first(where: { $0.id == selectedCategoryId })
        let categoryName = currentCategory?.name ?? "Категория"
        
        Task {
            do {
                // Передаем энум напрямую в менеджер, никакой ручной сборки словарей в View
                try await manager.updateAnimationType(.category(id: selectedCategoryId))
                
                await MainActor.run {
                    self.alertMessage = "\(categoryName) воспроизводится на устройстве"
                    self.isShowingAlert = true
                }
            } catch {
                await MainActor.run {
                    self.alertMessage = "Ошибка отправки: \(error.localizedDescription)"
                    self.isShowingAlert = true
                }
            }
        }
    }
    
    private func loadInitialItems() async {
        isLoading = true
        errorMessage = nil
        currentStart = 1
        hasMorePages = true
        items.removeAll()
        
        let endNum = currentStart + pageSize - 1
        do {
            let response = try await manager.fetchDivoomCategoryImages(categoryId: selectedCategoryId, startNum: currentStart, endNum: endNum, refreshIndex: 0)
            let fetchedItems = response.FileList ?? []
            let curListNum = response.CurListNum ?? fetchedItems.count
            
            items = fetchedItems
            isLoading = false
            
            if curListNum < pageSize {
                hasMorePages = false
            } else {
                currentStart += pageSize
            }
            
            fetchAnimations(for: fetchedItems)
        } catch {
            errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func loadMoreItems() async {
        guard !isLoadingMore, hasMorePages else { return }
        isLoadingMore = true
        
        let endNum = currentStart + pageSize - 1
        do {
            let response = try await manager.fetchDivoomCategoryImages(categoryId: selectedCategoryId, startNum: currentStart, endNum: endNum, refreshIndex: 0)
            let fetchedItems = response.FileList ?? []
            let curListNum = response.CurListNum ?? fetchedItems.count
            
            if !fetchedItems.isEmpty {
                items.append(contentsOf: fetchedItems)
                fetchAnimations(for: fetchedItems)
            }
            
            if curListNum < pageSize {
                hasMorePages = false
            } else {
                currentStart += pageSize
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
            let response = try await manager.fetchDivoomCategoryImages(categoryId: selectedCategoryId, startNum: currentStart, endNum: endNum, refreshIndex: 1)
            let fetchedItems = response.FileList ?? []
            let curListNum = response.CurListNum ?? fetchedItems.count
            
            items = fetchedItems
            
            if curListNum < pageSize {
                hasMorePages = false
            } else {
                currentStart += pageSize
            }
            
            fetchAnimations(for: fetchedItems)
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
