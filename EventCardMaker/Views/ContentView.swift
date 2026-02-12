import SwiftUI

enum AppStep: Int, CaseIterable {
    case camera = 0
    case nameInput = 1
    case templateSelect = 2
    case preview = 3
    case complete = 4
}

struct ContentView: View {
    @State private var step: AppStep = .camera
    @State private var cardData = CardData()
    @StateObject private var cameraService = CameraService()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                switch step {
                case .camera:
                    CameraView(cameraService: cameraService, cardData: $cardData) {
                        step = .nameInput
                    }
                case .nameInput:
                    NameInputView(cardData: $cardData) {
                        step = .templateSelect
                    }
                case .templateSelect:
                    TemplateSelectView(cardData: $cardData) {
                        step = .preview
                    }
                case .preview:
                    CardPreviewView(cardData: $cardData) {
                        step = .complete
                    }
                case .complete:
                    CompleteView {
                        cardData = CardData()
                        step = .camera
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    ContentView()
}
