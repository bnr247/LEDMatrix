//
//  DivoomFeedView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 07.11.2026.
//

import SwiftUI

struct DivoomFeedView: View {
    let title: String
    @ObservedObject var manager: MatrixManager
    
    let initialItems: [DivoomFileItem]
    let selectedItemId: String
    let fetchMoreItems: (_ startNum: Int, _ endNum: Int) async throws -> [DivoomFileItem]
    let onScrollPositionChanged: ((String?) -> Void)? // <--- Добавлено
    
    init(
        title: String,
        manager: MatrixManager,
        initialItems: [DivoomFileItem],
        selectedItemId: String,
        fetchMoreItems: @escaping (_ startNum: Int, _ endNum: Int) async throws -> [DivoomFileItem],
        onScrollPositionChanged: ((String?) -> Void)? = nil
    ) {
        self.title = title
        self.manager = manager
        self.initialItems = initialItems
        self.selectedItemId = selectedItemId
        self.fetchMoreItems = fetchMoreItems
        self.onScrollPositionChanged = onScrollPositionChanged
    }
    
    @State private var items: [DivoomFileItem] = []
    @State private var loadedAnimations: [String: UIImage] = [:]
    @State private var loadedAvatars: [String: UIImage] = [:]
    @State private var isLoadingMore = false
    @State private var hasMorePages = true
    @State private var currentStart = 1
    @State private var scrollPositionId: String? = nil
    private let pageSize = 30
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(items) { item in
                        DivoomFeedItemView(
                            manager: manager,
                            item: item,
                            animationImage: loadedAnimations[item.FileId ?? ""],
                            avatarImage: loadedAvatars[item.UserHeaderId ?? ""]
                        )
                        .id(item.id)
                        .scrollTransition(.interactive, axis: .vertical) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1.0 : 0.6)
                                .scaleEffect(phase.isIdentity ? 1.0 : 0.98)
                        }
                        .onAppear {
                            if item.id == items.last?.id {
                                Task { await loadMore() }
                            }
                        }
                    }
                    
                    if isLoadingMore {
                        ProgressView()
                            .tint(manager.accentColor)
                            .padding()
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $scrollPositionId)
            .onChange(of: scrollPositionId) { _, newId in
                onScrollPositionChanged?(newId) // <--- Синхронизируем позицию
                if let id = newId, let item = items.first(where: { $0.id == id }), let galleryId = item.GalleryId, !galleryId.isEmpty {
                    Task {
                        await manager.addDivoomWatch(galleryId: galleryId, classify: item.Classify)
                    }
                }
            }
            .background(Color.black)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if items.isEmpty {
                    items = initialItems
                    currentStart = initialItems.count + 1
                    preloadAnimations(for: initialItems)
                    preloadAvatars(for: initialItems)
                    
                    scrollPositionId = selectedItemId
                    
                    try? await Task.sleep(for: .milliseconds(50))
                    withAnimation(.none) {
                        proxy.scrollTo(selectedItemId, anchor: .top)
                    }
                    
                    if let initialItem = initialItems.first(where: { $0.id == selectedItemId }), let galleryId = initialItem.GalleryId, !galleryId.isEmpty {
                        await manager.addDivoomWatch(galleryId: galleryId, classify: initialItem.Classify)
                    }
                }
            }
        }
    }
    
    private func loadMore() async {
        guard !isLoadingMore, hasMorePages else { return }
        isLoadingMore = true
        
        let endNum = currentStart + pageSize - 1
        do {
            let fetched = try await fetchMoreItems(currentStart, endNum)
            if fetched.isEmpty {
                hasMorePages = false
            } else {
                items.append(contentsOf: fetched)
                currentStart += fetched.count
                preloadAnimations(for: fetched)
                preloadAvatars(for: fetched)
            }
        } catch {}
        
        isLoadingMore = false
    }
    
    private func preloadAnimations(for list: [DivoomFileItem]) {
        for item in list {
            guard let fileId = item.FileId, !fileId.isEmpty, loadedAnimations[fileId] == nil else { continue }
            Task.detached(priority: .background) {
                // Parse or load data on background thread
                if let result = await DivoomAnimationLoader.loadAndCreateAnimation(from: fileId) {
                    await MainActor.run {
                        self.loadedAnimations[fileId] = result.image
                    }
                }
            }
        }
    }
    
    private func preloadAvatars(for list: [DivoomFileItem]) {
        for item in list {
            guard let headerId = item.UserHeaderId, !headerId.isEmpty, loadedAvatars[headerId] == nil else { continue }
            Task.detached(priority: .background) {
                if let result = await DivoomAnimationLoader.loadAndCreateAnimation(from: headerId) {
                    await MainActor.run {
                        self.loadedAvatars[headerId] = result.image
                    }
                }
            }
        }
    }
}

/// Карточка поста
struct DivoomFeedItemView: View {
    @ObservedObject var manager: MatrixManager
    let item: DivoomFileItem
    let animationImage: UIImage?
    let avatarImage: UIImage?
    
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var isFollowing: Bool
    @State private var isFollowLoading = false
    @State private var isShowingPlaylists = false
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
                            .overlay(Image(systemName: "person.fill").foregroundColor(.white.opacity(0.7)))
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                
                Text(item.UserName ?? "Pixel Artist")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    toggleFollow()
                }) {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isFollowing ? .gray : .yellow)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(16)
                }
                .disabled(isFollowLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // 2. Анимация поста (квадрат по ширине экрана)
            ZStack {
                if let image = animationImage {
                    AnimatedImageRepresentable(image: image)
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
                            .foregroundColor(isLiked ? .red : .white)
                        Text("\(likeCount)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                
                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                    Text("\(item.CommentCnt ?? 0)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Button(action: {
                    loadAndShowPlaylists()
                }) {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6).opacity(0.12))
        .cornerRadius(16)
        .padding(.horizontal, 12)
        .overlay(alignment: .bottom) {
            if let message = toastMessage {
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.85))
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
                            .foregroundColor(.secondary)
                    } else {
                        List(playlists) { playlist in
                            Button(action: {
                                addToPlaylist(playlist)
                            }) {
                                HStack {
                                    Text(playlist.Name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if let count = playlist.Count {
                                        Text("\(count)")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .navigationTitle("Выберите плейлист")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") {
                            isShowingPlaylists = false
                        }
                    }
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
        Task {
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
