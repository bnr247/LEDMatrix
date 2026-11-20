//
//  AnimatedImageView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 31.10.2026.
//

import SwiftUI
import UIKit

/// Ограничитель параллельного разбора полных анимаций. При быстром скролле
/// не разворачиваем десятки 600-кадровых анимаций одновременно — только те
/// ячейки, которые реально находятся на экране.
private actor DivoomFullAnimationLimiter {
    static let shared = DivoomFullAnimationLimiter()
    private let limit = 2
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if active < limit {
            active += 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if waiters.isEmpty {
            active = max(0, active - 1)
        } else {
            let next = waiters.removeFirst()
            next.resume()
        }
    }
}

struct AnimatedImageView: View {
    @ObservedObject var manager: MatrixManager
    let item: DivoomFileItem
    /// Быстрый первый кадр из сетки. Полная анимация догружается только
    /// для ячейки, которая находится на экране.
    let image: UIImage?

    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var fullLoadTask: Task<Void, Never>?
    @State private var isVisible = false

    @State private var isLiked: Bool
    @State private var likeCount: Int

    private var displayedImage: UIImage? { loadedImage ?? image }

    init(manager: MatrixManager, item: DivoomFileItem, image: UIImage?) {
        self.manager = manager
        self.item = item
        self.image = image
        _isLiked = State(initialValue: (item.IsLike ?? 0) == 1)
        _likeCount = State(initialValue: item.LikeCnt ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Как в галерее iOS: квадратная миниатюра 1:1, заполняющая всю ширину колонки
            ZStack {
                if let displayedImage {
                    AnimatedImageRepresentable(image: displayedImage, isAnimating: isVisible)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay {
                            if isLoading {
                                ProgressView()
                                    .tint(manager.accentColor)
                            }
                        }
                }
            }

            // Нижняя плашка (как подпись/инфо в iOS Фото)
            HStack(spacing: 0) {
                Button(action: {
                    toggleLike()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(manager.accentColor)
                        Text("\(likeCount)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .themedLightText(manager)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                if let commentCnt = item.CommentCnt {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right.fill")
                            .font(.system(size: 11))
                            .foregroundColor(manager.accentColor)
                        Text("\(commentCnt)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .themedLightText(manager)
                    }
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(Color.black.opacity(0.85))
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onAppear {
            isVisible = true
            beginFullAnimationIfNeeded()
        }
        .onDisappear {
            isVisible = false
            fullLoadTask?.cancel()
            fullLoadTask = nil
        }
    }

    /// Первый кадр уже показан сеткой. Полную анимацию грузим только когда
    /// ячейка появилась на экране, и отменяем задачу при уходе с экрана.
    private func beginFullAnimationIfNeeded() {
        guard fullLoadTask == nil,
              displayedImage?.images == nil,
              let fileId = item.FileId, !fileId.isEmpty else { return }

        // Возврат из фида: анимация уже в кэше — показываем её мгновенно,
        // без новой задачи и без повторного разбора.
        if let cached = DivoomAnimationLoader.cachedAnimation(for: fileId) {
            loadedImage = cached
            return
        }

        fullLoadTask = Task { @MainActor in
            await DivoomFullAnimationLimiter.shared.acquire()
            await performFullLoad(fileId: fileId)
            await DivoomFullAnimationLimiter.shared.release()
        }
    }

    @MainActor
    private func performFullLoad(fileId: String) async {
        if displayedImage == nil {
            if let firstFrame = await DivoomAnimationLoader.loadFirstFrame(from: fileId) {
                guard !Task.isCancelled else { return }
                loadedImage = firstFrame
            }
        }

        if let result = await DivoomAnimationLoader.loadAndCreateAnimation(from: fileId) {
            guard !Task.isCancelled else { return }
            loadedImage = result.image
            isLoading = false
        }
    }

    private func toggleLike() {
        let newIsLiked = !isLiked
        let oldIsLiked = isLiked
        let oldLikeCount = likeCount

        isLiked = newIsLiked
        likeCount = newIsLiked ? oldLikeCount + 1 : max(0, oldLikeCount - 1)

        guard let galleryId = item.GalleryId, !galleryId.isEmpty else { return }

        Task {
            do {
                try await manager.toggleDivoomLike(galleryId: galleryId, isLike: newIsLiked ? 1 : 0)
            } catch {
                await MainActor.run {
                    isLiked = oldIsLiked
                    likeCount = oldLikeCount
                }
            }
        }
    }
}

/// Полная анимация поста в фиде: первый кадр уже передан, полная версия
/// догружается только когда пост находится на экране.
struct DivoomFullAnimationView: View {
    let manager: MatrixManager
    let fileId: String?
    let image: UIImage?

    @State private var loadedImage: UIImage?
    @State private var fullLoadTask: Task<Void, Never>?
    @State private var isVisible = false

    private var displayedImage: UIImage? { loadedImage ?? image }

    var body: some View {
        ZStack {
            if let displayedImage {
                AnimatedImageRepresentable(image: displayedImage, isAnimating: isVisible)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .overlay {
                        ProgressView()
                            .tint(manager.accentColor)
                    }
            }
        }
        .onAppear {
            isVisible = true
            guard fullLoadTask == nil,
                  displayedImage?.images == nil,
                  let fileId, !fileId.isEmpty else { return }

            if let cached = DivoomAnimationLoader.cachedAnimation(for: fileId) {
                loadedImage = cached
                return
            }

            fullLoadTask = Task { @MainActor in
                await DivoomFullAnimationLimiter.shared.acquire()
                await performFullLoad(fileId: fileId)
                await DivoomFullAnimationLimiter.shared.release()
            }
        }
        .onDisappear {
            isVisible = false
            fullLoadTask?.cancel()
            fullLoadTask = nil
        }
    }

    @MainActor
    private func performFullLoad(fileId: String) async {
        if displayedImage == nil,
           let firstFrame = await DivoomAnimationLoader.loadFirstFrame(from: fileId) {
            guard !Task.isCancelled else { return }
            loadedImage = firstFrame
        }

        if let result = await DivoomAnimationLoader.loadAndCreateAnimation(from: fileId) {
            guard !Task.isCancelled else { return }
            loadedImage = result.image
        }
    }
}

struct AnimatedImageRepresentable: UIViewRepresentable {
    let image: UIImage?
    /// Ячейки за пределами экрана не тратят CPU на анимацию.
    var isAnimating: Bool = true

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        container.clipsToBounds = true

        let imageView = UIImageView()
        imageView.backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.magnificationFilter = .nearest
        imageView.layer.minificationFilter = .nearest
        imageView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(imageView)

        let gridOverlayView = PixelGridView()
        gridOverlayView.backgroundColor = .clear
        gridOverlayView.isUserInteractionEnabled = false
        gridOverlayView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(gridOverlayView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            gridOverlayView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gridOverlayView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            gridOverlayView.topAnchor.constraint(equalTo: container.topAnchor),
            gridOverlayView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        updateImageView(imageView, with: image, isAnimating: isAnimating)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let imageView = uiView.subviews.first(where: { $0 is UIImageView }) as? UIImageView else { return }
        updateImageView(imageView, with: image, isAnimating: isAnimating)
    }

    private func updateImageView(_ imageView: UIImageView, with image: UIImage?, isAnimating: Bool) {
        // SwiftUI вызывает updateUIView при каждом скролле. Если картинка та же,
        // пересборка animationImages и startAnimating сбрасывают анимацию и
        // получаются подтормаживания — этого здесь больше нет.
        if imageView.image !== image {
            imageView.image = image
            guard let image, let frames = image.images, !frames.isEmpty else {
                imageView.stopAnimating()
                imageView.animationImages = nil
                return
            }
            imageView.animationImages = frames
            imageView.animationDuration = image.duration
        }

        guard imageView.animationImages != nil else { return }
        if isAnimating {
            if !imageView.isAnimating { imageView.startAnimating() }
        } else if imageView.isAnimating {
            imageView.stopAnimating()
        }
    }
}

private class PixelGridView: UIView {
    override func draw(_ rect: CGRect) {
        guard rect.width > 0, rect.height > 0 else { return }
        let context = UIGraphicsGetCurrentContext()
        context?.setStrokeColor(UIColor(white: 0.3, alpha: 0.6).cgColor)
        context?.setLineWidth(0.5)

        let cols = 16
        let rows = 16
        let dx = rect.width / CGFloat(cols)
        let dy = rect.height / CGFloat(rows)

        for i in 1..<cols {
            let x = CGFloat(i) * dx
            context?.move(to: CGPoint(x: x, y: 0))
            context?.addLine(to: CGPoint(x: x, y: rect.height))
        }

        for j in 1..<rows {
            let y = CGFloat(j) * dy
            context?.move(to: CGPoint(x: 0, y: y))
            context?.addLine(to: CGPoint(x: rect.width, y: y))
        }

        context?.strokePath()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }
}
