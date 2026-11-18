//
//  DivoomTab.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 30.10.2026.
//

import SwiftUI

struct DivoomAlbumsView: View {
    @ObservedObject var manager: MatrixManager
    
    @State private var albums: [DivoomAlbum] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Загрузка альбомов...")
                        .font(.subheadline)
                        .foregroundColor(manager.accentColor)
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(manager.dangerColor)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(manager.appTextColor)
                    Button("Повторить попытку") {
                        Task { await loadAlbums() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(manager.accentColor)
                    
                }
                .padding()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(albums) { album in
                            NavigationLink(destination: DivoomAlbumDetailView(manager: manager, album: album)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    CachedAsyncImage(url: URL(string: "https://fin.divoom-gz.com/" + album.AlbumImageId)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle()
                                            .fill(manager.fieldBackgroundColor)
                                            .overlay(
                                                ProgressView()
                                                    .tint(manager.accentColor)
                                            )
                                    }
                                    .frame(height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    
                                    Text(album.AlbumName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(manager.accentColor)
                                        .lineLimit(1)
                                        .padding(.horizontal, 4)
                                }
                                .padding(8)
                                .themedCard(manager, cornerRadius: 16)
                            }
                        }
                    }
                    .padding(16)
                }
                .background(manager.backgroundColor.ignoresSafeArea())
            }
        }
        .background(manager.backgroundColor.ignoresSafeArea())
        .refreshable {
            await loadAlbums()
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
