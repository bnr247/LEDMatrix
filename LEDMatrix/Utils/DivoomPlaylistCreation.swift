//
//  DivoomPlaylistCreation.swift
//  LEDMatrix
//
//  Создание плейлиста: один и тот же диалог используется на экране
//  плейлистов и в списке плейлистов, который выезжает из фида.
//

import SwiftUI

struct DivoomCreatePlaylistModifier: ViewModifier {
    @ObservedObject var manager: MatrixManager
    @Binding var isPresented: Bool
    let onCreated: (() -> Void)?

    @State private var playlistName = ""

    func body(content: Content) -> some View {
        content
            .alert("Новый плейлист", isPresented: $isPresented) {
                TextField("Название плейлиста", text: $playlistName)
                Button("Отмена", role: .cancel) {
                    playlistName = ""
                }
                Button("Добавить") {
                    let name = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    Task {
                        do {
                            try await manager.createDivoomPlaylist(name: name)
                            await MainActor.run {
                                playlistName = ""
                                onCreated?()
                            }
                        } catch {
                            // Диалог оставляем открытым, чтобы пользователь
                            // мог исправить название и повторить попытку.
                        }
                    }
                }
            } message: {
                Text("Введите название нового плейлиста")
            }
    }
}

extension View {
    func divoomCreatePlaylistAlert(
        manager: MatrixManager,
        isPresented: Binding<Bool>,
        onCreated: (() -> Void)? = nil
    ) -> some View {
        modifier(DivoomCreatePlaylistModifier(manager: manager, isPresented: isPresented, onCreated: onCreated))
    }
}
