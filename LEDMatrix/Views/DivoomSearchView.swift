//
//  DivoomSearchView.swift
//  LEDMatrix
//
//  Поиск по Divoom: тэги, анимации и пользователи.
//

import SwiftUI

enum DivoomSearchTab: String, CaseIterable, Identifiable {
    case tags = "Тэги"
    case animations = "Анимации"
    case users = "Пользователи"

    var id: String { rawValue }

    // Пользователи пока скрыты — вернём вкладку, когда будет готово API.
    static var visible: [DivoomSearchTab] {
        [.tags, .animations]
    }
}

struct DivoomSearchView: View {
    @ObservedObject var manager: MatrixManager
    let query: String

    @State private var selectedTab: DivoomSearchTab = .tags

    var body: some View {
        VStack(spacing: 0) {
            Picker("Раздел поиска", selection: $selectedTab) {
                ForEach(DivoomSearchTab.visible) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .tint(manager.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(manager.backgroundColor)

            Rectangle()
                .fill(manager.dividerColor)
                .frame(height: 0.5)

            Group {
                switch selectedTab {
                case .tags:
                    DivoomTagSearchResults(manager: manager, query: query)
                case .animations:
                    DivoomAnimationSearchResults(manager: manager, query: query)
                case .users:
                    DivoomSearchPlaceholder(
                        manager: manager,
                        title: "Пользователи",
                        icon: "person.2"
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(manager.backgroundColor)
    }
}

// MARK: - Тэги

private struct DivoomTagSearchResults: View {
    @ObservedObject var manager: MatrixManager
    let query: String

    @State private var tags: [DivoomTag] = []
    @State private var previewImages: [String: UIImage] = [:]
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var errorMessage: String? = nil

    private let pageSize = 30

    var body: some View {
        Group {
            if isLoading && tags.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(manager.accentColor)
                    Text("Загрузка тэгов...")
                        .font(.subheadline)
                        .foregroundColor(manager.secondaryTextColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, tags.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(manager.warningColor)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(manager.appTextColor)
                    Button("Повторить") {
                        Task { await reload() }
                    }
                    .buttonStyle(.bordered)
                    .tint(manager.accentColor)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tags.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tag.slash")
                        .font(.largeTitle)
                        .foregroundColor(manager.secondaryTextColor)
                    Text("Тэги не найдены")
                        .foregroundColor(manager.appTextColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(tags) { tag in
                            DivoomTagCard(
                                manager: manager,
                                tag: tag,
                                previewImages: previewImages
                            )
                            .onAppear {
                                guard tag.id == tags.last?.id else { return }
                                Task { await loadMore() }
                            }
                        }

                        if isLoadingMore {
                            ProgressView()
                                .tint(manager.accentColor)
                                .padding()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .refreshable {
                    await reload()
                }
            }
        }
        .background(manager.backgroundColor)
        // query меняется только по кнопке «Поиск» на клавиатуре — поиск не инкрементальный.
        .task(id: query) {
            await reload()
        }
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        hasMore = true
        tags = []

        do {
            let fetched = try await manager.fetchDivoomTags(
                tagKey: query.trimmingCharacters(in: .whitespacesAndNewlines),
                startNum: 1,
                endNum: pageSize
            )
            guard !Task.isCancelled else { return }
            tags = fetched
            hasMore = fetched.count >= pageSize
            preloadPreviews(for: fetched)
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func loadMore() async {
        guard !isLoading, !isLoadingMore, hasMore, !tags.isEmpty else { return }
        isLoadingMore = true

        let startNum = tags.count + 1
        let endNum = startNum + pageSize - 1

        do {
            let fetched = try await manager.fetchDivoomTags(
                tagKey: query.trimmingCharacters(in: .whitespacesAndNewlines),
                startNum: startNum,
                endNum: endNum
            )
            let existing = Set(tags.map(\.id))
            let unique = fetched.filter { !existing.contains($0.id) }

            if fetched.isEmpty || unique.isEmpty {
                hasMore = false
            } else {
                tags.append(contentsOf: unique)
                hasMore = fetched.count >= pageSize
                preloadPreviews(for: unique)
            }
        } catch {
            hasMore = false
        }

        isLoadingMore = false
    }

    private func preloadPreviews(for list: [DivoomTag]) {
        for tag in list {
            for item in (tag.GalleryList ?? []).prefix(3) {
                guard let fileId = item.FileId, !fileId.isEmpty,
                      previewImages[fileId] == nil else { continue }

                Task.detached(priority: .background) {
                    if let result = await DivoomAnimationLoader.loadAndCreateAnimation(from: fileId) {
                        await MainActor.run {
                            self.previewImages[fileId] = result.image
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Поиск анимаций

private struct DivoomAnimationSearchResults: View {
    @ObservedObject var manager: MatrixManager
    let query: String

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            if trimmedQuery.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 34))
                        .foregroundColor(manager.accentColor)
                    Text("Введите запрос и нажмите «Поиск»")
                        .font(.subheadline)
                        .foregroundColor(manager.secondaryTextColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                DivoomUniversalGridView(
                    title: "Поиск: \(trimmedQuery)",
                    manager: manager,
                    fetchItems: { start, end, sort in
                        let response = try await manager.searchDivoomAnimations(
                            keywords: trimmedQuery,
                            startNum: start,
                            endNum: end,
                            fileSort: sort
                        )
                        return (response.FileList ?? [], response.CurListNum ?? response.FileList?.count ?? 0)
                    },
                    onPlayTapped: nil
                )
                // Полностью пересоздаём галерею при новом запросе, чтобы
                // сбросить пагинацию и загрузить результаты заново.
                .id(trimmedQuery)
            }
        }
        .background(manager.backgroundColor)
    }
}

// MARK: - Карточка тэга

private struct DivoomTagCard: View {
    @ObservedObject var manager: MatrixManager
    let tag: DivoomTag
    let previewImages: [String: UIImage]

    @State private var isFollowing: Bool
    @State private var followCount: Int

    init(manager: MatrixManager, tag: DivoomTag, previewImages: [String: UIImage]) {
        self.manager = manager
        self.tag = tag
        self.previewImages = previewImages
        _isFollowing = State(initialValue: (tag.IsFollow ?? 0) == 1)
        _followCount = State(initialValue: tag.FollowCnt ?? 0)
    }

    private var previewItems: [DivoomFileItem] {
        Array((tag.GalleryList ?? []).prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок и кнопка подписки в одной строке, а счётчики —
            // отдельной строкой ниже, чтобы они не переносились и не упирались
            // в кнопку на узких экранах.
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    NavigationLink {
                        DivoomTagDetailView(
                            manager: manager,
                            tag: tag,
                            isFollowing: $isFollowing,
                            followCount: $followCount
                        )
                    } label: {
                        HStack(spacing: 4) {
                            Text(tag.TagName)
                                .font(.headline)
                                .foregroundColor(manager.appTextColor)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(manager.secondaryTextColor)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    DivoomTagFollowButton(
                        manager: manager,
                        tagName: tag.TagName,
                        isFollowing: $isFollowing,
                        followCount: $followCount
                    )
                }

                NavigationLink {
                    DivoomTagDetailView(
                        manager: manager,
                        tag: tag,
                        isFollowing: $isFollowing,
                        followCount: $followCount
                    )
                } label: {
                    HStack(spacing: 14) {
                        Label("Анимации: \((tag.GalleryCnt ?? 0).formatted())", systemImage: "sparkles")
                        Label("Подписки: \(followCount.formatted())", systemImage: "person.2")
                    }
                    .font(.caption)
                    .foregroundColor(manager.secondaryTextColor)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if previewItems.isEmpty {
                Text("Нет анимаций")
                    .font(.caption)
                    .foregroundColor(manager.secondaryTextColor)
            } else {
                HStack(spacing: 6) {
                    ForEach(previewItems) { item in
                        DivoomTagPreviewLink(
                            manager: manager,
                            tag: tag,
                            items: previewItems,
                            selectedItem: item,
                            image: previewImages[item.FileId ?? ""]
                        )
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(manager.cardBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(manager.cardBorderColor, lineWidth: 1)
        )
    }
}

private struct DivoomTagPreviewLink: View {
    @ObservedObject var manager: MatrixManager
    let tag: DivoomTag
    let items: [DivoomFileItem]
    let selectedItem: DivoomFileItem
    let image: UIImage?

    var body: some View {
        NavigationLink {
            DivoomFeedView(
                title: "#\(tag.TagName)",
                manager: manager,
                initialItems: items,
                selectedItemId: selectedItem.id,
                fetchMoreItems: { start, end in
                    let response = try await manager.fetchDivoomTagImages(
                        tagName: tag.TagName,
                        startNum: start,
                        endNum: end
                    )
                    return response.FileList ?? []
                }
            )
        } label: {
            AnimatedImageView(manager: manager, item: selectedItem, image: image)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Детальная галерея тэга

struct DivoomTagDetailView: View {
    @ObservedObject var manager: MatrixManager
    let tag: DivoomTag
    @Binding var isFollowing: Bool
    @Binding var followCount: Int

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text("#\(tag.TagName)")
                        .font(.title3.bold())
                        .foregroundColor(manager.appTextColor)

                    Spacer(minLength: 0)

                    DivoomTagFollowButton(
                        manager: manager,
                        tagName: tag.TagName,
                        isFollowing: $isFollowing,
                        followCount: $followCount
                    )
                }

                // Счётчики на отдельной строке — так же, как в карточке тэга.
                HStack(spacing: 14) {
                    Label("Анимации: \((tag.GalleryCnt ?? 0).formatted())", systemImage: "sparkles")
                    Label("Подписки: \(followCount.formatted())", systemImage: "person.2")
                }
                .font(.caption)
                .foregroundColor(manager.secondaryTextColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(manager.backgroundColor)

            Rectangle()
                .fill(manager.dividerColor)
                .frame(height: 0.5)

            DivoomUniversalGridView(
                title: "#\(tag.TagName)",
                manager: manager,
                fetchItems: { start, end, sort in
                    let response = try await manager.fetchDivoomTagImages(
                        tagName: tag.TagName,
                        startNum: start,
                        endNum: end,
                        fileSort: sort
                    )
                    return (response.FileList ?? [], response.CurListNum ?? response.FileList?.count ?? 0)
                },
                onPlayTapped: nil
            )
        }
        .background(manager.backgroundColor)
        .navigationTitle("#\(tag.TagName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(manager.cardBackgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

// MARK: - Кнопка подписки на тэг

struct DivoomTagFollowButton: View {
    @ObservedObject var manager: MatrixManager
    let tagName: String
    @Binding var isFollowing: Bool
    @Binding var followCount: Int

    @State private var isBusy = false

    var body: some View {
        Button(action: toggleFollow) {
            Text(isFollowing ? "Подписан" : "Подписаться")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isFollowing ? manager.secondaryTextColor : manager.accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isFollowing
                              ? manager.fieldBackgroundColor
                              : manager.accentColor.opacity(0.16))
                )
                .overlay(
                    Capsule()
                        .stroke(isFollowing
                                ? manager.cardBorderColor
                                : manager.accentColor.opacity(0.5),
                                lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.6 : 1)
    }

    private func toggleFollow() {
        let newValue = !isFollowing
        let oldValue = isFollowing
        let oldCount = followCount

        isFollowing = newValue
        followCount = max(0, followCount + (newValue ? 1 : -1))
        isBusy = true

        Task {
            do {
                try await manager.toggleDivoomTagFollow(
                    tagName: tagName,
                    isFollow: newValue ? 1 : 0
                )
                await MainActor.run { isBusy = false }
            } catch {
                await MainActor.run {
                    isFollowing = oldValue
                    followCount = oldCount
                    isBusy = false
                }
            }
        }
    }
}

// MARK: - Заглушки будущих разделов

private struct DivoomSearchPlaceholder: View {
    @ObservedObject var manager: MatrixManager
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundColor(manager.accentColor)
            Text(title)
                .font(.title2)
                .foregroundColor(manager.appTextColor)
            Text("Раздел в разработке")
                .font(.subheadline)
                .foregroundColor(manager.secondaryTextColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(manager.backgroundColor)
    }
}
