import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import PDFKit

// Mirrors the FT design tokens from MainTabView (which are file-private there)
private enum FT {
    static let green   = Color(red: 0.18, green: 0.72, blue: 0.34)
    static let bg      = Color(red: 0.961, green: 0.961, blue: 0.973)
    static let card    = Color.white
    static let t1      = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let t2      = Color(red: 0.50, green: 0.50, blue: 0.56)
    static let t3      = Color(red: 0.72, green: 0.72, blue: 0.76)
}

struct ImportExpenseSheet: View {
    @ObservedObject var financeManager: FinanceManager
    @ObservedObject var aiManager: FinanceAIManager
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var drafts: [SelectableDraft] = []
    @State private var phase: ImportPhase = .pick
    @State private var showFilePicker = false

    private enum ImportPhase { case pick, extracting, review }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .pick:    pickView
                case .extracting: extractingView
                case .review:  reviewView
                }
            }
            .background(FT.bg.ignoresSafeArea())
            .navigationTitle("Import Expenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FT.t2)
                }
                if phase == .review {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save Selected") { saveSelected() }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(selectedCount > 0 ? FT.green : FT.t3)
                            .disabled(selectedCount == 0)
                    }
                }
            }
            .tint(FT.green)
        }
    }

    // MARK: - Pick phase

    private var pickView: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(FT.green.opacity(0.12)).frame(width: 80, height: 80)
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(FT.green)
                }

                VStack(spacing: 6) {
                    Text("Import a Screenshot or Photo")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(FT.t1)
                    Text("AI will extract all transactions\nfrom bank statements, receipts,\nor expense screenshots.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FT.t2)
                        .multilineTextAlignment(.center)
                }
            }

            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(selectedImage == nil ? "Choose Photo" : "Change Photo",
                          systemImage: "photo.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(FT.green)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    showFilePicker = true
                } label: {
                    Label(selectedImage == nil ? "Choose File" : "Change File",
                          systemImage: "doc.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FT.green)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(FT.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                if selectedImage != nil {
                    Button {
                        Task { await extract() }
                    } label: {
                        Label("Extract Transactions", systemImage: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(FT.green)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            if let err = aiManager.errorMessage {
                Text(err)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .onChange(of: pickerItem) { _, item in
            Task {
                guard let item,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let img = UIImage(data: data) else { return }
                selectedImage = img
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image, .pdf, .jpeg, .png, .heic, .tiff],
            allowsMultipleSelection: false
        ) { result in
            guard let url = try? result.get().first else { return }
            Task { await loadFile(url: url) }
        }
    }

    private func loadFile(url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { return }

        if url.pathExtension.lowercased() == "pdf",
           let doc = PDFDocument(data: data),
           let page = doc.page(at: 0) {
            let bounds = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2
            let renderer = UIGraphicsImageRenderer(
                size: CGSize(width: bounds.width * scale, height: bounds.height * scale)
            )
            selectedImage = renderer.image { ctx in
                ctx.cgContext.setFillColor(UIColor.white.cgColor)
                ctx.cgContext.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))
                ctx.cgContext.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
        } else if let img = UIImage(data: data) {
            selectedImage = img
        }
    }

    // MARK: - Extracting phase

    private var extractingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.6)
                .tint(FT.green)
            Text("Analyzing image…")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(FT.t2)
            Spacer()
        }
    }

    // MARK: - Review phase

    private var reviewView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                if drafts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundStyle(FT.t3)
                        Text("No transactions found")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(FT.t1)
                        Text("Try a clearer image or one that shows financial data more clearly.")
                            .font(.system(size: 13))
                            .foregroundStyle(FT.t2)
                            .multilineTextAlignment(.center)
                        Button("Try Another Image") {
                            selectedImage = nil
                            drafts = []
                            phase = .pick
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FT.green)
                        .padding(.top, 8)
                    }
                    .padding(40)
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            Text("\(drafts.count) transaction\(drafts.count == 1 ? "" : "s") found")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(FT.t2)
                            Spacer()
                            Button(selectedCount == drafts.count ? "Deselect All" : "Select All") {
                                let all = selectedCount == drafts.count
                                for i in drafts.indices { drafts[i].selected = !all }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FT.green)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)

                        ForEach($drafts) { $item in
                            DraftRow(item: $item)
                                .padding(.horizontal, 18)
                                .padding(.bottom, 10)
                        }

                        Spacer(minLength: 24)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private var selectedCount: Int { drafts.filter(\.selected).count }

    private func extract() async {
        guard let image = selectedImage else { return }
        phase = .extracting

        let compressed = image.resizedForUpload().jpegData(compressionQuality: 0.7) ?? Data()
        selectedImage = nil  // release the full-resolution bitmap before the network call
        let base64 = compressed.base64EncodedString()
        let results = await aiManager.parseImage(imageBase64: base64, mimeType: "image/jpeg")

        drafts = results.map { SelectableDraft(draft: $0) }
        phase = .review
    }

    private func saveSelected() {
        for item in drafts where item.selected {
            financeManager.applyReceiptDraft(item.draft)
        }
        dismiss()
    }
}

// MARK: - UIImage resize helper

private extension UIImage {
    /// Scales down to fit within 1536px on the longest side before upload.
    /// Claude Vision works well at this resolution and it stays under Railway's body limit.
    func resizedForUpload(maxDimension: CGFloat = 1536) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

// MARK: - Supporting types

private struct SelectableDraft: Identifiable {
    let id = UUID()
    let draft: ReceiptDraft
    var selected: Bool = true
}

private struct DraftRow: View {
    @Binding var item: SelectableDraft

    var body: some View {
        Button { item.selected.toggle() } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(item.selected ? FT.green : FT.t3.opacity(0.25))
                        .frame(width: 24, height: 24)
                    if item.selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                MerchantLogoView(
                    merchant: item.draft.merchant,
                    category: item.draft.category,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.draft.merchant)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FT.t1)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(item.draft.category.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(item.draft.category.color)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(item.draft.category.color.opacity(0.12))
                            .clipShape(Capsule())
                        Text(item.draft.purchaseDate.formattedDate)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(FT.t3)
                    }
                }

                Spacer()

                Text(CurrencyFormatting.shared.string(for: item.draft.amount))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(item.draft.amount < 0 ? FT.green : FT.t1)
            }
            .padding(14)
            .background(FT.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(item.selected ? FT.green.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
