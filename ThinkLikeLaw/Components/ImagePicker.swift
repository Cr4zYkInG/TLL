import SwiftUI
import PhotosUI

/**
 * ImagePicker — A standard wrapper for PHPickerViewController
 */
#if os(iOS)
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let provider = results.first?.itemProvider else { return }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                    }
                }
            }
        }
    }
}
#else
// Temporary empty wrapper for macOS
struct ImagePicker: View {
    var image: Binding<Image?>
    
    init(image: Binding<Image?>? = nil) {
        self.image = image ?? .constant(nil)
    }

    // A secondary init explicitly typed as Any to catch completely untyped `nil` closures
    init(image: Binding<Any?>) {
        self.image = .constant(nil)
    }
    
    var body: some View {
        Text("Image Picker not supported on Mac.")
    }
}
#endif
