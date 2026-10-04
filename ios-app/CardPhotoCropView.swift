import SwiftUI
import UIKit

/// Stages photo edits until Use Photo is tapped. Back dismisses only this editor
/// so its presenting library can retain its position. Preview and export share
/// the same scroll-view viewport, including the image's displayed orientation.
struct CardPhotoCropView: View {
    let image: UIImage
    let onUse: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var editor = CardPhotoCropState()

    private let cardAspect: CGFloat = 1536.0 / 969.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                GeometryReader { geometry in
                    let width = max(0, min(geometry.size.width, geometry.size.height * cardAspect))
                    CardPhotoCropCanvas(image: image, editor: editor)
                        .frame(width: width, height: width / cardAspect)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(.secondary.opacity(0.4), lineWidth: 1)
                                .allowsHitTesting(false)
                        }
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Photo crop")
                        .accessibilityHint("Move the photo to choose the part shown on your card. Use the Zoom slider to resize it.")
                        .accessibilityAction(named: Text("Move photo left")) { editor.pan(x: 0.1, y: 0) }
                        .accessibilityAction(named: Text("Move photo right")) { editor.pan(x: -0.1, y: 0) }
                        .accessibilityAction(named: Text("Move photo up")) { editor.pan(x: 0, y: 0.1) }
                        .accessibilityAction(named: Text("Move photo down")) { editor.pan(x: 0, y: -0.1) }
                }

                Text("Drag to position. Pinch to zoom.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Slider(value: Binding(get: { editor.zoom }, set: { editor.setZoom($0) }), in: 1...5) {
                        Text("Zoom")
                    }
                    .accessibilityValue(L("%lld percent", Int((editor.zoom * 100).rounded())))

                    Text("\(editor.zoom, specifier: "%.1f")×")
                        .font(.subheadline.monospacedDigit())
                        .fixedSize()

                    Button("Reset") { editor.reset() }
                        .fixedSize()
                }
            }
            .padding()
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Adjust Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Photo") {
                        guard let cropped = editor.canvas?.croppedImage() else { return }
                        onUse(cropped)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!editor.isReady)
                }
            }
        }
    }
}

@MainActor
final class CardPhotoCropState: ObservableObject {
    @Published var zoom: Double = 1
    @Published var isReady = false
    weak var canvas: CardPhotoCropScrollView?

    func setZoom(_ value: Double) {
        zoom = value
        canvas?.setRelativeZoom(CGFloat(value))
    }

    func reset() {
        zoom = 1
        canvas?.resetCrop()
    }

    func pan(x: CGFloat, y: CGFloat) {
        canvas?.pan(x: x, y: y)
    }
}

private struct CardPhotoCropCanvas: UIViewRepresentable {
    let image: UIImage
    let editor: CardPhotoCropState

    func makeUIView(context: Context) -> CardPhotoCropScrollView {
        let view = CardPhotoCropScrollView(image: image, editor: editor)
        editor.canvas = view
        return view
    }

    func updateUIView(_ uiView: CardPhotoCropScrollView, context: Context) {}
}

@MainActor
final class CardPhotoCropScrollView: UIView, UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    private let imageView: UIImageView
    private let image: UIImage
    private weak var editor: CardPhotoCropState?
    private var previousSize = CGSize.zero
    private var adjustingLayout = false

    init(image: UIImage, editor: CardPhotoCropState) {
        self.image = image
        self.imageView = UIImageView(image: image)
        self.editor = editor
        super.init(frame: .zero)

        clipsToBounds = true
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.bounces = false
        scrollView.bouncesZoom = false
        scrollView.decelerationRate = .fast
        scrollView.clipsToBounds = true
        imageView.contentMode = .scaleToFill
        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.addSubview(imageView)
        scrollView.contentSize = image.size
        addSubview(scrollView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0,
              image.size.width > 0, image.size.height > 0,
              bounds.size != previousSize else { return }

        // Retain the selected image-space center across rotation or sheet resizing.
        let center = previousSize == .zero
            ? CGPoint(x: image.size.width / 2, y: image.size.height / 2)
            : visibleImageCenter
        let relativeZoom = previousSize == .zero
            ? CGFloat(editor?.zoom ?? 1)
            : scrollView.zoomScale / scrollView.minimumZoomScale

        adjustingLayout = true
        scrollView.frame = bounds
        let minimum = max(bounds.width / image.size.width, bounds.height / image.size.height)
        // Widen both bounds before assigning the new limits, avoiding an interim clamp.
        scrollView.maximumZoomScale = max(scrollView.maximumZoomScale, minimum * 5)
        scrollView.minimumZoomScale = min(scrollView.minimumZoomScale, minimum)
        scrollView.setZoomScale(minimum * min(5, max(1, relativeZoom)), animated: false)
        scrollView.minimumZoomScale = minimum
        scrollView.maximumZoomScale = minimum * 5
        centerImage(on: center)
        previousSize = bounds.size
        adjustingLayout = false

        if editor?.isReady == false {
            // Layout can run during a SwiftUI update; publish after that update ends.
            DispatchQueue.main.async { [weak self] in self?.editor?.isReady = true }
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard !adjustingLayout, previousSize != .zero else { return }
        let zoom = Double(scrollView.zoomScale / scrollView.minimumZoomScale)
        if abs((editor?.zoom ?? 1) - zoom) > 0.001 { editor?.zoom = zoom }
    }

    private var visibleImageCenter: CGPoint {
        scrollView.convert(CGPoint(x: scrollView.bounds.midX, y: scrollView.bounds.midY), to: imageView)
    }

    func setRelativeZoom(_ zoom: CGFloat) {
        guard previousSize != .zero else { return }
        let center = visibleImageCenter
        scrollView.setZoomScale(scrollView.minimumZoomScale * min(5, max(1, zoom)), animated: false)
        centerImage(on: center)
    }

    func resetCrop() {
        guard previousSize != .zero else { return }
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
        centerImage(on: CGPoint(x: image.size.width / 2, y: image.size.height / 2))
    }

    private func centerImage(on center: CGPoint) {
        let scale = scrollView.zoomScale
        setClampedOffset(CGPoint(x: center.x * scale - bounds.width / 2,
                                y: center.y * scale - bounds.height / 2))
    }

    private func setClampedOffset(_ point: CGPoint) {
        scrollView.contentOffset = CGPoint(
            x: min(max(0, point.x), max(0, scrollView.contentSize.width - bounds.width)),
            y: min(max(0, point.y), max(0, scrollView.contentSize.height - bounds.height))
        )
    }

    func pan(x: CGFloat, y: CGFloat) {
        setClampedOffset(CGPoint(x: scrollView.contentOffset.x + bounds.width * x,
                                y: scrollView.contentOffset.y + bounds.height * y))
    }

    func croppedImage() -> UIImage? {
        guard previousSize != .zero else { return nil }
        // Conversion includes the live pinch scale and pan offset. Drawing UIImage
        // (instead of cropping its raw CGImage) honors EXIF rotation and mirroring.
        let crop = scrollView.convert(scrollView.bounds, to: imageView)
        guard crop.width > 0, crop.height > 0 else { return nil }
        let output = CGSize(width: 1536, height: 969)
        let scaleX = output.width / crop.width
        let scaleY = output.height / crop.height
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: output, format: format).image { context in
            context.cgContext.interpolationQuality = .high
            image.draw(in: CGRect(x: -crop.minX * scaleX, y: -crop.minY * scaleY,
                                  width: image.size.width * scaleX,
                                  height: image.size.height * scaleY))
        }
    }
}
