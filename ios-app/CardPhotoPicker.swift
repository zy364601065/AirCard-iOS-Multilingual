import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Keeps the library alive beneath the crop editor so Back preserves its position.
struct CardPhotoPicker: UIViewControllerRepresentable {
    let onUse: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> Container {
        let container = Container()
        container.picker.delegate = context.coordinator
        return container
    }

    func updateUIViewController(_ container: Container, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIViewController(_ container: Container, coordinator: Coordinator) {
        coordinator.cancelLoading()
    }

    /// Own modal presentation separately from PHPicker's internal controller lifecycle.
    @MainActor
    final class Container: UIViewController {
        let picker: PHPickerViewController

        init() {
            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.filter = .images
            configuration.selectionLimit = 1
            configuration.preferredAssetRepresentationMode = .current
            picker = PHPickerViewController(configuration: configuration)
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidLoad() {
            super.viewDidLoad()
            addChild(picker)
            picker.view.frame = view.bounds
            picker.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(picker.view)
            picker.didMove(toParent: self)
        }
    }

    @MainActor
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: CardPhotoPicker
        private var loadID: UUID?
        private var progress: Progress?
        private var loadingView: UIView?
        private var finished = false

        init(parent: CardPhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !finished, loadID == nil, (picker.parent ?? picker).presentedViewController == nil else { return }
            guard let result = results.first else {
                finished = true
                parent.dismiss()
                return
            }

            // Allow choosing this photo again after Back without resetting the library.
            picker.deselectAssets(withIdentifiers: results.compactMap(\.assetIdentifier))
            let id = UUID()
            loadID = id
            showLoading(in: picker.view)
            progress = result.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self, weak picker] data, _ in
                let image = data.flatMap { ImageEngine.safeImageFromData($0, maxDimension: 2560) }
                DispatchQueue.main.async {
                    guard let self, let picker, self.loadID == id else { return }
                    self.cancelLoading()
                    if let image {
                        self.presentCrop(image, from: picker)
                    } else {
                        let alert = UIAlertController(
                            title: L("Couldn't Load Photo"),
                            message: L("Choose another image or try downloading the photo to your iPhone first."),
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: L("OK"), style: .default))
                        (picker.parent ?? picker).present(alert, animated: true)
                    }
                }
            }
        }

        func presentCrop(_ image: UIImage, from picker: PHPickerViewController) {
            var selectedImage: UIImage?
            let crop = CardPhotoCropView(image: image) { selectedImage = $0 }
            let host = CropHostingController(rootView: crop)
            // Keep the library view mounted as well as retaining its controller.
            host.modalPresentationStyle = .overFullScreen
            host.onDismiss = { [weak self] in
                guard let self, let selectedImage, !self.finished else { return }
                self.finished = true
                self.parent.onUse(selectedImage)
                self.parent.dismiss()
            }
            (picker.parent ?? picker).present(host, animated: true)
        }

        func cancelLoading() {
            loadID = nil
            progress?.cancel()
            progress = nil
            loadingView?.removeFromSuperview()
            loadingView = nil
        }

        private func showLoading(in view: UIView) {
            let overlay = UIView(frame: view.bounds)
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            overlay.backgroundColor = .systemBackground.withAlphaComponent(0.95)
            let spinner = UIActivityIndicatorView(style: .large)
            spinner.startAnimating()
            let label = UILabel()
            label.text = L("Loading Photo…")
            label.font = .preferredFont(forTextStyle: .body)
            label.adjustsFontForContentSizeCategory = true
            let cancel = UIButton(type: .system)
            cancel.setTitle(L("Cancel"), for: .normal)
            cancel.addAction(UIAction { [weak self] _ in self?.cancelLoading() }, for: .touchUpInside)
            let stack = UIStackView(arrangedSubviews: [spinner, label, cancel])
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = 16
            stack.translatesAutoresizingMaskIntoConstraints = false
            overlay.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
            ])
            view.addSubview(overlay)
            loadingView = overlay
        }
    }
}

private final class CropHostingController: UIHostingController<CardPhotoCropView> {
    var onDismiss: (() -> Void)?

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isBeingDismissed || presentingViewController == nil else { return }
        onDismiss?()
        onDismiss = nil
    }
}
