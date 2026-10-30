//
//  DivoomTab.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 30.10.2026.
//

import SwiftUI

struct DivoomTab: View {
    @ObservedObject var manager: MatrixManager
    
    @State private var albums: [DivoomAlbum] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Авторизация и загрузка альбомов...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Повторить попытку") {
                            Task { await loadAlbums() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(albums) { album in
                                NavigationLink(destination: DivoomDetailGalleryView(manager: manager, album: album)) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        CachedAsyncImage(url: URL(string: "https://f.divoom-gz.com/" + album.AlbumImageId)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .overlay(ProgressView())
                                        }
                                        .frame(height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        
                                        Text(album.AlbumName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                            .padding(.horizontal, 4)
                                    }
                                    .padding(8)
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                }
                            }
                        }
                        .padding(16)
                    }
                    .background(Color(UIColor.systemGroupedBackground))
                }
            }
            .navigationTitle("Галерея Divoom")
            .refreshable {
                await loadAlbums()
            }
        }
        .task {
            if albums.isEmpty {
                await loadAlbums()
            }
        }
    }
    
    private func loadAlbums() async {
        isLoading = true
        errorMessage = nil
        do {
            albums = try await manager.fetchDivoomAlbums()
        } catch {
            errorMessage = "Не удалось загрузить альбомы: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
