import SwiftUI

struct CameraView: View {
    @ObservedObject var cameraService: CameraService
    @Binding var cardData: CardData
    var onCapture: () -> Void
    
    @State private var isCapturing = false
    
    var body: some View {
        ZStack {
            // カメラプレビュー（リアルタイム切り抜き表示）
            if let preview = cameraService.previewWithMask {
                Image(uiImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let frame = cameraService.currentFrame {
                Image(uiImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // カメラ未起動時のプレースホルダー
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("カメラを起動中...")
                        .foregroundColor(.gray)
                }
            }
            
            // UI オーバーレイ
            VStack {
                // ガイドテキスト
                Text("人物を撮影してください")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.top, 60)
                
                Spacer()
                
                // 人物検出インジケーター
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
