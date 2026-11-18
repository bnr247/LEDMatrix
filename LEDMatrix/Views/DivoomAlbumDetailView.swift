//
//  DivoomDetailGalleryView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 30.10.2026.
//

import SwiftUI

struct DivoomAlbumDetailView: View {
    @ObservedObject var manager: MatrixManager
    let album: DivoomAlbum
    
    @State private var alertMessage: String? = nil
    @State private var isShowingAlert = false
    
    var body: some View {
        DivoomUniversalGridView(
            title: album.AlbumName,
            manager: manager,
            fetchItems: { start, end, sort in
                let response = try await manager.fetchDivoomAlbumImages(
                    albumId: album.AlbumId,
                    startNum: start,
                    endNum: end,
                    fileSort: sort,
                    refreshIndex: 0
                )
                return (response.FileList ?? [], response.CurListNum ?? response.FileList?.count ?? 0)
            },
            onPlayTapped: { sort in
               let _ = sendAlbumCommand(sort: sort)
            }
        )
        .navigationTitle(album.AlbumName)
        .toolbarBackground(manager.cardBackgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Альбомы", isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }
    
    private func sendAlbumCommand(sort: Int) {
        let albumIdInt = Int(album.AlbumId) ?? 0
        
        Task {
            do {
                try await manager.updateAnimationType(.album(id: albumIdInt, sortOrder: sort))
                
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
}
