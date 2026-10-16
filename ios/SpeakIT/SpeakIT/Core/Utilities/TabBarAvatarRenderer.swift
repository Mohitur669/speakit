//
//  TabBarAvatarRenderer.swift
//  SpeakIT
//
//  Utility to render circular profile photo and monogram avatar icons
//  directly into the iOS Bottom Tab Bar (UITabBarItem).
//

import UIKit

enum TabBarAvatarRenderer {
    static let iconSize: CGFloat = 25.0
    
    /// Brand primary color (#6366F1)
    private static let primaryColor = UIColor(red: 0.388, green: 0.400, blue: 0.945, alpha: 1.0)
    
    /// High-speed in-memory cache for rendered circular tab avatars
    private static let cache = NSCache<NSString, UIImage>()
    
    /// Clears the rendered tab bar avatar cache (e.g., when the user logs out or updates profile photo).
    static func clearCache() {
        cache.removeAllObjects()
    }
    
    /// Renders a circular profile image for the tab bar item.
    /// - Parameters:
    ///   - image: Optional custom profile UIImage.
    ///   - initials: User's initials string if custom photo is absent.
    ///   - isSelected: Whether the profile tab is currently active.
    ///   - customKey: Optional cache key identifier (e.g. avatar URL).
    /// - Returns: High-resolution circular UIImage configured with `.alwaysOriginal` rendering.
    static func render(
        image: UIImage?,
        initials: String,
        isSelected: Bool,
        customKey: String? = nil
    ) -> UIImage {
        let key: NSString
        if let customKey = customKey, !customKey.isEmpty {
            key = "\(customKey):\(isSelected ? "sel" : "unsel")" as NSString
        } else if let photo = image {
            key = "img_\(photo.hash)_\(Int(photo.size.width))x\(Int(photo.size.height)):\(isSelected ? "sel" : "unsel")" as NSString
        } else {
            key = "mono_\(initials):\(isSelected ? "sel" : "unsel")" as NSString
        }
        
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let size = CGSize(width: iconSize, height: iconSize)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { context in
            let cgContext = context.cgContext
            let bounds = CGRect(origin: .zero, size: size)
            
            let ringWidth: CGFloat = isSelected ? 1.8 : 0.8
            let ringColor: UIColor = isSelected ? primaryColor : UIColor.separator.withAlphaComponent(0.4)
            
            // Inset bounds so stroke stays completely within icon frame
            let strokeInset = ringWidth / 2.0
            let circleRect = bounds.insetBy(dx: strokeInset, dy: strokeInset)
            
            if let photo = image {
                // 1. Custom User Photo
                cgContext.saveGState()
                let clipPath = UIBezierPath(ovalIn: circleRect)
                clipPath.addClip()
                
                // Aspect fill source photo into circular rect
                let aspect = photo.size.width / max(1.0, photo.size.height)
                var drawRect = circleRect
                if aspect > 1.0 {
                    let w = circleRect.height * aspect
                    drawRect = CGRect(
                        x: circleRect.midX - w / 2.0,
                        y: circleRect.minY,
                        width: w,
                        height: circleRect.height
                    )
                } else {
                    let h = circleRect.width / max(0.01, aspect)
                    drawRect = CGRect(
                        x: circleRect.minX,
                        y: circleRect.midY - h / 2.0,
                        width: circleRect.width,
                        height: h
                    )
                }
                photo.draw(in: drawRect)
                cgContext.restoreGState()
                
                // Draw border ring
                let ringPath = UIBezierPath(ovalIn: circleRect)
                ringPath.lineWidth = ringWidth
                ringColor.setStroke()
                ringPath.stroke()
                
            } else if !initials.isEmpty {
                // 2. Deterministic Monogram Initials
                let bgPath = UIBezierPath(ovalIn: circleRect)
                let bgColor = isSelected ? primaryColor : primaryColor.withAlphaComponent(0.85)
                bgColor.setFill()
                bgPath.fill()
                
                if isSelected {
                    let ringPath = UIBezierPath(ovalIn: circleRect)
                    ringPath.lineWidth = ringWidth
                    primaryColor.setStroke()
                    ringPath.stroke()
                }
                
                // Draw initials centered
                let text = String(initials.prefix(2)).uppercased()
                let fontSize: CGFloat = text.count > 1 ? 9.5 : 11.0
                let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.white
                ]
                let textSize = text.size(withAttributes: attributes)
                let textRect = CGRect(
                    x: (iconSize - textSize.width) / 2.0,
                    y: (iconSize - textSize.height) / 2.0,
                    width: textSize.width,
                    height: textSize.height
                )
                text.draw(in: textRect, withAttributes: attributes)
                
            } else {
                // 3. System silhouette fallback
                let bgPath = UIBezierPath(ovalIn: circleRect)
                UIColor.systemGray5.setFill()
                bgPath.fill()
                
                if let systemIcon = UIImage(systemName: "person.fill") {
                    let iconRect = circleRect.insetBy(dx: 4.5, dy: 4.5)
                    UIColor.systemGray.setFill()
                    systemIcon.draw(in: iconRect)
                }
            }
        }
        
        let finalImage = rendered.withRenderingMode(.alwaysOriginal)
        cache.setObject(finalImage, forKey: key)
        return finalImage
    }
}
