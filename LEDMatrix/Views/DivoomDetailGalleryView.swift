//
//  DivoomDetailGalleryView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 30.10.2026.
//

import SwiftUI

struct DivoomDetailGalleryView: View {
    @ObservedObject var manager: MatrixManager
    let album: DivoomAlbum
    
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
        Group {
            if isLoading && items.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Загрузка элементов альбома...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
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
                                        Text("1st: 0x\(String(format: "%02X", firstByte)) (\(firstByte))")
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
        .navigationTitle(album.AlbumName)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    sendAlbumCommand()
                }) {
                    Image(systemName: "play.rectangle")
                }
            }
        }
        .alert("Альбомы", isPresented: $isShowingAlert) {
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
    
    private func sendAlbumCommand() {
        let albumIdInt = Int(album.AlbumId) ?? 0
        
        Task {
            do {
                // Используем метод менеджера вместо прямого вызова sendCommand с JSON-словарем
                try await manager.updateAnimationType(.album(id: albumIdInt))
                
                await MainActor.run {
                    self.alertMessage = "\(album.AlbumName) воспроизводится на устройстве"
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
        
        let endNum = currentStart + pageSize - 1
        do {
            let response = try await manager.fetchDivoomAlbumImages(albumId: album.AlbumId, startNum: currentStart, endNum: endNum, refreshIndex: 0)
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
            let response = try await manager.fetchDivoomAlbumImages(albumId: album.AlbumId, startNum: currentStart, endNum: endNum, refreshIndex: 0)
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
            let response = try await manager.fetchDivoomAlbumImages(albumId: album.AlbumId, startNum: currentStart, endNum: endNum, refreshIndex: 1)
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
