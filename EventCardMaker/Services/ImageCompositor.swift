import UIKit
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

class ImageCompositor {
    private let context = CIContext()
    
    // カードサイズ（プロ野球カード比率 63:88 → 2.5x scale）
    static let cardSize = CGSize(width: 630, height: 880)
    
    /// 人物画像を背景に合成し、色味をなじませる
    func compose(person: UIImage, template: CardTemplate, name: String) -> UIImage? {
        let size = Self.cardSize
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            
            // 1. 背景描画
            drawBackground(in: ctx, rect: rect, template: template)
            
            // 2. 人物描画（色味調整済み）
            if let adjusted = adjustPersonColors(person, template: template) {
                let personRect = calculatePersonRect(imageSize: adjusted.size, cardSize: size)
                adjusted.draw(in: personRect)
            }
            
            // 3. カードフレーム描画
            drawCardFrame(in: ctx, rect: rect, template: template)
            
            // 4. 名前描画
            drawName(name, in: ctx, rect: rect, template: template)
        }
    }
    
    // MARK: - 背景
    
    private func drawBackground(in ctx: UIGraphicsImageRendererContext, rect: CGRect, template: CardTemplate) {
        // グラデーション背景
        let colors = [
            template.backgroundColor.cgColor ?? UIColor.blue.cgColor,
            template.backgroundColor.darker(by: 0.3).cgColor
        ]
        
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: [0.0, 1.0]
        )!
        
        ctx.cgContext.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: 0),
            end: CGPoint(x: rect.midX, y: rect.maxY),
            options: []
        )
    }
    
    // MARK: - 人物色味調整
    
    private func adjustPersonColors(_ image: UIImage, template: CardTemplate) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return image }
        
        // 色温度調整（背景に合わせてなじませ）
        let tempFilter = CIFilter.temperatureAndTint()
        tempFilter.inputImage = ciImage
        tempFilter.neutral = CIVector(x: 6500, y: 0) // デフォルト色温度
        
        guard let tempOutput = tempFilter.outputImage else { return image }
        
        // コントラスト・明るさ微調整
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = tempOutput
        colorFilter.saturation = 1.1  // 少し鮮やかに
        colorFilter.contrast = 1.05   // 少しコントラスト上げ
        colorFilter.brightness = 0.02 // 少し明るく
        
        guard let output = colorFilter.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else { return image }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - 人物配置計算
    
    private func calculatePersonRect(imageSize: CGSize, cardSize: CGSize) -> CGRect {
        let targetHeight = cardSize.height * 0.7
        let scale = targetHeight / imageSize.height
        let targetWidth = imageSize.width * scale
        
        return CGRect(
            x: (cardSize.width - targetWidth) / 2,
            y: cardSize.height * 0.08,
            width: targetWidth,
            height: targetHeight
        )
    }
    
    // MARK: - カードフレーム
    
    private func drawCardFrame(in ctx: UIGraphicsImageRendererContext, rect: CGRect, template: CardTemplate) {
        let cgCtx = ctx.cgContext
        
        // 外枠
        cgCtx.setStrokeColor(template.accentColor.cgColor ?? UIColor.yellow.cgColor)
        cgCtx.setLineWidth(8)
        cgCtx.stroke(rect.insetBy(dx: 12, dy: 12))
        
        // 内枠
        cgCtx.setLineWidth(2)
        cgCtx.stroke(rect.insetBy(dx: 20, dy: 20))
        
        // 下部の名前バー背景
        let barRect = CGRect(x: 0, y: rect.height * 0.82, width: rect.width, height: rect.height * 0.18)
        cgCtx.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
        cgCtx.fill(barRect)
    }
    
    // MARK: - 名前描画
    
    private func drawName(_ name: String, in ctx: UIGraphicsImageRendererContext, rect: CGRect, template: CardTemplate) {
        let fontSize: CGFloat = 48
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .heavy),
            .foregroundColor: UIColor.white,
            .kern: 4.0
        ]
        
        let text = name.uppercased()
        let textSize = text.size(withAttributes: attributes)
        let textRect = CGRect(
            x: (rect.width - textSize.width) / 2,
            y: rect.height * 0.88 - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: attributes)
    }
}

// MARK: - Color Extensions

extension UIColor {
    func darker(by percentage: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s, brightness: max(b - percentage, 0), alpha: a)
    }
}

extension Color {
    var cgColor: CGColor? {
        UIColor(self).cgColor
    }
    
    func darker(by percentage: CGFloat) -> UIColor {
        UIColor(self).darker(by: percentage)
    }
}
