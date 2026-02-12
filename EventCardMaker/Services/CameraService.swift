import AVFoundation
import UIKit
import Vision

class CameraService: NSObject, ObservableObject {
    @Published var currentFrame: UIImage?
    @Published var segmentationMask: UIImage?
    @Published var previewWithMask: UIImage?
    @Published var permissionDenied = false
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "camera.processing", qos: .userInteractive)
    
    private var segmentationRequest: VNGeneratePersonSegmentationRequest = {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .fast // リアルタイムプレビュー用
        return request
    }()
    
    var isRunning: Bool { captureSession.isRunning }
    
    func start() {
        guard !captureSession.isRunning else { return }
        
        // カメラ権限チェック
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
    
    func captureHighQuality(completion: @escaping (UIImage?, UIImage?) -> Void) {
        guard let frame = currentFrame, let ciImage = CIImage(image: frame) else {
            completion(nil, nil)
            return
        }
        
        processingQueue.async {
            // 高精度セグメンテーション
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
                    let context = CIContext()
                    if let cgImage = context.createCGImage(maskedCIImage, from: maskedCIImage.extent) {
                        let segmented = UIImage(cgImage: cgImage)
                        DispatchQueue.main.async {
                            completion(frame, segmented)
                        }
                        return
                    }
                }
            } catch {
                print("High quality segmentation failed: \(error)")
            }
            
            DispatchQueue.main.async { completion(nil, nil) }
        }
    }
    
    private func setupCamera() {
        captureSession.sessionPreset = .photo
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("Failed to get camera device")
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        // フレーム画像
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)
        
        // リアルタイムセグメンテーション
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([segmentationRequest])
        
        var maskImage: UIImage?
        if let mask = segmentationRequest.results?.first?.pixelBuffer {
            let maskCI = CIImage(cvPixelBuffer: mask)
            // マスクを元画像に適用
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
        
        DispatchQueue.main.async { [weak self] in
            self?.currentFrame = uiImage
            self?.previewWithMask = maskImage
        }
    }
}
