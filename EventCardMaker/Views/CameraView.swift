import SwiftUI

struct CameraView: View {
    @ObservedObject var cameraService: CameraService
    @Binding var cardData: CardData
    var onCapture: () -> Void
    
    @State private var isCapturing = false
    
    var body: some View {
        ZStack {
            if cameraService.permissionDenied {
                permissionDeniedView
            } else if cameraService.currentFrame != nil {
                cameraPreviewView
            } else {
                loadingView
            }
        }
        .onAppear { cameraService.start() }
        .onDisappear { cameraService.stop() }
    }
    
    // MARK: - カメラプレビュー
    
    private var cameraPreviewView: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Text("人物を撮影")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                
                Spacer()
                
                Button { cameraService.toggleCamera() } label: {
                    Image(systemName: "camera.rotate.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)
            
            // モード切替（スクロール可能）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SegmentationMode.allCases, id: \.self) { mode in
                        Button {
                            cameraService.segmentationMode = mode
                        } label: {
                            Text(mode.label)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(cameraService.segmentationMode == mode ? .black : .white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(cameraService.segmentationMode == mode ? Color.green : Color.white.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(cameraService.currentFPS) fps")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(fpsColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.6))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // 閾値スライダー（PersonSegmentationモード時のみ表示）
            if cameraService.segmentationMode != .foregroundMask {
                HStack(spacing: 8) {
                    Text("閾値")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(width: 30)
                    
                    Slider(value: $cameraService.maskThreshold, in: 0.5...0.99, step: 0.01)
                        .tint(.green)
                    
                    Text(String(format: "%.2f", cameraService.maskThreshold))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            } else {
                Text("ForegroundInstanceMask — 閾値なし（自動最適化）")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
            
            Spacer()
            
            // 2画面比較
            HStack(spacing: 8) {
                VStack(spacing: 6) {
                    Text("RAW")
                        .font(.caption.bold())
                        .foregroundColor(.yellow)
                    if let frame = cameraService.currentFrame {
                        Image(uiImage: frame)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                    }
                }
                
                VStack(spacing: 6) {
                    Text(cameraService.segmentationMode == .foregroundMask ? "FOREGROUND" : "SEGMENTED")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                    
                    if let masked = cameraService.previewWithMask {
                        Image(uiImage: masked)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                            .background(CheckerboardBackground().cornerRadius(12))
                    } else {
                        ZStack {
                            Color.gray.opacity(0.2).cornerRadius(12)
                            Text("人物未検出")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
            
            // ステータス
            HStack(spacing: 12) {
                if cameraService.previewWithMask != nil {
                    Label("検出中", systemImage: "person.fill.checkmark")
                        .font(.callout.bold())
                        .foregroundColor(.green)
                }
                Text(cameraService.isFrontCamera ? "フロント" : "リア")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.gray.opacity(0.3))
                    .cornerRadius(6)
                Text(cameraService.segmentationMode.label)
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.15))
                    .cornerRadius(6)
            }
            .padding(8)
            .background(.black.opacity(0.6))
            .cornerRadius(8)
            
            // シャッター
            Button { capturePhoto() } label: {
                ZStack {
                    Circle().fill(.white).frame(width: 72, height: 72)
                    Circle().stroke(.white, lineWidth: 4).frame(width: 82, height: 82)
                    if isCapturing { ProgressView().tint(.black) }
                }
            }
            .disabled(isCapturing)
            .opacity(isCapturing ? 0.7 : 1)
            .padding(.bottom, 40)
        }
    }
    
    private var fpsColor: Color {
        if cameraService.currentFPS >= 20 { return .green }
        if cameraService.currentFPS >= 10 { return .yellow }
        return .red
    }
    
    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            Text("カメラへのアクセスが必要です")
                .font(.title3.bold())
                .foregroundColor(.white)
            Text("設定 → EventCardMaker → カメラをONにしてください")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(1.5)
            Text("カメラを起動中...")
                .foregroundColor(.gray)
        }
    }
    
    private func capturePhoto() {
        isCapturing = true
        cameraService.captureHighQuality { original, segmented in
            if let original, let segmented {
                cardData.capturedImage = original
                cardData.segmentedImage = segmented
                onCapture()
            }
            isCapturing = false
        }
    }
}

struct CheckerboardBackground: View {
    let size: CGFloat = 10
    var body: some View {
        Canvas { context, canvasSize in
            let rows = Int(canvasSize.height / size) + 1
            let cols = Int(canvasSize.width / size) + 1
            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(x: CGFloat(col) * size, y: CGFloat(row) * size, width: size, height: size)
                    context.fill(Path(rect), with: .color(isLight ? Color.gray.opacity(0.3) : Color.gray.opacity(0.15)))
                }
            }
        }
    }
}
