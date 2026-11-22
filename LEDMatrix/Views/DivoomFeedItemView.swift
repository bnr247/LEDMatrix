//
//  DivoomFeedItemView.swift
//  LEDMatrix
//
//  Карточка одного элемента ленты Divoom.
//

import SwiftUI
import UIKit

struct DivoomFeedItemView: View {
    @ObservedObject var manager: MatrixManager
    let item: DivoomFileItem
    let animationImage: UIImage?
    let avatarImage: UIImage?
    
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var isFollowing: Bool
    @State private var authorFansCount = 0
    @State private var isFollowLoading = false
    @State private var isShowingPlaylists = false
    @State private var isShowingCreatePlaylist = false
    @State private var playlists: [DivoomPlaylist] = []
    @State private var isLoadingPlaylists = false
    @State private var toastMessage: String? = nil

    init(manager: MatrixManager, item: DivoomFileItem, animationImage: UIImage?, avatarImage: UIImage?) {
        self.manager = manager
        self.item = item
        self.animationImage = animationImage
        self.avatarImage = avatarImage
        _isLiked = State(initialValue: (item.IsLike ?? 0) == 1)
        _likeCount = State(initialValue: item.LikeCnt ?? 0)
        _isFollowing = State(initialValue: (item.IsFollow ?? 0) == 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Верхняя панель: Аватар (анимация), Имя, Кнопка Подписаться
            HStack(spacing: 10) {
                ZStack {
                    if let avatar = avatarImage {
                        AnimatedImageRepresentable(image: avatar)
                            .aspectRatio(1, contentMode: .fill)
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(Image(systemName: "person.fill").foregroundColor(manager.secondaryTextColor.opacity(0.7)))
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                
                if let userId = item.UserId {
                    NavigationLink {
                        DivoomUserGalleryView(
                            manager: manager,
                            userId: userId,
                            displayName: item.UserName ?? "Pixel Artist",
                            headId: item.UserHeaderId,
                            isFollowing: $isFollowing,
                            fansCount: $authorFansCount
                        )
                    } label: {
                        Text(item.UserName ?? "Pixel Artist")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(manager.appTextColor)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(item.UserName ?? "Pixel Artist")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(manager.appTextColor)
                }
                
                Spacer()
                
                Button(action: {
                    toggleFollow()
                }) {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.system(size: 13, weight: .semibold))
                        .if(!manager.currentTheme.usesSystemAppearance) { content in
                            content
                                .foregroundColor(isFollowing ? manager.secondaryTextColor : manager.accentColor)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(manager.fieldBackgroundColor)
                                .cornerRadius(16)
                        }
                }
                .themedButtonStyle(manager, .borderless)
                .disabled(isFollowLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // 2. Анимация поста (квадрат по ширине экрана)
            ZStack {
                if let image = animationImage {
                    DivoomFullAnimationView(manager: manager, fileId: item.FileId, image: image)
                        .aspectRatio(1, contentMode: .fit)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(ProgressView().tint(manager.accentColor))
                }
            }
            .frame(maxWidth: .infinity)
            
            // 3. Нижняя панель: Лайки, Комментарии, Кнопка добавления в альбом
            HStack(spacing: 20) {
                Button(action: {
                    toggleLike()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(manager.accentColor)
                        Text("\(likeCount)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(manager.appTextColor)
                    }
                }
                .buttonStyle(.plain)
                
                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(manager.accentColor)
                    Text("\(item.CommentCnt ?? 0)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(manager.appTextColor)
                }
                
                Button(action: {
                    loadAndShowPlaylists()
                }) {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(manager.accentColor)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
        .background(manager.cardBackgroundColor)
        .if(!manager.currentTheme.usesSystemAppearance) { content in
            content.cornerRadius(16)
        }
        .padding(.horizontal, 12)
        .overlay(alignment: .bottom) {
            if let message = toastMessage {
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .themedLightText(manager)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(manager.toastBackgroundColor)
                    .cornerRadius(20)
                    .shadow(radius: 4)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: toastMessage)
            }
        }
        .sheet(isPresented: $isShowingPlaylists) {
            NavigationView {
                Group {
                    if isLoadingPlaylists {
                        ProgressView()
                            .tint(manager.accentColor)
                    } else if playlists.isEmpty {
                        Text("Нет плейлистов")
                            .foregroundColor(manager.secondaryTextColor)
                    } else {
                        List(playlists) { playlist in
                            Button(action: {
                                addToPlaylist(playlist)
                            }) {
                                HStack {
                                    Text(playlist.Name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(manager.appTextColor)
                                    Spacer()
                                    if let count = playlist.Count {
                                        Text("\(count)")
                                            .font(.system(size: 14))
                                            .foregroundColor(manager.valueTextColor)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(manager.cardBackgroundColor)
                        }
                    }
                }
                .themedForm(manager)
                .themedNavigationTitle("Выберите плейлист", manager: manager)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") {
                            isShowingPlaylists = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            isShowingCreatePlaylist = true
                        }) {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Новый плейлист")
                    }
                }
                .divoomCreatePlaylistAlert(manager: manager, isPresented: $isShowingCreatePlaylist) {
                    Task { await reloadPlaylists() }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func toggleLike() {
        let newIsLiked = !isLiked
        let oldIsLiked = isLiked
        let oldLikeCount = likeCount

        isLiked = newIsLiked
        likeCount = newIsLiked ? oldLikeCount + 1 : max(0, oldLikeCount - 1)

        guard let galleryId = item.GalleryId, !galleryId.isEmpty else { return }

        Task {
            do {
                try await manager.toggleDivoomLike(galleryId: galleryId, isLike: newIsLiked ? 1 : 0)
            } catch {
                await MainActor.run {
                    isLiked = oldIsLiked
                    likeCount = oldLikeCount
                }
            }
        }
    }
    
    private func toggleFollow() {
        guard let someUserId = item.UserId, !isFollowLoading else {
            return
        }
            
        let newIsFollowing = !isFollowing
        let oldIsFollowing = isFollowing
            
        isFollowing = newIsFollowing
        isFollowLoading = true

        Task {
            do {
                try await manager.toggleDivoomFollow(someOneUserId: someUserId, isFollow: newIsFollowing ? 1 : 0)
                await MainActor.run {
                    isFollowLoading = false
                }
            } catch {
                await MainActor.run {
                    isFollowing = oldIsFollowing
                    isFollowLoading = false
                }
            }
        }
    }
    
    private func loadAndShowPlaylists() {
        isLoadingPlaylists = true
        isShowingPlaylists = true
        Task { await reloadPlaylists() }
    }

    private func reloadPlaylists() async {
        do {
            let fetched = try await manager.fetchDivoomPlaylists(startNum: 1, endNum: 50)
            await MainActor.run {
                playlists = fetched
                isLoadingPlaylists = false
            }
        } catch {
            await MainActor.run {
                isLoadingPlaylists = false
            }
        }
    }

    private func addToPlaylist(_ playlist: DivoomPlaylist) {
        guard let galleryId = item.GalleryId, !galleryId.isEmpty else { return }
        isShowingPlaylists = false
            
        Task {
            do {
                try await manager.addDivoomImageToPlaylist(playId: playlist.PlayId, galleryId: galleryId)
                await MainActor.run {
                    showToast(message: "Добавлено в плейлист \(playlist.Name)")
                }
            } catch {
                print("⚠️ Add to playlist error: \(error.localizedDescription)")
            }
        }
    }

    private func showToast(message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }
}
