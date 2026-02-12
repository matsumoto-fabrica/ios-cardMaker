import SwiftUI

struct CardPreviewView: View {
    @Binding var cardData: CardData
    var onConfirm: () -> Void
    
    @State private var isComposing = true
    
    private let compositor = ImageCompositor()
    
    var body: some View {
        VStack(spacing: 30) {
            Text("カードプレビュー")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
                .padding(.top, 60)
            
            if isComposing {
                ProgressView("合成中...")
                    .foregroundColor(.white)
                    .frame(maxHeight: .infinity)
            } else if let composite = cardData.compositeImage {
                Image(uiImage: composite)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(16)
                    .shadow(radius: 20)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            HStack(spacing: 20) {
                Button("撮り直す") {
                    // TODO: カメラに戻る
                }
                .font(.body.bold())
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(16)
                
                Button("アップロード") {
                    onConfirm()
                }
                .font(.body.bold())
                .foregroundColor(.black)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .onAppear {
            composeCard()
        }
    }
    
    private func composeCard() {
        guard let person = cardData.segmentedImage else { return }
        let template = CardTemplate.samples[cardData.templateIndex]
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = compositor.compose(person: person, template: template, name: cardData.name)
            DispatchQueue.main.async {
                cardData.compositeImage = result
                isComposing = false
            }
        }
    }
}
