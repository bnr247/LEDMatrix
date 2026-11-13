//
//  DivoomPlaylistsView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 07.11.2026.
//

import SwiftUI

struct DivoomPlaylistsView: View {
    @ObservedObject var manager: MatrixManager
    
    @State private var playlists: [DivoomPlaylist] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String? = nil
    
    @State private var hasMorePages = true
    @State private var currentStart = 1
    private let pageSize = 30
    
    // Состояния для модального окна добавления плейлиста
    @State private var isShowingAddAlert = false
    @State private var newPlaylistName = ""
    @State private var isCreating = false
    
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
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, playlists.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                    Button("Повторить") {
                        Task { await loadInitialPlaylists() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if playlists.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Нет плейлистов")
                        .font(.headline)
                        .foregroundColor(.secondary)
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
                                        .foregroundColor(.secondary)
                                }
                                Text("Элементов: \(playlist.Count ?? 0)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                playlistToDelete = playlist
                                isShowingDeleteAlert = true
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
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
                .refreshable {
                    await refreshPlaylists()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    newPlaylistName = ""
                    isShowingAddAlert = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Новый плейлист", isPresented: $isShowingAddAlert) {
            TextField("Название плейлиста", text: $newPlaylistName)
            Button("Отмена", role: .cancel) {}
            Button("Добавить") {
                let nameToCreate = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !nameToCreate.isEmpty else { return }
                Task {
                    isCreating = true
                    do {
                        try await manager.createDivoomPlaylist(name: nameToCreate)
                        await loadInitialPlaylists()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    isCreating = false
                }
            }
        } message: {
            Text("Введите название нового плейлиста")
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
