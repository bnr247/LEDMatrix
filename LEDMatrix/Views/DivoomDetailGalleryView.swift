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
    @State private var errorMessage: String? = nil
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Загрузка элементов альбома...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                    Button("Повторить") {
                        Task { await loadItems() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                List(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.FileName ?? "Без названия")
                            .font(.headline)
                        
                        if let content = item.Content, !content.isEmpty {
                            Text(content)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(album.AlbumName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadItems()
        }
    }
    
    private func loadItems() async {
        isLoading = true
        errorMessage = nil
        do {
            // ИСПОЛЬЗУЕМ .stringValue для преобразования DivoomID в String
            items = try await manager.fetchDivoomAlbumImages(albumId: album.AlbumId.stringValue)
        } catch {
            errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
