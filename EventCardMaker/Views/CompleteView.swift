import SwiftUI

struct CompleteView: View {
    var onReset: () -> Void
    
    @State private var showQR = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("アップロード完了！")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            
            // QRコード（モック）
            if showQR {
                Image(systemName: "qrcode")
                    .font(.system(size: 120))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
                
                Text("QRコードを読み取ってカードを取得")
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button {
                onReset()
            } label: {
                Text("次の人を撮影")
                    .font(.title3.bold())
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .onAppear {
            // アップロードシミュレーション
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation { showQR = true }
            }
        }
    }
}
