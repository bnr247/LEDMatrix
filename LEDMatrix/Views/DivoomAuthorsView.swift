//
//  DivoomAuthorsView.swift
//  LEDMatrix
//
//  Вкладка «Авторы»: список экспертов и галерея пользователя.
//

import SwiftUI

struct DivoomAuthorsView: View {
    @ObservedObject var manager: MatrixManager

    @State private var experts: [DivoomExpert] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var errorMessage: String? = nil

    private let pageSize = 20

    var body: some View {
        Group {
            if isLoading && experts.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(manager.accentColor)
                    Text("Загрузка авторов...")
                        .font(.subheadline)
                        .foregroundColor(manager.secondaryTextColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, experts.isEmpty {
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
            } else if experts.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.2.slash")
                        .font(.largeTitle)
                        .foregroundColor(manager.secondaryTextColor)
                    Text("Авторы не найдены")
                        .foregroundColor(manager.appTextColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(experts) { expert in
                            DivoomExpertCard(manager: manager, expert: expert)
                                .onAppear {
                                    guard expert.id == experts.last?.id else { return }
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
        .task {
            await reload()
        }
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        hasMore = true
        experts = []

        do {
            let fetched = try await manager.fetchDivoomExperts(startNum: 1, endNum: pageSize)
            guard !Task.isCancelled else { return }
            experts = fetched.ExpertList ?? []
            hasMore = experts.count >= pageSize
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func loadMore() async {
        guard !isLoading, !isLoadingMore, hasMore, !experts.isEmpty else { return }
        isLoadingMore = true

        let startNum = experts.count + 1
        let endNum = startNum + pageSize - 1

        do {
            let fetched = try await manager.fetchDivoomExperts(startNum: startNum, endNum: endNum)
            let existing = Set(experts.map(\.id))
            let unique = (fetched.ExpertList ?? []).filter { !existing.contains($0.id) }

            if unique.isEmpty {
                hasMore = false
            } else {
                experts.append(contentsOf: unique)
                hasMore = unique.count >= pageSize
            }
        } catch {
            hasMore = false
        }

        isLoadingMore = false
    }
}

// MARK: - Карточка автора

private struct DivoomExpertCard: View {
    @ObservedObject var manager: MatrixManager
    let expert: DivoomExpert

    @State private var isFollowing: Bool
    @State private var fansCount: Int

    init(manager: MatrixManager, expert: DivoomExpert) {
        self.manager = manager
        self.expert = expert
        _isFollowing = State(initialValue: (expert.IsFollow ?? 0) == 1)
        _fansCount = State(initialValue: expert.FansCnt ?? 0)
    }

    private var detailView: DivoomExpertDetailView {
        DivoomExpertDetailView(
            manager: manager,
            expert: expert,
            isFollowing: $isFollowing,
            fansCount: $fansCount
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                NavigationLink {
                    detailView
                } label: {
                    HStack(spacing: 10) {
                        DivoomUserAvatarView(headId: expert.HeadId, size: 48)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(expert.NickName)
                                .font(.headline)
                                .foregroundColor(manager.appTextColor)
                            Text("Lv.\(expert.Level ?? 0)")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(manager.secondaryTextColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                DivoomExpertFollowButton(
                    manager: manager,
                    userId: expert.UserId,
                    isFollowing: $isFollowing,
                    fansCount: $fansCount
                )
            }

            // Счётчики отдельной строкой под ником, как в карточках тэгов,
            // чтобы не упираться в кнопку подписки.
            NavigationLink {
                detailView
            } label: {
                HStack(spacing: 12) {
                    Label("Score: \((expert.Score ?? 0).formatted())", systemImage: "star.fill")
                    Label("Подписчики: \(fansCount.formatted())", systemImage: "person.2")
                }
                .font(.caption)
                .foregroundColor(manager.secondaryTextColor)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 58)
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

// MARK: - Галерея пользователя

struct DivoomExpertDetailView: View {
    @ObservedObject var manager: MatrixManager
    let expert: DivoomExpert
    @Binding var isFollowing: Bool
    @Binding var fansCount: Int

    @State private var info: DivoomSomeoneInfo?
    @State private var score = 0
    @State private var likeCount = 0

    private var displayName: String {
        info?.NickName ?? expert.NickName
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    DivoomUserAvatarView(headId: info?.HeadId ?? expert.HeadId, size: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(.title3.bold())
                            .foregroundColor(manager.appTextColor)

                        HStack(spacing: 12) {
                            Label("Score: \(score.formatted())", systemImage: "star.fill")
                            Label("Лайки: \(likeCount.formatted())", systemImage: "heart")
                            Label("Подписчики: \(fansCount.formatted())", systemImage: "person.2")
                        }
                        .font(.caption)
                        .foregroundColor(manager.secondaryTextColor)
                    }
                }

                DivoomExpertFollowButton(
                    manager: manager,
                    userId: expert.UserId,
                    isFollowing: $isFollowing,
                    fansCount: $fansCount
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(manager.backgroundColor)

            Rectangle()
                .fill(manager.dividerColor)
                .frame(height: 0.5)

            DivoomUniversalGridView(
                title: displayName,
                manager: manager,
                fetchItems: { start, end, _ in
                    // По спецификации GetSomeoneListV3 всегда использует FileSort = 1.
                    let response = try await manager.fetchDivoomSomeoneImages(
                        userId: expert.UserId,
                        startNum: start,
                        endNum: end,
                        fileSort: 1
                    )
                    return (response.FileList ?? [], response.CurListNum ?? response.FileList?.count ?? 0)
                },
                onPlayTapped: nil
            )
        }
        .background(manager.backgroundColor)
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(manager.cardBackgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            guard let result = try? await manager.fetchDivoomSomeoneInfo(userId: expert.UserId) else { return }
            guard !Task.isCancelled else { return }
            info = result
            score = result.Score ?? 0
            likeCount = result.LikeCnt ?? 0
            if let fans = result.FansCnt { fansCount = fans }
            if let follow = result.IsFollow { isFollowing = follow == 1 }
        }
    }
}

// MARK: - Кнопка подписки на автора

struct DivoomExpertFollowButton: View {
    @ObservedObject var manager: MatrixManager
    let userId: Int
    @Binding var isFollowing: Bool
    @Binding var fansCount: Int

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
        let oldCount = fansCount

        isFollowing = newValue
        fansCount = max(0, fansCount + (newValue ? 1 : -1))
        isBusy = true

        Task {
            do {
                try await manager.toggleDivoomExpertFollow(
                    userId: userId,
                    isFollow: newValue ? 1 : 0
                )
                await MainActor.run { isBusy = false }
            } catch {
                await MainActor.run {
                    isFollowing = oldValue
                    fansCount = oldCount
                    isBusy = false
                }
            }
        }
    }
}

// MARK: - Анимированный аватар пользователя

struct DivoomUserAvatarView: View {
    let headId: String?
    let size: CGFloat

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                AnimatedImageRepresentable(image: image)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
        .frame(width: size, height: size)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: headId) {
            image = nil
            guard let headId = headId, !headId.isEmpty else { return }
            let loaded = await Task.detached(priority: .background) {
                await DivoomAnimationLoader.loadAndCreateAnimation(from: headId)
            }.value
            guard !Task.isCancelled else { return }
            image = loaded?.image
        }
    }
}
