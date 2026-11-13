//
//  DivoomLikesView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 10.11.2026.
//

import SwiftUI

struct DivoomLikesView: View {
    @ObservedObject var manager: MatrixManager
    
    @State private var alertMessage: String? = nil
    @State private var isShowingAlert = false
    
    var body: some View {
        DivoomUniversalGridView(
            title: "Избранное",
            manager: manager,
            fetchItems: { start, end, sort in
                let response = try await manager.fetchDivoomLikedImages(
                    startNum: start,
                    endNum: end,
                    fileSort: sort
                )
                return (response.FileList ?? [], response.CurListNum ?? response.FileList?.count ?? 0)
            },
            onPlayTapped: { sort in
                sendLikesCommand(sort: sort)
            }
        )
        .navigationTitle("Избранное")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Избранное", isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }
    
    private func sendLikesCommand(sort: Int) {
        Task {
            do {
                try await manager.updateAnimationType(.likes(sortOrder: sort))
                
                await MainActor.run {
                    self.alertMessage = "Избранное воспроизводится на устройстве"
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
