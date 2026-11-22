//
//  DivoomPlaylistsView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 07.11.2026.
//

import SwiftUI

struct DivoomPlaylistsView: View {
    @ObservedObject var manager: MatrixManager
    // Увеличивается родителем после создания плейлиста из навбара.
    let refreshTrigger: Int
    
    @State private var playlists: [DivoomPlaylist] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String? = nil
    
    @State private var hasMorePages = true
    @State private var currentStart = 1
    private let pageSize = 30
    
    // Состояния для подтверждения удаления
    @State private var playlistToDelete: DivoomPlaylist? = nil
    @State private var isShowingDeleteAlert = false
    
    var body: some View {
        Group {
            if isLoading && playlists.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Загрузка плейлистов...")
                        .font(.subheadline)
                        .foregroundColor(manager.secondaryTextColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, playlists.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(manager.warningColor)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(manager.appTextColor)
                    Button("Повторить") {
                        Task { await loadInitialPlaylists() }
                    }
                    .buttonStyle(.bordered)
                    .tint(manager.accentColor)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if playlists.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 40))
                        .foregroundColor(manager.secondaryTextColor)
                    Text("Нет плейлистов")
                        .font(.headline)
                        .foregroundColor(manager.secondaryTextColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(playlists) { playlist in
                        NavigationLink(destination: DivoomPlaylistDetailView(manager: manager, playlist: playlist)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(playlist.Name)
                                    .font(.headline)
                                if let desc = playlist.Describe, !desc.isEmpty {
                                    Text(desc)
                                        .font(.subheadline)
                                        .foregroundColor(manager.secondaryTextColor)
                                }
                                HStack(spacing: 0) {
                                    Text("Элементов: ")
                                        .foregroundColor(manager.appTextColor)
                                    Text("\(playlist.Count ?? 0)")
                                        .foregroundColor(manager.valueTextColor)
                                }
                                .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(manager.cardBackgroundColor)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                playlistToDelete = playlist
                                isShowingDeleteAlert = true
                            } label: {
                                Label("Удалить", systemImage: "trash")
                                    .foregroundColor(.red)
                            }
                            .tint(.red)
                        }
                        .onAppear {
                            if playlist.id == playlists.last?.id {
                                Task { await loadMorePlaylists() }
                            }
                        }
                    }
                    
                    if isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                .listStyle(.plain)
                .themedForm(manager)
                .refreshable {
                    await refreshPlaylists()
                }
            }
        }
        .tint(manager.accentColor)
        .background(manager.backgroundColor.ignoresSafeArea())
        .onChange(of: refreshTrigger) { _, _ in
            Task { await loadInitialPlaylists() }
        }
        .alert("Удаление плейлиста", isPresented: $isShowingDeleteAlert, presenting: playlistToDelete) { playlist in
            Button("Отмена", role: .cancel) {
                playlistToDelete = nil
            }
            Button("Удалить", role: .destructive) {
                Task {
                    do {
                        try await manager.deleteDivoomPlaylist(playId: playlist.PlayId)
                        await loadInitialPlaylists()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    playlistToDelete = nil
                }
            }
            .tint(.red)
        } message: { playlist in
            Text("Вы уверены, что хотите удалить плейлист «\(playlist.Name)»?")
        }
        .task {
            if playlists.isEmpty {
                await loadInitialPlaylists()
            }
        }
    }
    
    private func loadInitialPlaylists() async {
        isLoading = true
        errorMessage = nil
        currentStart = 1
        hasMorePages = true
        playlists.removeAll()
        
        let endNum = currentStart + pageSize - 1
        do {
            let fetched = try await manager.fetchDivoomPlaylists(startNum: currentStart, endNum: endNum)
            playlists = fetched
            isLoading = false
            
            if fetched.count < pageSize {
                hasMorePages = false
            } else {
                currentStart += pageSize
            }
        } catch {
            errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func loadMorePlaylists() async {
        guard !isLoadingMore, hasMorePages else { return }
        isLoadingMore = true
        
        let endNum = currentStart + pageSize - 1
        do {
            let fetched = try await manager.fetchDivoomPlaylists(startNum: currentStart, endNum: endNum)
            if !fetched.isEmpty {
                playlists.append(contentsOf: fetched)
            }
            
            if fetched.count < pageSize {
                hasMorePages = false
            } else {
                currentStart += pageSize
            }
            isLoadingMore = false
        } catch {
            isLoadingMore = false
        }
    }
    
    private func refreshPlaylists() async {
        currentStart = 1
        hasMorePages = true
        let endNum = currentStart + pageSize - 1
        
        do {
            let fetched = try await manager.fetchDivoomPlaylists(startNum: currentStart, endNum: endNum)
            playlists = fetched
            if fetched.count < pageSize {
                hasMorePages = false
            } else {
                currentStart += pageSize
            }
        } catch {}
    }
}
