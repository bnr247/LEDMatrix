//
//  DivoomPreviewThumbnails.swift
//  LEDMatrix
//
//  Три превью анимаций в карточке. Пустые слоты сохраняют тот же размер,
//  что и заполненные, поэтому одна-две анимации не растягиваются на всю ширину.
//

import SwiftUI

struct DivoomPreviewThumbnails: View {
    let manager: MatrixManager
    let title: String
    let items: [DivoomFileItem]
    let images: [String: UIImage]
    let fetchMoreItems: (_ startNum: Int, _ endNum: Int) async throws -> [DivoomFileItem]

    private let slots = 3

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<slots, id: \.self) { index in
                DivoomPreviewThumbnailSlot(
                    manager: manager,
                    title: title,
                    item: index < items.count ? items[index] : nil,
                    initialItems: items,
                    image: index < items.count ? images[items[index].FileId ?? ""] : nil,
                    fetchMoreItems: fetchMoreItems
                )
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct DivoomPreviewThumbnailSlot: View {
    @ObservedObject var manager: MatrixManager
    let title: String
    let item: DivoomFileItem?
    let initialItems: [DivoomFileItem]
    let image: UIImage?
    let fetchMoreItems: (_ startNum: Int, _ endNum: Int) async throws -> [DivoomFileItem]

    var body: some View {
        Group {
            if let item = item {
                NavigationLink {
                    DivoomFeedView(
                        title: title,
                        manager: manager,
                        initialItems: initialItems,
                        selectedItemId: item.id,
                        fetchMoreItems: fetchMoreItems
                    )
                } label: {
                    AnimatedImageView(manager: manager, item: item, image: image)
                }
                .buttonStyle(.plain)
            } else {
                DivoomPreviewPlaceholder()
            }
        }
    }
}

/// Пустой слот той же формы, что и AnimatedImageView: квадрат плюс плашка 28 pt.
private struct DivoomPreviewPlaceholder: View {
    var body: some View {
        VStack(spacing: 0) {
            Color.black
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Color.black.opacity(0.85)
                .frame(height: 28)
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
