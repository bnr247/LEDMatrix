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
    var id: String {
        rawValue
    }
}

struct DivoomMainView: View {
    @ObservedObject var manager: MatrixManager
    @State private var selectedSection: DivoomSection = .categories

    var body: some View {
        Group {
            if selectedSection == .categories {
                DivoomCategoriesView(manager: manager)
            } else {
                DivoomTab(manager: manager)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Сегментированный переключатель в центре шапки
            ToolbarItem(placement: .principal) {
                Picker("Раздел", selection: $selectedSection) {
                    ForEach(DivoomSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
    }
}
