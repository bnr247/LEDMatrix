//
//  DivoomPlaylistDetailView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 07.11.2026.
//

import SwiftUI

struct DivoomPlaylistDetailView: View {
    @ObservedObject var manager: MatrixManager
    let playlist: DivoomPlaylist
    
    @State private var alertMessage: String? = nil
    @State private var isShowingAlert = false
    
    var body: some View {
        DivoomUniversalGridView(
            title: playlist.Name,
            manager: manager,
            fetchItems: { start, end, sort in
                let response = try await manager.fetchDivoomPlaylistImages(
                    playId: playlist.PlayId,
                    startNum: start,
                    endNum: end,
                    fileSort: sort
                )
                return (response.FileList ?? [], response.CurListNum ?? response.FileList?.count ?? 0)
            },
            onPlayTapped: { sort in
                sendPlaylistCommand(sort: sort)
            }
        )
        .navigationTitle(playlist.Name)
                .toolbarBackground(manager.cardBackgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
                .alert("Плейлисты", isPresented: $isShowingAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(alertMessage ?? "")
                }
    }
    
    private func sendPlaylistCommand(sort: Int) {
        Task {
            do {
                try await manager.updateAnimationType(.playlist(id: playlist.PlayId, sortOrder: sort))
                
                await MainActor.run {
                    self.alertMessage = "\(playlist.Name) воспроизводится на устройстве"
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
}
