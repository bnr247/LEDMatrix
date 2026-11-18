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

    var body: some View {
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
            
            VStack(spacing: 10) {
                Image(systemName: DivoomSection.authors.iconName)
                    .font(.system(size: 34))
                    .foregroundColor(manager.accentColor)
                Text("Авторы")
                    .font(.title2)
                    .foregroundColor(manager.appTextColor)
                Text("Раздел в разработке")
                    .font(.subheadline)
                    .foregroundColor(manager.secondaryTextColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(manager.backgroundColor)
                .tabItem {
                    Label(DivoomSection.authors.rawValue, systemImage: DivoomSection.authors.iconName)
                }
                .tag(DivoomSection.authors)
        }
        .background(manager.backgroundColor)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(manager.cardBackgroundColor)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(manager.accentColor)
    }
}
