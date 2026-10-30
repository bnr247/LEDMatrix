//
//  CachedAsyncImage.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 30.10.2026.
//

import SwiftUI

// MARK: - In-Memory Image Cache

final class ImageCache {
    static let shared = ImageCache()
    private init() {}
    
    private var cache = NSCache<NSURL, UIImage>()
    
    func image(for url: URL) -> UIImage? {
        return cache.object(forKey: url as NSURL)
    }
    
    func insert(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

// MARK: - CachedAsyncImage Component

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var image: UIImage? = nil
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .onChange(of: url) { _, _ in
            loadImage()
        }
    }

    private func loadImage() {
        guard let url = url else { return }

        // 1. Проверяем оперативный кэш (NSCache)
        if let cachedImage = ImageCache.shared.image(for: url) {
            self.image = cachedImage
            return
        }

        guard !isLoading else { return }
        isLoading = true

        // 2. Если в кэше нет — загружаем по сети
        Task {
            do {
                let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15.0)
                let (data, _) = try await URLSession.shared.data(for: request)
                if let downloadedImage = UIImage(data: data) {
                    // Сохраняем в NSCache
                    ImageCache.shared.insert(downloadedImage, for: url)
                    await MainActor.run {
                        self.image = downloadedImage
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}
