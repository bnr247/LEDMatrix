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
        .toolbarBackground(manager.cardBackgroundColor)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(manager.accentColor)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: toggleSearch) {
                    Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                        .font(.body)
                        .foregroundColor(manager.appTextColor)
                }
                .accessibilityLabel(isSearching ? "Закрыть поиск" : "Поиск")
            }
        }
    }

    // MARK: - Обычные вкладки Divoom

    private var tabsContent: some View {
        TabView(selection: $selectedSection) {
            DivoomCategoriesView(manager: manager)
                .tabItem {
                    Label(DivoomSection.categories.rawValue, systemImage: DivoomSection.categories.iconName)
                }
                .tag(DivoomSection.categories)

            DivoomAlbumsView(manager: manager)
                .tabItem {
                    Label(DivoomSection.albums.rawValue, systemImage: DivoomSection.albums.iconName)
                }
                .tag(DivoomSection.albums)

            DivoomLikesView(manager: manager)
                .tabItem {
                    Label(DivoomSection.favorites.rawValue, systemImage: DivoomSection.favorites.iconName)
                }
                .tag(DivoomSection.favorites)

            DivoomPlaylistsView(manager: manager)
                .tabItem {
                    Label(DivoomSection.playlists.rawValue, systemImage: DivoomSection.playlists.iconName)
                }
                .tag(DivoomSection.playlists)

            DivoomAuthorsView(manager: manager)
                .tabItem {
                    Label(DivoomSection.authors.rawValue, systemImage: DivoomSection.authors.iconName)
                }
                .tag(DivoomSection.authors)
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
