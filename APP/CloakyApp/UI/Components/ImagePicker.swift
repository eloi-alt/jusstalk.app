import SwiftUI
import PhotosUI
import UIKit
import AVFoundation

final class CameraCoordinator: NSObject {
    static let shared = CameraCoordinator()
    
    var onImageCaptured: ((UIImage?) -> Void)?
    
    private override init() {
        super.init()
    }
    
    func presentCamera(from rootVC: UIViewController, onCapture: @escaping (UIImage?) -> Void) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            onCapture(nil)
            return
        }
        
        self.onImageCaptured = onCapture
        
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.modalPresentationStyle = .fullScreen
        
        rootVC.present(picker, animated: true)
    }
}

extension CameraCoordinator: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = info[.originalImage] as? UIImage
        picker.dismiss(animated: true) {
            self.onImageCaptured?(image)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            self.onImageCaptured?(nil)
        }
    }
}

struct CameraButton: View {
    @ObservedObject var viewModel: GalleryViewModel
    
    var body: some View {
        Button {
            presentCamera()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera")
                    .font(.title3)
                Text(String(localized: "gallery.take.photo", defaultValue: "Take Photo"))
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color(.secondarySystemBackground))
            .foregroundColor(.primary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .accessibilityLabel(String(localized: "gallery.take.photo", defaultValue: "Take Photo"))
    }
    
    private func presentCamera() {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch authStatus {
        case .authorized:
            presentCameraWithPermission()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.presentCameraWithPermission()
                    }
                }
            }
        case .denied, .restricted:
            return
        @unknown default:
            return
        }
    }
    
    private func presentCameraWithPermission() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        
        CameraCoordinator.shared.presentCamera(from: rootVC) { image in
            if let image = image {
                viewModel.handleSelectedImageWithTrialCheck(image)
            }
        }
    }
}

// MARK: - ImagePicker

struct ImagePicker: UIViewControllerRepresentable {
    
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    var onImageSelected: ((UIImage?) -> Void)?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        
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
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                parent.dismiss()
                return
            }
            
            provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                DispatchQueue.main.async {
                    let uiImage = image as? UIImage
                    self?.parent.selectedImage = uiImage
                    self?.parent.dismiss()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        self?.parent.onImageSelected?(uiImage)
                    }
                }
            }
        }
    }
}
