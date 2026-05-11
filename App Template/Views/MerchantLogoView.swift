import SwiftUI

// Shared decoded-image cache so scrolling through expenses doesn't re-decode
// the same logo bitmaps on every render cycle.
private final class LogoImageCache {
    static let shared = LogoImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 150
        cache.totalCostLimit = 30 * 1024 * 1024  // 30 MB
    }

    func image(for key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func store(_ image: UIImage, for key: String) { cache.setObject(image, forKey: key as NSString) }
}

/// Displays a merchant logo from logo.dev, falling back to a colored SF Symbol circle.
struct MerchantLogoView: View {
    let merchant: String
    let category: ExpenseCategory
    let size: CGFloat

    @State private var cachedImage: UIImage?
    @State private var loadFailed = false

    private var logoURL: URL? { LogoService.shared.logoURL(for: merchant) }

    var body: some View {
        ZStack {
            if let img = cachedImage {
                ZStack {
                    Color.white
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding(size * 0.10)
                }
                .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
                .transition(.opacity)
            } else if loadFailed || logoURL == nil {
                fallbackIcon
            } else {
                // Shimmer placeholder while loading
                RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                    .fill(Color(white: 0.92))
                    .task { await loadLogo() }
            }
        }
        .frame(width: size, height: size)
    }

    private func loadLogo() async {
        guard let url = logoURL else { loadFailed = true; return }
        let key = url.absoluteString

        if let cached = LogoImageCache.shared.image(for: key) {
            cachedImage = cached
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let img = UIImage(data: data) else { loadFailed = true; return }
            LogoImageCache.shared.store(img, for: key)
            cachedImage = img
        } catch {
            loadFailed = true
        }
    }

    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(category.color.opacity(0.15))
            Image(systemName: category.sfSymbol)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(category.color)
        }
    }
}
