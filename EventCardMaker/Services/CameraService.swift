import AVFoundation
import UIKit
import Vision

enum SegmentationQuality: String, CaseIterable {
    case fast = "Fast"
    case balanced = "Balanced"
    case accurate = "Accurate"
    
    var vnQuality: VNGeneratePersonSegmentationRequest.QualityLevel {
        switch self {
        case .fast: return .fast
        case .balanced: return .balanced
        case .accurate: return .accurate
        }
    }
    
    var label: String {
        switch self {
        case .fast: return "Fast (30fps)"
        case .balanced: return "Balanced (15fps)"
        case .accurate: return "Accurate (3fps)"
        }
    }
}

class CameraService: NSObject, ObservableObject {
    @Published var currentFrame: UIImage?
    @Published var segmentationMask: UIImage?
    @Published var previewWithMask: UIImage?
    @Published var permissionDenied = false
    @Published var isFrontCamera = false
    @Published var quality: SegmentationQuality = .balanced {
        didSet {
            segmentationRequest.qualityLevel = quality.vnQuality
        }
    }
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "camera.processing", qos: .userInteractive)
    private var currentInput: AVCaptureDeviceInput?
    
    private lazy var segmentationRequest: VNGeneratePersonSegmentationRequest = {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = quality.vnQuality
        return request
    }()
    
    // FPS計測用
    @Published var currentFPS: Int = 0
    private var frameCount = 0
    private var lastFPSUpdate = Date()
    
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
                    DispatchQueue.main.async {
                        self?.permissionDenied = true
                    }
                }
            }
        default:
            DispatchQueue.main.async { [weak self] in
                self?.permissionDenied = true
            }
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
            
            if let currentInput = self.currentInput {
                captureSession.removeInput(currentInput)
            }
            
            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
                self.currentInput = newInput
            }
            
            self.updateVideoOrientation()
            captureSession.commitConfiguration()
            
            DispatchQueue.main.async {
                self.isFrontCamera = !self.isFrontCamera
            }
        }
    }
    
    /// バースト撮影: 複数フレームから最良の切り抜きを選択
    func captureHighQuality(burstCount: Int = 3, completion: @escaping (UIImage?, UIImage?) -> Void) {
        guard let frame = currentFrame, let ciImage = CIImage(image: frame) else {
            completion(nil, nil)
            return
        }
        
        processingQueue.async { [weak self] in
            guard let self else { return }
            
            // バーストで複数フレーム処理
            var bestResult: (original: UIImage, segmented: UIImage, coverage: CGFloat)?
            
            for i in 0..<burstCount {
                // 最初のフレームは現在のフレームを使用、以降は少し待って新しいフレームを取得
                let targetFrame: UIImage
                let targetCI: CIImage
                
                if i == 0 {
                    targetFrame = frame
                    targetCI = ciImage
                } else {
                    // 少し待って次のフレームを取得
                    Thread.sleep(forTimeInterval: 0.1)
                    guard let newFrame = self.currentFrame,
                          let newCI = CIImage(image: newFrame) else { continue }
                    targetFrame = newFrame
                    targetCI = newCI
                }
                
                do {
                    let request = VNGenerateForegroundInstanceMaskRequest()
                    let handler = VNImageRequestHandler(ciImage: targetCI, options: [:])
                    try handler.perform([request])
                    
                    if let result = request.results?.first {
                        let maskedBuffer = try result.generateMaskedImage(
                            ofInstances: result.allInstances,
                            from: handler,
                            croppedToInstancesExtent: false
                        )
                        let maskedCIImage = CIImage(cvPixelBuffer: maskedBuffer)
                        let context = CIContext()
                        if let cgImage = context.createCGImage(maskedCIImage, from: maskedCIImage.extent) {
                            let segmented = UIImage(cgImage: cgImage)
                            
                            // マスクのカバレッジ（非透明ピクセルの割合）で品質評価
                            let coverage = self.calculateMaskCoverage(maskedBuffer)
                            
                            if bestResult == nil || coverage > bestResult!.coverage {
                                bestResult = (targetFrame, segmented, coverage)
                            }
                        }
                    }
                } catch {
                    print("Burst frame \(i) failed: \(error)")
                }
            }
            
            DispatchQueue.main.async {
                if let best = bestResult {
                    print("Best burst frame coverage: \(best.coverage)")
                    completion(best.original, best.segmented)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    /// マスクのカバレッジ計算（品質評価用）
    private func calculateMaskCoverage(_ pixelBuffer: CVPixelBuffer) -> CGFloat {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let totalPixels = width * height
        guard totalPixels > 0 else { return 0 }
        
        // 簡易チェック: 中央付近のピクセルをサンプリング
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return 0 }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        var nonZeroCount = 0
        let sampleStep = 4 // 4ピクセルおきにサンプリング（高速化）
        
        for y in stride(from: 0, to: height, by: sampleStep) {
            let rowPtr = baseAddress.advanced(by: y * bytesPerRow)
            for x in stride(from: 0, to: width, by: sampleStep) {
                let pixel = rowPtr.advanced(by: x * 4).load(as: UInt8.self)
                if pixel > 128 { nonZeroCount += 1 }
            }
        }
        
        let sampledTotal = (width / sampleStep) * (height / sampleStep)
        return CGFloat(nonZeroCount) / CGFloat(max(sampledTotal, 1))
    }
    
    private func setupCamera() {
        captureSession.sessionPreset = .photo
        
        let position: AVCaptureDevice.Position = .back
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("Failed to get camera device")
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
            currentInput = input
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
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
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)
        
        // リアルタイムセグメンテーション
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([segmentationRequest])
        
        var maskImage: UIImage?
        if let mask = segmentationRequest.results?.first?.pixelBuffer {
            let maskCI = CIImage(cvPixelBuffer: mask)
            let blendFilter = CIFilter.blendWithMask()
            blendFilter.inputImage = ciImage
            blendFilter.backgroundImage = CIImage(color: .clear).cropped(to: ciImage.extent)
            blendFilter.maskImage = maskCI.transformed(by: CGAffineTransform(
                scaleX: ciImage.extent.width / maskCI.extent.width,
                y: ciImage.extent.height / maskCI.extent.height
            ))
            
            if let output = blendFilter.outputImage,
               let outputCG = context.createCGImage(output, from: output.extent) {
                maskImage = UIImage(cgImage: outputCG)
            }
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
