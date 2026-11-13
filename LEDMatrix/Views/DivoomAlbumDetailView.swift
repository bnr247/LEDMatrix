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
            onPlayTapped: {
                sendAlbumCommand()
            }
        )
        .navigationTitle(album.AlbumName)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Альбомы", isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }
    
    private func sendAlbumCommand() {
        let albumIdInt = Int(album.AlbumId) ?? 0
        
        Task {
            do {
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
}
