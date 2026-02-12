import SwiftUI

struct TemplateSelectView: View {
    @Binding var cardData: CardData
    var onNext: () -> Void
    
    let templates = CardTemplate.samples
    
    var body: some View {
        VStack(spacing: 30) {
            Text("テンプレートを選択")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
                .padding(.top, 60)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(templates) { template in
                        TemplateCard(
                            template: template,
                            personImage: cardData.segmentedImage,
                            name: cardData.name,
                            isSelected: cardData.templateIndex == template.id
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                cardData.templateIndex = template.id
                            }
                        }
                    }
                }
                .padding(.horizontal, 30)
            }
            
            Spacer()
            
            Button {
                onNext()
            } label: {
                Text("このテンプレートで作成")
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
    }
}

struct TemplateCard: View {
    let template: CardTemplate
    let personImage: UIImage?
    let name: String
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [template.backgroundColor, template.backgroundColor.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            VStack {
                // 人物サムネイル
                if let image = personImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 180)
                }
                
                Spacer()
                
                // 名前
                Text(name.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.bottom, 12)
            }
            .padding(.top, 12)
            
            // 枠
            RoundedRectangle(cornerRadius: 16)
                .stroke(template.accentColor, lineWidth: isSelected ? 4 : 1)
        }
        .frame(width: 180, height: 280)
        .scaleEffect(isSelected ? 1.05 : 0.95)
        .shadow(color: isSelected ? template.accentColor.opacity(0.5) : .clear, radius: 10)
    }
}
