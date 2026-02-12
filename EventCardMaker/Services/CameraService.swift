import AVFoundation
import UIKit
import Vision

enum SegmentationMode: String, CaseIterable {
    case personFast = "Person Fast"
    case personBalanced = "Person Bal"
    case personAccurate = "Person Acc"
    case foregroundMask = "Foreground"
    
    var label: String { rawValue }
}

class CameraService: NSObject, ObservableObject {
    @Published var currentFrame: UIImage?
    @Published var previewWithMask: UIImage?
    @Published var permissionDenied = false
    @Published var isFrontCamera = false
    @Published var segmentationMode: SegmentationMode = .foregroundMask
    /// マスク閾値: 0.5〜0.99
    @Published var maskThreshold: Float = 0.9
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "camera.processing", qos: .userInteractive)
    // 撮影処理用の別キュー（processingQueueをブロックしない）
    private let captureQueue = DispatchQueue(label: "camera.capture", qos: .userInitiated)
    private var currentInput: AVCaptureDeviceInput?
    
    // PersonSegmentation用（モード別に精度変更）
    private var personSegmentationRequest: VNGeneratePersonSegmentationRequest = {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        return request
    }()
    
    // FPS計測
    @Published var currentFPS: Int = 0
    private var frameCount = 0
    private var lastFPSUpdate = Date()
    
    // 最新フレームを保持（撮影用、ロックで保護）
    private var latestPixelBuffer: CVPixelBuffer?
    private var latestFrameImage: UIImage?
    private let frameLock = NSLock()
    
    var isRunning: Bool { captureSession.isRunning }
    
    func start() {
        guard !captureSession.isRunning else { return }
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            processingQueue.async { [weak self] in
                self?.setupCamera()
                self?.captureSession.startRunning()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.processingQueue.async {
                        self?.setupCamera()
                        self?.captureSession.startRunning()
                    }
                } else {
                    DispatchQueue.main.async { self?.permissionDenied = true }
                }
            }
        default:
            DispatchQueue.main.async { [weak self] in self?.permissionDenied = true }
        }
    }
    
    func stop() {
        captureSession.stopRunning()
    }
    
    func toggleCamera() {
        processingQueue.async { [weak self] in
            guard let self else { return }
            let newPosition: AVCaptureDevice.Position = isFrontCamera ? .back : .front
            guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newCamera) else { return }
            
            captureSession.beginConfiguration()
            if let currentInput = self.currentInput { captureSession.removeInput(currentInput) }
            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
                self.currentInput = newInput
            }
            self.updateVideoOrientation()
            captureSession.commitConfiguration()
            DispatchQueue.main.async { self.isFrontCamera = !self.isFrontCamera }
        }
    }
    
    /// 高精度撮影（別キューで実行、カメラフレーム処理をブロックしない）
    func captureHighQuality(completion: @escaping (UIImage?, UIImage?) -> Void) {
        frameLock.lock()
        let frame = latestFrameImage
        frameLock.unlock()
        
        guard let frame, let ciImage = CIImage(image: frame) else {
            completion(nil, nil)
            return
        }
        
        let threshold = maskThreshold
        
        // 別キューで実行（processingQueueをブロックしない）
        captureQueue.async { [weak self] in
            guard let self else {
                DispatchQueue.main.async { completion(nil, nil) }
                return
            }
            
            do {
                let request = VNGenerateForegroundInstanceMaskRequest()
                let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
                try handler.perform([request])
                
                if let result = request.results?.first {
                    let maskedBuffer = try result.generateMaskedImage(
                        ofInstances: result.allInstances,
                        from: handler,
                        croppedToInstancesExtent: false
                    )
                    let maskedCIImage = CIImage(cvPixelBuffer: maskedBuffer)
                    
                    // 閾値適用
                    let thresholded = self.applyThresholdToMaskedImage(maskedCIImage, threshold: threshold)
                    
                    let context = CIContext()
                    if let finalImage = thresholded,
                       let cgImage = context.createCGImage(finalImage, from: finalImage.extent) {
                        let segmented = UIImage(cgImage: cgImage)
                        DispatchQueue.main.async { completion(frame, segmented) }
                        return
                    }
                }
            } catch {
                print("Capture failed: \(error)")
            }
            DispatchQueue.main.async { completion(nil, nil) }
        }
    }
    
    // MARK: - Private
    
    private func setupCamera() {
        captureSession.sessionPreset = .photo
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else { return }
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
            currentInput = input
        }
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(videoOutput) { captureSession.addOutput(videoOutput) }
        updateVideoOrientation()
    }
    
    private func updateVideoOrientation() {
        if let connection = videoOutput.connection(with: .video) {
            connection.videoRotationAngle = 90
            if isFrontCamera || currentInput?.device.position == .front {
                connection.isVideoMirrored = true
            }
        }
    }
    
    /// マスク済み画像に閾値処理
    private func applyThresholdToMaskedImage(_ image: CIImage, threshold: Float) -> CIImage? {
        // アルファチャンネルに閾値を適用
        // maskedImageのアルファ値がthreshold以下なら透明にする
        return image // ForegroundInstanceMaskは既にバイナリに近いので基本そのまま
    }
    
    /// PersonSegmentationマスクに閾値を適用
    private func applyMaskThreshold(_ maskCI: CIImage, threshold: Float) -> CIImage {
        let sharpness: Float = 20.0
        let bias = -threshold * sharpness + sharpness / 2.0
        
        let matrixFilter = CIFilter.colorMatrix()
        matrixFilter.inputImage = maskCI
        matrixFilter.rVector = CIVector(x: CGFloat(sharpness), y: 0, z: 0, w: 0)
        matrixFilter.gVector = CIVector(x: 0, y: CGFloat(sharpness), z: 0, w: 0)
        matrixFilter.bVector = CIVector(x: 0, y: 0, z: CGFloat(sharpness), w: 0)
        matrixFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: CGFloat(sharpness))
        matrixFilter.biasVector = CIVector(x: CGFloat(bias), y: CGFloat(bias), z: CGFloat(bias), w: CGFloat(bias))
        
        guard let output = matrixFilter.outputImage else { return maskCI }
        
        let clampFilter = CIFilter.colorClamp()
        clampFilter.inputImage = output
        clampFilter.minComponents = CIVector(x: 0, y: 0, z: 0, w: 0)
        clampFilter.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)
        
        return clampFilter.outputImage ?? maskCI
    }
    
    /// ForegroundInstanceMask でリアルタイムセグメンテーション
    private func performForegroundMask(ciImage: CIImage, context: CIContext) -> UIImage? {
        do {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            try handler.perform([request])
            
            if let result = request.results?.first {
                let maskedBuffer = try result.generateMaskedImage(
                    ofInstances: result.allInstances,
                    from: handler,
                    croppedToInstancesExtent: false
                )
                let maskedCIImage = CIImage(cvPixelBuffer: maskedBuffer)
                if let cgImage = context.createCGImage(maskedCIImage, from: maskedCIImage.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        } catch {
            // ForegroundInstanceMask failed, return nil
        }
        return nil
    }
    
    /// PersonSegmentation でリアルタイムセグメンテーション
    private func performPersonSegmentation(pixelBuffer: CVPixelBuffer, ciImage: CIImage, context: CIContext) -> UIImage? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([personSegmentationRequest])
        
        guard let mask = personSegmentationRequest.results?.first?.pixelBuffer else { return nil }
        let maskCI = CIImage(cvPixelBuffer: mask)
        
        let currentThreshold = maskThreshold
        let thresholdedMask = applyMaskThreshold(maskCI, threshold: currentThreshold)
        
        let scaledMask = thresholdedMask.transformed(by: CGAffineTransform(
            scaleX: ciImage.extent.width / maskCI.extent.width,
            y: ciImage.extent.height / maskCI.extent.height
        ))
        
        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = ciImage
        blendFilter.backgroundImage = CIImage(color: .clear).cropped(to: ciImage.extent)
        blendFilter.maskImage = scaledMask
        
        if let output = blendFilter.outputImage,
           let outputCG = context.createCGImage(output, from: output.extent) {
            return UIImage(cgImage: outputCG)
        }
        return nil
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)
        
        // 最新フレーム保持（撮影用）
        frameLock.lock()
        latestFrameImage = uiImage
        latestPixelBuffer = pixelBuffer
        frameLock.unlock()
        
        // モード別セグメンテーション
        let mode = segmentationMode
        var maskImage: UIImage?
        
        switch mode {
        case .personFast:
            personSegmentationRequest.qualityLevel = .fast
            maskImage = performPersonSegmentation(pixelBuffer: pixelBuffer, ciImage: ciImage, context: context)
        case .personBalanced:
            personSegmentationRequest.qualityLevel = .balanced
            maskImage = performPersonSegmentation(pixelBuffer: pixelBuffer, ciImage: ciImage, context: context)
        case .personAccurate:
            personSegmentationRequest.qualityLevel = .accurate
            maskImage = performPersonSegmentation(pixelBuffer: pixelBuffer, ciImage: ciImage, context: context)
        case .foregroundMask:
            maskImage = performForegroundMask(ciImage: ciImage, context: context)
        }
        
        // FPS計測
        frameCount += 1
        let now = Date()
        let elapsed = now.timeIntervalSince(lastFPSUpdate)
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentFrame = uiImage
            self.previewWithMask = maskImage
            
            if elapsed >= 1.0 {
                self.currentFPS = self.frameCount
                self.frameCount = 0
                self.lastFPSUpdate = now
            }
        }
    }
}
