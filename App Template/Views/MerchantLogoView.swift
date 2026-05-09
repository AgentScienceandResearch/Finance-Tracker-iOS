import SwiftUI

/// Displays a merchant logo from logo.dev, falling back to a colored SF Symbol circle.
struct MerchantLogoView: View {
    let merchant: String
    let category: ExpenseCategory
    let size: CGFloat

    private var logoURL: URL? { LogoService.shared.logoURL(for: merchant) }

    var body: some View {
        ZStack {
            if let url = logoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
                            .transition(.opacity)
                    case .failure, .empty:
                        fallbackIcon
                    @unknown default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: size, height: size)
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
