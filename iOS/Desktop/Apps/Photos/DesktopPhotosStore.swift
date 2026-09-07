import Foundation
import Photos
import UIKit

public enum DesktopPhotosFilter: String, CaseIterable, Identifiable {
    case library = "Library"
    case favorites = "Favorites"
    case recent = "Recent"

    public var id: String { rawValue }
    public var icon: String {
        switch self {
        case .library: return "photo.stack.fill"
        case .favorites: return "heart.fill"
        case .recent: return "clock.fill"
        }
    }
}

@MainActor
public final class DesktopPhotosStore: ObservableObject {
    public static let shared = DesktopPhotosStore()

    @Published public private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published public private(set) var assets: [PHAsset] = []
    @Published public var selectedFilter: DesktopPhotosFilter = .library {
        didSet { reloadGrantedAssets() }
    }
    @Published public var selectedAssetID: String? = nil
    @Published public var isDeleting: Bool = false
    @Published public var statusMessage: String? = nil

    public var selectedAsset: PHAsset? {
        guard let id = selectedAssetID else { return nil }
        return assets.first(where: { $0.localIdentifier == id })
    }

    private init() {
        self.authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    public func start() async {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = current
        if current == .notDetermined {
            authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        reloadGrantedAssets()
    }

    public func reloadGrantedAssets() {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            assets = []
            selectedAssetID = nil
            return
        }

        let options = PHFetchOptions()
        options.fetchLimit = 120
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if selectedFilter == .favorites {
            options.predicate = NSPredicate(format: "isFavorite == YES")
        }

        let result = PHAsset.fetchAssets(with: .image, options: options)
        var nextAssets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in nextAssets.append(asset) }
        self.assets = nextAssets

        if let id = selectedAssetID, !nextAssets.contains(where: { $0.localIdentifier == id }) {
            selectedAssetID = nil
        }
    }

    public func select(assetID: String?) {
        self.selectedAssetID = assetID
    }

    public func selectIndex(_ index: Int) {
        guard index >= 0, index < assets.count else { return }
        self.selectedAssetID = assets[index].localIdentifier
    }

    public func deleteSelectedAsset() {
        guard let asset = selectedAsset else { return }
        isDeleting = true
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        } completionHandler: { [weak self] success, error in
            Task { @MainActor in
                guard let self = self else { return }
                self.isDeleting = false
                if success {
                    self.selectedAssetID = nil
                    self.reloadGrantedAssets()
                } else if let error {
                    self.statusMessage = "Delete failed: \(error.localizedDescription)"
                }
            }
        }
    }

    public func toggleFavoriteSelectedAsset() {
        guard let asset = selectedAsset else { return }
        let nextState = !asset.isFavorite
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = nextState
        } completionHandler: { [weak self] success, _ in
            Task { @MainActor in
                guard let self = self, success else { return }
                self.reloadGrantedAssets()
            }
        }
    }
}
