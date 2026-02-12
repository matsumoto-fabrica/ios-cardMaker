import SwiftUI

struct CardData {
    var name: String = ""
    var templateIndex: Int = 0
    var capturedImage: UIImage?
    var segmentedImage: UIImage?
    var compositeImage: UIImage?
}

struct CardTemplate: Identifiable {
    let id: Int
    let name: String
    let backgroundColor: Color
    let accentColor: Color
    let backgroundImageName: String?
    
    static let samples: [CardTemplate] = [
        CardTemplate(id: 0, name: "Classic Blue", backgroundColor: .blue, accentColor: .yellow, backgroundImageName: nil),
        CardTemplate(id: 1, name: "Fire Red", backgroundColor: .red, accentColor: .white, backgroundImageName: nil),
        CardTemplate(id: 2, name: "Gold Elite", backgroundColor: Color(red: 0.2, green: 0.15, blue: 0.05), accentColor: .yellow, backgroundImageName: nil),
        CardTemplate(id: 3, name: "Emerald", backgroundColor: .green, accentColor: .white, backgroundImageName: nil),
    ]
}
