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
                        initialImages: {
                            guard let fileId = item.FileId, let image else { return [:] }
                            return [fileId: image]
                        }(),
                        selectedItemId: item.id,
                        fetchMoreItems: fetchMoreItems
                    )
                } label: {
                    AnimatedImageView(manager: manager, item: item, image: image)
                }
                .buttonStyle(.plain)
            } else {
                // Пустой слот ничего не рисует, но занимает ту же ширину,
                // чтобы заполненные превью не растягивались.
                Color.clear
            }
        }
    }
}

