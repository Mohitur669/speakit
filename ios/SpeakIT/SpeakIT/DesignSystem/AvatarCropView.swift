//
//  AvatarCropView.swift
//  SpeakIT
//
//  Interactive circular avatar cropper:
//  - Aspect-Fill base sizing ensuring zero white borders / margins
//  - Real-time pinch-to-zoom (1.0x to 4.0x) and pan/drag positioning
//  - Boundary clamping preventing image from leaving circular viewport
//  - Dimmed inverted circular mask with crisp boundary guide
//  - High-performance 512x512 px Retina square export with JPEG compression
//

import SwiftUI

struct AvatarCropView: View {
    let sourceImage: UIImage
    var onCropped: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    
    // Zoom and Pan State
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let cropDiameter: CGFloat = 280
    
    // Base Aspect-Fill dimensions so the image always completely covers the circular viewport
    private var baseImageSize: CGSize {
        let imgW = sourceImage.size.width
        let imgH = sourceImage.size.height
        guard imgW > 0 && imgH > 0 else {
            return CGSize(width: cropDiameter, height: cropDiameter)
        }
        let aspect = imgW / imgH
        if aspect >= 1.0 {
            // Landscape or square: height matches cropDiameter, width is scaled up
            let h = cropDiameter
            let w = h * aspect
            return CGSize(width: w, height: h)
        } else {
            // Portrait: width matches cropDiameter, height is scaled up
            let w = cropDiameter
            let h = w / aspect
            return CGSize(width: w, height: h)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // 1. Interactive Image Canvas (Aspect-Fill centered over crop circle)
                Image(uiImage: sourceImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: baseImageSize.width * scale, height: baseImageSize.height * scale)
                    .offset(offset)
                    .frame(width: cropDiameter, height: cropDiameter)
                
                // 2. Inverted Circular Mask (Dimmed exterior, clear circular center)
                Color.black.opacity(0.65)
                    .mask(
                        Rectangle()
                            .overlay(
                                Circle()
                                    .frame(width: cropDiameter, height: cropDiameter)
                                    .blendMode(.destinationOut)
                            )
                    )
                    .compositingGroup()
                    .allowsHitTesting(false)
                
                // 3. Circular Guide Ring
                Circle()
                    .stroke(Color.white.opacity(0.85), lineWidth: 2)
                    .frame(width: cropDiameter, height: cropDiameter)
                    .allowsHitTesting(false)
                
                // 4. User Guidance Footer
                VStack {
                    Spacer()
                    Text("Pinch to zoom, drag to position")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                        .padding(.bottom, 28)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { val in
                            let newScale = max(1.0, min(4.0, lastScale * val))
                            scale = newScale
                            offset = clampOffset(offset, forScale: newScale)
                        }
                        .onEnded { _ in
                            lastScale = scale
                            lastOffset = offset
                        },
                    DragGesture()
                        .onChanged { val in
                            let proposed = CGSize(
                                width: lastOffset.width + val.translation.width,
                                height: lastOffset.height + val.translation.height
                            )
                            offset = clampOffset(proposed, forScale: scale)
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
            )
            .navigationTitle("Move and Scale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Choose") {
                        if let data = renderCroppedAvatar() {
                            onCropped(data)
                            dismiss()
                        }
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.speakitPrimary)
                }
            }
        }
    }
    
    // MARK: - Boundary Clamping (Prevents white margins from ever showing)
    private func clampOffset(_ proposed: CGSize, forScale s: CGFloat) -> CGSize {
        let currentWidth = baseImageSize.width * s
        let currentHeight = baseImageSize.height * s
        
        let maxOffsetX = max(0, (currentWidth - cropDiameter) / 2.0)
        let maxOffsetY = max(0, (currentHeight - cropDiameter) / 2.0)
        
        let clampedX = min(maxOffsetX, max(-maxOffsetX, proposed.width))
        let clampedY = min(maxOffsetY, max(-maxOffsetY, proposed.height))
        
        return CGSize(width: clampedX, height: clampedY)
    }
    
    // MARK: - Crop & Downsample Renderer
    private func renderCroppedAvatar() -> Data? {
        let outputDimension: CGFloat = 512
        let targetSize = CGSize(width: outputDimension, height: outputDimension)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.preferredRange = .standard
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        
        let renderedImage = renderer.image { _ in
            let factor = outputDimension / cropDiameter
            let drawWidth = baseImageSize.width * scale * factor
            let drawHeight = baseImageSize.height * scale * factor
            
            let drawX = (outputDimension - drawWidth) / 2.0 + (offset.width * factor)
            let drawY = (outputDimension - drawHeight) / 2.0 + (offset.height * factor)
            
            sourceImage.draw(in: CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight))
        }
        
        return renderedImage.jpegData(compressionQuality: 0.80)
    }
}
