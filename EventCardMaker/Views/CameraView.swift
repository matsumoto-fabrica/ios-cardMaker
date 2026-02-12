import SwiftUI

struct CameraView: View {
    @ObservedObject var cameraService: CameraService
    @Binding var cardData: CardData
    var onCapture: () -> Void
    
    @State private var isCapturing = false
    
    var body: some View {
        ZStack {
            if cameraService.permissionDenied {
                // カメラ権限拒否時
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
            } else if cameraService.currentFrame != nil {
                // カメラ映像あり → 2画面並列表示
                VStack(spacing: 0) {
                    Text("人物を撮影してください")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding(.top, 60)
                    
                    Spacer()
                    
                    // 2画面比較
                    HStack(spacing: 8) {
                        // 左: 生カメラ映像
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
                        
                        // 右: 切り抜き済み
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
                                        // チェッカーボードで透過部分を可視化
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
                    
                    // 人物検出ステータス
                    if cameraService.previewWithMask != nil {
                        Label("人物を検出中", systemImage: "person.fill.checkmark")
                            .font(.callout.bold())
                            .foregroundColor(.green)
                            .padding(8)
                            .background(.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                    
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
                        }
                    }
                    .disabled(isCapturing)
                    .opacity(isCapturing ? 0.5 : 1)
                    .padding(.bottom, 40)
                }
            } else {
                // カメラ起動中
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("カメラを起動中...")
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            cameraService.start()
        }
        .onDisappear {
            cameraService.stop()
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
