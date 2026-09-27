//
//  ImageProcessor.swift
//  SpeakIT
//
//  Client-side image pre-processing pipeline for user profile avatars:
//  1. Square aspect-fill center cropping
//  2. Downsampling to 512x512 px Retina resolution
//  3. JPEG compression (0.80 quality) to produce ~80-180 KB payload
//

import UIKit

enum ImageProcessor {
    
    /// Prepares raw selected photo data for optimal avatar storage and networking.
    /// - Parameters:
    ///   - rawData: Raw image data from PhotosPicker or camera.
    ///   - targetDimension: The target square dimension in pixels (default 512px).
    ///   - compressionQuality: JPEG compression factor (0.75 - 0.82 standard, default 0.80).
    /// - Returns: Compressed JPEG Data ready for multipart upload.
    static func processAvatar(
        from rawData: Data,
        targetDimension: CGFloat = 512,
        compressionQuality: CGFloat = 0.80
    ) -> Data? {
        guard let sourceImage = UIImage(data: rawData) else { return nil }
        
        // 1. Center crop to 1:1 square
        let cropped = cropToSquare(image: sourceImage)
        
        // 2. Downsample to target dimension
        let resized = resize(image: cropped, targetSize: CGSize(width: targetDimension, height: targetDimension))
        
        // 3. Compress to JPEG
        return resized.jpegData(compressionQuality: compressionQuality)
    }
    
    /// Crops a UIImage to a centered 1:1 square aspect ratio respecting image orientation.
    static func cropToSquare(image: UIImage) -> UIImage {
        let originalWidth = image.size.width
        let originalHeight = image.size.height
        let edge = min(originalWidth, originalHeight)
        
        let x = (originalWidth - edge) / 2.0
        let y = (originalHeight - edge) / 2.0
        let cropRect = CGRect(x: x, y: y, width: edge, height: edge)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        
        let renderer = UIGraphicsImageRenderer(size: cropRect.size, format: format)
        return renderer.image { _ in
            image.draw(at: CGPoint(x: -cropRect.origin.x, y: -cropRect.origin.y))
        }
    }
    
    /// Resizes an image to the exact target size using high-quality downsampling.
    static func resize(image: UIImage, targetSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.preferredRange = .standard
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
