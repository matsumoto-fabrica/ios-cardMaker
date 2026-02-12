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
        .onAppear {
            cameraService.start()
        }
        .onDisappear {
            cameraService.stop()
        }
    }
    
    // MARK: - カメラプレビュー
    
    private var cameraPreviewView: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Text("人物を撮影してください")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                
                Spacer()
                
                Button {
                    cameraService.toggleCamera()
                } label: {
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
            
            // 精度切り替えボタン
            HStack(spacing: 8) {
                ForEach(SegmentationQuality.allCases, id: \.self) { q in
                    Button {
                        cameraService.quality = q
                    } label: {
                        Text(q.rawValue)
                            .font(.caption.bold())
                            .foregroundColor(cameraService.quality == q ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(cameraService.quality == q ? Color.green : Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                // リアルタイムFPS表示
                Text("\(cameraService.currentFPS) fps")
                    .font(.caption.mono())
                    .foregroundColor(fpsColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
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
                    Text("SEGMENTED")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                    
                    if let masked = cameraService.previewWithMask {
                        Image(uiImage: masked)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                            .background(
                                CheckerboardBackground()
                                    .cornerRadius(12)
                            )
                    } else {
                        ZStack {
                            Color.gray.opacity(0.2)
                                .cornerRadius(12)
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
            HStack(spacing: 16) {
                if cameraService.previewWithMask != nil {
                    Label("人物検出中", systemImage: "person.fill.checkmark")
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
            }
            .padding(8)
            .background(.black.opacity(0.6))
            .cornerRadius(8)
            
            // シャッターボタン
            Button {
                capturePhoto()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 72, height: 72)
                    Circle()
                        .stroke(.white, lineWidth: 4)
                        .frame(width: 82, height: 82)
                    
                    if isCapturing {
                        ProgressView()
                            .tint(.black)
                    }
                }
            }
            .disabled(isCapturing)
            .opacity(isCapturing ? 0.7 : 1)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - FPSカラー
    
    private var fpsColor: Color {
        if cameraService.currentFPS >= 20 { return .green }
        if cameraService.currentFPS >= 10 { return .yellow }
        return .red
    }
    
    // MARK: - 権限拒否
    
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
    
    // MARK: - ローディング
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("カメラを起動中...")
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - 撮影
    
    private func capturePhoto() {
        isCapturing = true
        
        // バースト3枚から最良フレームを選択
        cameraService.captureHighQuality(burstCount: 3) { original, segmented in
            if let original, let segmented {
                cardData.capturedImage = original
                cardData.segmentedImage = segmented
                onCapture()
            }
            isCapturing = false
        }
    }
}

// 透過部分を可視化するチェッカーボード
struct CheckerboardBackground: View {
    let size: CGFloat = 10
    
    var body: some View {
        Canvas { context, canvasSize in
            let rows = Int(canvasSize.height / size) + 1
            let cols = Int(canvasSize.width / size) + 1
            
            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * size,
                        y: CGFloat(row) * size,
                        width: size,
                        height: size
                    )
                    context.fill(
                        Path(rect),
                        with: .color(isLight ? Color.gray.opacity(0.3) : Color.gray.opacity(0.15))
                    )
                }
            }
        }
    }
}

// mono font extension
extension Font {
    func mono() -> Font {
        .system(.caption, design: .monospaced)
    }
}
