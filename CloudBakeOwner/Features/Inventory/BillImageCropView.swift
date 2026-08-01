import SwiftUI
import UIKit

struct BillImageCropView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onUseCrop: (UIImage) -> Void

    @State private var cropRect = BillImageCropper.defaultCropRect
    @State private var gestureStartCropRect: CGRect?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Keep only the bill inside the frame. This helps the iPhone read each line in order.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                GeometryReader { proxy in
                    let imageFrame = aspectFitFrame(imageSize: image.size, in: proxy.size)

                    ZStack {
                        Color.black

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: imageFrame.width, height: imageFrame.height)

                        cropOverlay(in: imageFrame)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
            }
            .background(CloudBakeScreenBackground())
            .navigationTitle("Crop Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        cropRect = BillImageCropper.defaultCropRect
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Crop") {
                        guard let croppedImage = BillImageCropper.crop(image, to: cropRect) else {
                            errorMessage = "The selected area could not be cropped. Reset the frame and try again."
                            return
                        }
                        onUseCrop(croppedImage)
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("inventory.purchaseBill.crop.use")
                }
            }
        }
    }

    @ViewBuilder
    private func cropOverlay(in imageFrame: CGRect) -> some View {
        let selection = displayRect(for: cropRect, in: imageFrame)

        ZStack {
            Path { path in
                path.addRect(imageFrame)
                path.addRect(selection)
            }
            .fill(.black.opacity(0.55), style: FillStyle(eoFill: true))

            Rectangle()
                .stroke(.white, lineWidth: 2)
                .frame(width: selection.width, height: selection.height)
                .position(x: selection.midX, y: selection.midY)
                .contentShape(Rectangle())
                .gesture(moveGesture(in: imageFrame))
                .accessibilityLabel("Bill crop area")

            cropHandle(.topLeft, selection: selection, imageFrame: imageFrame)
            cropHandle(.topRight, selection: selection, imageFrame: imageFrame)
            cropHandle(.bottomLeft, selection: selection, imageFrame: imageFrame)
            cropHandle(.bottomRight, selection: selection, imageFrame: imageFrame)
        }
        .accessibilityIdentifier("inventory.purchaseBill.crop.area")
    }

    private func cropHandle(
        _ corner: CropCorner,
        selection: CGRect,
        imageFrame: CGRect
    ) -> some View {
        Circle()
            .fill(.white)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
            .frame(width: 28, height: 28)
            .position(corner.point(in: selection))
            .contentShape(Rectangle().inset(by: -10))
            .gesture(resizeGesture(corner, in: imageFrame))
            .accessibilityLabel("\(corner.accessibilityName) crop handle")
    }

    private func moveGesture(in imageFrame: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = beginGestureIfNeeded()
                let dx = value.translation.width / imageFrame.width
                let dy = value.translation.height / imageFrame.height
                cropRect.origin.x = min(max(0, start.origin.x + dx), 1 - start.width)
                cropRect.origin.y = min(max(0, start.origin.y + dy), 1 - start.height)
            }
            .onEnded { _ in
                gestureStartCropRect = nil
            }
    }

    private func resizeGesture(_ corner: CropCorner, in imageFrame: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = beginGestureIfNeeded()
                cropRect = corner.resized(
                    start,
                    dx: value.translation.width / imageFrame.width,
                    dy: value.translation.height / imageFrame.height
                )
            }
            .onEnded { _ in
                gestureStartCropRect = nil
            }
    }

    private func beginGestureIfNeeded() -> CGRect {
        if let gestureStartCropRect {
            return gestureStartCropRect
        }
        gestureStartCropRect = cropRect
        return cropRect
    }

    private func aspectFitFrame(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (containerSize.width - size.width) / 2,
            y: (containerSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func displayRect(for normalizedRect: CGRect, in imageFrame: CGRect) -> CGRect {
        CGRect(
            x: imageFrame.minX + normalizedRect.minX * imageFrame.width,
            y: imageFrame.minY + normalizedRect.minY * imageFrame.height,
            width: normalizedRect.width * imageFrame.width,
            height: normalizedRect.height * imageFrame.height
        )
    }
}

enum BillImageCropper {
    static let defaultCropRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    static func crop(_ image: UIImage, to normalizedRect: CGRect) -> UIImage? {
        let normalizedImage = normalizeOrientation(of: image)
        guard let cgImage = normalizedImage.cgImage else {
            return nil
        }

        let unitBounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        let clampedRect = normalizedRect.standardized.intersection(unitBounds)
        guard clampedRect.width > 0, clampedRect.height > 0 else {
            return nil
        }

        let pixelMinX = (clampedRect.minX * CGFloat(cgImage.width)).rounded()
        let pixelMinY = (clampedRect.minY * CGFloat(cgImage.height)).rounded()
        let pixelMaxX = (clampedRect.maxX * CGFloat(cgImage.width)).rounded()
        let pixelMaxY = (clampedRect.maxY * CGFloat(cgImage.height)).rounded()
        let pixelRect = CGRect(
            x: pixelMinX,
            y: pixelMinY,
            width: pixelMaxX - pixelMinX,
            height: pixelMaxY - pixelMinY
        ).intersection(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        guard let croppedImage = cgImage.cropping(to: pixelRect) else {
            return nil
        }
        return UIImage(cgImage: croppedImage, scale: normalizedImage.scale, orientation: .up)
    }

    private static func normalizeOrientation(of image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else {
            return image
        }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}

private enum CropCorner {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    private static let minimumSize = 0.12

    var accessibilityName: String {
        switch self {
        case .topLeft: "Top left"
        case .topRight: "Top right"
        case .bottomLeft: "Bottom left"
        case .bottomRight: "Bottom right"
        }
    }

    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft: CGPoint(x: rect.minX, y: rect.minY)
        case .topRight: CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    func resized(_ rect: CGRect, dx: CGFloat, dy: CGFloat) -> CGRect {
        var minX = rect.minX
        var minY = rect.minY
        var maxX = rect.maxX
        var maxY = rect.maxY

        switch self {
        case .topLeft:
            minX = min(max(0, rect.minX + dx), maxX - Self.minimumSize)
            minY = min(max(0, rect.minY + dy), maxY - Self.minimumSize)
        case .topRight:
            maxX = max(min(1, rect.maxX + dx), minX + Self.minimumSize)
            minY = min(max(0, rect.minY + dy), maxY - Self.minimumSize)
        case .bottomLeft:
            minX = min(max(0, rect.minX + dx), maxX - Self.minimumSize)
            maxY = max(min(1, rect.maxY + dy), minY + Self.minimumSize)
        case .bottomRight:
            maxX = max(min(1, rect.maxX + dx), minX + Self.minimumSize)
            maxY = max(min(1, rect.maxY + dy), minY + Self.minimumSize)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
