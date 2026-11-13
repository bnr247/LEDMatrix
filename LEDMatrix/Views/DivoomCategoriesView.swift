//
//  DivoomCategoriesView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 31.10.2026.
//

import SwiftUI

struct DivoomCategoryModel: Identifiable, Hashable {
    let id: Int
    let name: String
}

struct DivoomCategoriesView: View {
    @ObservedObject var manager: MatrixManager
    
    let categories: [DivoomCategoryModel] = [
        DivoomCategoryModel(id: 0, name: "New"),
        DivoomCategoryModel(id: 20, name: "Follow"),
        DivoomCategoryModel(id: 30, name: "Haunted 2026"),
        DivoomCategoryModel(id: 18, name: "Recommend"),
        DivoomCategoryModel(id: 3, name: "Character"),
        DivoomCategoryModel(id: 17, name: "Festival"),
        DivoomCategoryModel(id: 4, name: "Emoji"),
        DivoomCategoryModel(id: 8, name: "Pattern"),
        DivoomCategoryModel(id: 9, name: "Creative"),
        DivoomCategoryModel(id: 6, name: "Nature"),
        DivoomCategoryModel(id: 5, name: "Daily"),
        DivoomCategoryModel(id: 15, name: "Gadget"),
        DivoomCategoryModel(id: 7, name: "Icon"),
        DivoomCategoryModel(id: 16, name: "Business"),
        DivoomCategoryModel(id: 1, name: "Default"),
        DivoomCategoryModel(id: 40, name: "AI"),
        DivoomCategoryModel(id: 12, name: "Photo")
    ]
    
    @State private var selectedCategoryId: Int = 0
    @State private var alertMessage: String? = nil
    @State private var isShowingAlert = false
    @State private var selectedCategoryName: String? = nil
    @State private var sortOrder: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories) { category in
                        Button(action: {
                            selectedCategoryName = category.name
                            selectedCategoryId = category.id
                        }) {
                            Text(category.name)
                                .font(selectedCategoryId == category.id ? .subheadline.bold() : .subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedCategoryId == category.id ? Color.accentColor : Color.secondary.opacity(0.15))
                                .foregroundColor(selectedCategoryId == category.id ? .white : .primary)
                                .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)
                
            Divider()
            
            // Жестко растягиваем универсальную галерею на все доступное пространство
            let currentCategory = categories.first(where: { $0.id == selectedCategoryId })
            DivoomUniversalGridView(
                title: currentCategory?.name ?? "Категория",
                manager: manager,
                fetchItems: { start, end, sort in
                    let response = try await manager.fetchDivoomCategoryImages(
                        categoryId: selectedCategoryId,
                        startNum: start,
                        endNum: end,
                        fileSort: sort,
                        refreshIndex: 0
                    )
                    return (response.FileList ?? [], response.CurListNum ?? 0)
                },
                onPlayTapped: { sort in
                    sendCategoryCommand(sortOrder: sort)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(selectedCategoryId)
        }
        //.frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Категории", isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }
    
    private func sendCategoryCommand(sortOrder: Int) {
        let currentCategory = categories.first(where: { $0.id == selectedCategoryId })
        let categoryName = currentCategory?.name ?? "Категория"
        
        Task {
            do {
                try await manager.updateAnimationType(.category(id: selectedCategoryId, sortOrder: sortOrder))
                
                await MainActor.run {
                    self.alertMessage = "\(categoryName) воспроизводится на устройстве"
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
