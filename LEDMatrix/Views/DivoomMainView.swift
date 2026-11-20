//
//  DivoomMainView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 31.10.2026.
//

import SwiftUI

enum DivoomSection: String, CaseIterable, Identifiable {
    case categories = "Категории"
    case albums = "Альбомы"
    case favorites = "Избранное"
    case playlists = "Плейлисты"
    case authors = "Авторы"

    var id: String {
        rawValue
    }

    var iconName: String {
        switch self {
        case .categories: return "square.grid.2x2"
        case .albums: return "photo.stack"
        case .playlists: return "list.bullet"
        case .favorites: return "heart.fill"
        case .authors: return "person.2"
        }
    }
}

struct DivoomMainView: View {
    @ObservedObject var manager: MatrixManager
    @State private var selectedSection: DivoomSection = .categories

    // Поиск: значок в навбаре переключает режим, крестик возвращает
    // к той вкладке, на которой пользователь был до входа в поиск.
    @State private var isSearching = false
    @State private var searchQuery = ""
    // Поиск запускается только по кнопке «Поиск» на клавиатуре: пока
    // пользователь печатает, запросы к API не отправляются.
    @State private var submittedQuery = ""
    @FocusState private var isSearchFieldFocused: Bool

    // Кнопка создания плейлиста живёт в навбаре родителя: вложенный
    // toolbar внутри TabView на этом экране не отображается.
    @State private var isShowingCreatePlaylist = false
    @State private var playlistsRefreshTrigger = 0

    var body: some View {
        Group {
            if isSearching {
                searchContent
            } else {
                tabsContent
            }
        }
        .background(manager.backgroundColor)
        .navigationBarTitleDisplayMode(.inline)
        .themedToolbarBackground(manager)
        .tint(manager.currentTheme.usesSystemAppearance ? Color.accentColor : manager.lightAccentColor)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isSearching {
                    Button(action: toggleSearch) {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundColor(manager.appTextColor)
                    }
                    .accessibilityLabel("Закрыть поиск")
                } else if selectedSection == .playlists {
                    Button(action: {
                        isShowingCreatePlaylist = true
                    }) {
                        Image(systemName: "plus")
                            .font(.body)
                            .foregroundColor(manager.appTextColor)
                    }
                    .accessibilityLabel("Новый плейлист")
                } else {
                    Button(action: toggleSearch) {
                        Image(systemName: "magnifyingglass")
                            .font(.body)
                            .foregroundColor(manager.appTextColor)
                    }
                    .accessibilityLabel("Поиск")
                }
            }
        }
        .divoomCreatePlaylistAlert(manager: manager, isPresented: $isShowingCreatePlaylist) {
            playlistsRefreshTrigger += 1
        }
    }

    // MARK: - Обычные вкладки Divoom

    private var tabsContent: some View {
        Group {
            if manager.currentTheme.usesSystemAppearance {
                TabView(selection: $selectedSection) {
                    ForEach(DivoomSection.allCases) { section in
                        tabContent(for: section)
                            .tabItem {
                                Label(section.rawValue, systemImage: section.iconName)
                            }
                            .tag(section)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    tabContent(for: selectedSection)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Rectangle()
                        .fill(manager.dividerColor)
                        .frame(height: 0.5)

                    HStack(spacing: 0) {
                        ForEach(DivoomSection.allCases) { section in
                            Button {
                                selectedSection = section
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: section.iconName)
                                        .font(.system(size: 18, weight: section == selectedSection ? .semibold : .regular))
                                    Text(section.rawValue)
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(section == selectedSection ? manager.accentColor : manager.lightAccentColor)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                    .background(manager.cardBackgroundColor.ignoresSafeArea(edges: .bottom))
                }
            }
        }
    }

    @ViewBuilder
    private func tabContent(for section: DivoomSection) -> some View {
        switch section {
        case .categories:
            DivoomCategoriesView(manager: manager)
        case .albums:
            DivoomAlbumsView(manager: manager)
        case .favorites:
            DivoomLikesView(manager: manager)
        case .playlists:
            DivoomPlaylistsView(manager: manager, refreshTrigger: playlistsRefreshTrigger)
        case .authors:
            DivoomAuthorsView(manager: manager)
        }
    }

    // MARK: - Режим поиска

    private var searchContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(manager.secondaryTextColor)

                TextField("Поиск по Divoom", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .foregroundColor(manager.appTextColor)
                    .focused($isSearchFieldFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        submittedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                        isSearchFieldFocused = false
                    }

                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        // Сброс отправленного запроса возвращает результаты
                        // поиска к стандартному состоянию (как при входе в поиск).
                        submittedQuery = ""
                        isSearchFieldFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(manager.secondaryTextColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Очистить поиск")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(manager.backgroundColor)

            Rectangle()
                .fill(manager.dividerColor)
                .frame(height: 0.5)

            DivoomSearchView(manager: manager, query: submittedQuery)
        }
        .background(manager.backgroundColor)
    }

    private func toggleSearch() {
        withAnimation {
            isSearching.toggle()
            if isSearching {
                submittedQuery = ""
                // Фокус не ставим: клавиатура должна появляться только когда
                // пользователь сам тапнет по полю ввода.
                isSearchFieldFocused = false
            } else {
                searchQuery = ""
                submittedQuery = ""
                isSearchFieldFocused = false
            }
        }
    }
}
