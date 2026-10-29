//
//  CameraStreamController.swift
//  LEDMatrix
//
//  Created by Stanislav Leonov  on 29.10.2026.
//

import AVFoundation
import SwiftUI

/// Контроллер захвата кадров камеры через AVFoundation
class CameraStreamController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.matrix.cameraSessionQueue")
    
    var onFrameCaptured: ((UIImage) -> Void)?
    private var lastSampleTime: CMTime = .zero
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.configureSession()
            self.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }
    
    private func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .medium
        
        // Выбираем тыловую камеру по умолчанию
        let cameraPosition: AVCaptureDevice.Position = .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition),
              let input = try? AVCaptureDeviceInput(device: device)
        else {
            captureSession.commitConfiguration()
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
            videoDeviceInput = input
        }
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.matrix.videoQueue"))
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        }
        
        captureSession.commitConfiguration()
    }
    
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self, let currentInput = self.videoDeviceInput else { return }
            
            let currentPosition = currentInput.device.position
            let newPosition: AVCaptureDevice.Position = (currentPosition == .back) ? .front : .back
            
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else { return }
            
            self.captureSession.beginConfiguration()
            self.captureSession.removeInput(currentInput)
            
            if self.captureSession.canAddInput(newInput) {
                self.captureSession.addInput(newInput)
                self.videoDeviceInput = newInput
            } else {
                self.captureSession.addInput(currentInput)
            }
            
            self.captureSession.commitConfiguration()
        }
    }
    
    /// Получение кадра из потока камеры (~15 кадров/сек для стабильности сети)
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if timestamp.seconds - lastSampleTime.seconds < 0.066 { // Ограничение ~15 FPS
            return
        }
        lastSampleTime = timestamp
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        let uiImage = UIImage(cgImage: cgImage)
        DispatchQueue.main.async {
            self.onFrameCaptured?(uiImage)
        }
    }
    
    private var photoCompletion: ((UIImage?) -> Void)?
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        photoCompletion = completion
        // Отправляем последний актуальный кадр через callback
        sessionQueue.async { [weak self] in
            // Передаем снимок в замыкание
            guard let self = self, let input = self.videoDeviceInput else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            // Делаем снимок текущего кадра через видео-поток
            // (вспомогательный метод сбросит текущую картинку в галерею)
        }
    }
}
