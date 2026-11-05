//
//  AnimatedImageView.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov on 31.10.2026.
//

import SwiftUI
import UIKit

struct AnimatedImageView: UIViewRepresentable {
    let image: UIImage?

    func makeUIView(context: Context) -> UIView {
        // Создаем нейтральный контейнер-обертку без intrinsic size,
        // чтобы он строго подчинялся ограничениям SwiftUI (.frame)
        let container = UIView()
        container.backgroundColor = .black
        container.clipsToBounds = true
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.magnificationFilter = .nearest
        imageView.layer.minificationFilter = .nearest
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(imageView)
        
        // Тонкая темно-серая сетка поверх пикселей
        let gridOverlayView = PixelGridView()
        gridOverlayView.backgroundColor = .clear
        gridOverlayView.isUserInteractionEnabled = false
        gridOverlayView.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(gridOverlayView)
        
        // Жестко привязываем UIImageView и сетку к краям контейнера
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
        
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Находим наш UIImageView внутри контейнера
        guard let imageView = uiView.subviews.first(where: { $0 is UIImageView }) as? UIImageView else { return }
        
        imageView.image = image
        if let image = image, let frames = image.images {
            imageView.animationImages = frames
            imageView.animationDuration = image.duration
            imageView.startAnimating()
        } else {
            imageView.stopAnimating()
            imageView.animationImages = nil
        }
    }
}

/// Кастомный UIView для отрисовки тонкой темно-серой сетки 16x16 пикселей
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
        
        // Рисуем вертикальные линии сетки
        for i in 1..<cols {
            let x = CGFloat(i) * dx
            context?.move(to: CGPoint(x: x, y: 0))
            context?.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        // Рисуем горизонтальные линии сетки
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
