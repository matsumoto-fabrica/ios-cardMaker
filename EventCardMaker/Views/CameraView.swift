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
            } else if let preview = cameraService.previewWithMask {
                // リアルタイム切り抜きプレビュー
                Image(uiImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let frame = cameraService.currentFrame {
                // 通常カメラプレビュー
                Image(uiImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // カメラ起動中
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("カメラを起動中...")
                        .foregroundColor(.gray)
                }
            }
            
            // UI オーバーレイ（カメラ権限OK時のみ）
            if !cameraService.permissionDenied {
                VStack {
                    Text("人物を撮影してください")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding(.top, 60)
                    
                    Spacer()
                    
                    if cameraService.previewWithMask != nil {
                        Label("人物を検出中", systemImage: "person.fill.checkmark")
                            .font(.callout.bold())
                            .foregroundColor(.green)
                            .padding(8)
                            .background(.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                    
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
                    .disabled(isCapturing || cameraService.currentFrame == nil)
                    .opacity(isCapturing || cameraService.currentFrame == nil ? 0.5 : 1)
                    .padding(.bottom, 40)
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
