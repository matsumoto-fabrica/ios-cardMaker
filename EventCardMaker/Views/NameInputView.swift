import SwiftUI

struct NameInputView: View {
    @Binding var cardData: CardData
    var onNext: () -> Void
    
    @FocusState private var isFocused: Bool
    
    private let maxLength = 20
    
    var isValid: Bool {
        let trimmed = cardData.name.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.count <= maxLength
    }
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Text("名前を入力")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            
            Text("アルファベットで入力してください")
                .foregroundColor(.gray)
            
            // 撮影画像サムネイル
            if let image = cardData.segmentedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 200)
                    .cornerRadius(12)
            }
            
            VStack(alignment: .trailing, spacing: 8) {
                TextField("YOUR NAME", text: $cardData.name)
                    .textInputAutocapitalization(.characters)
                    .keyboardType(.asciiCapable)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isValid ? Color.green : Color.gray, lineWidth: 2)
                    )
                    .focused($isFocused)
                    .onChange(of: cardData.name) { _, newValue in
                        // アルファベット・スペースのみ許可
                        let filtered = newValue.filter { $0.isLetter || $0 == " " }
                        if filtered != newValue {
                            cardData.name = filtered
                        }
                        if filtered.count > maxLength {
                            cardData.name = String(filtered.prefix(maxLength))
                        }
                    }
                
                Text("\(cardData.name.count)/\(maxLength)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            Button {
                onNext()
            } label: {
                Text("次へ")
                    .font(.title3.bold())
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValid ? Color.white : Color.gray)
                    .cornerRadius(16)
            }
            .disabled(!isValid)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .onAppear { isFocused = true }
    }
}
