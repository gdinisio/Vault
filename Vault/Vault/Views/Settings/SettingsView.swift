//
//  SettingsView.swift
//  Vault
//
//  Settings tab: starting paper cash, manual backup (export/import to Files),
//  API keys (Keychain) with setup help, and currency toggle.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Bindable var paperVM: PaperTradingViewModel

    @Environment(\.modelContext) private var context

    @State private var finnhubKey = ""
    @State private var geminiKey = ""
    @State private var groqKey = ""
    @State private var startingCashText = ""
    @State private var toastMessage: Toast?

    // Backup state
    @State private var exportDocument: VaultBackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var showRestoreConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 24) {
                    currencySection
                    paperCashSection
                    backupSection
                    apiKeysSection
                }
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 52)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .toast($toastMessage)
        .onAppear(perform: load)
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: BackupService.suggestedFilename
        ) { result in
            switch result {
            case .success: toastMessage = Toast(message: "Backup saved to Files.", kind: .success)
            case .failure(let error): toastMessage = Toast(message: "Export failed: \(error.localizedDescription)", kind: .error)
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }

    // MARK: Currency

    private var currencySection: some View {
        section("Display currency") {
            Picker("Currency", selection: Binding(
                get: { settings.displayCurrency },
                set: { settings.displayCurrency = $0 }
            )) {
                ForEach(DisplayCurrency.allCases, id: \.self) { c in
                    Text("\(c.symbol)  \(c.rawValue)").tag(c)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: Paper cash

    private var paperCashSection: some View {
        section("Paper trading") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Starting cash balance").font(.system(size: 14)).foregroundStyle(Theme.inkDim)
                HStack {
                    Text(settings.displayCurrency.symbol).foregroundStyle(Theme.inkDim)
                    TextField("10000", text: $startingCashText)
                        .textFieldStyle(.plain)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 18, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 15).padding(.vertical, 12).fieldBox()

                Button {
                    if let entered = Double(startingCashText), entered > 0 {
                        let base = Money.toBase(entered, from: settings.displayCurrency)
                        settings.startingPaperCash = base
                        paperVM.resetCash(to: base)
                        Haptics.success()
                        toastMessage = Toast(message: "Paper balance reset to \(Money.currency(base, currency: settings.displayCurrency)).", kind: .success)
                    }
                } label: {
                    Text("Reset balance to this amount")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.accent)
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: Backup

    private var backupSection: some View {
        section("Backup & restore") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Save a JSON snapshot of your holdings, paper positions, trades and cash to Files or iCloud Drive — then restore it after reinstalling.")
                    .font(.system(size: 13.5)).foregroundStyle(Theme.inkDim)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    actionButton("Export backup", systemImage: "square.and.arrow.up", tint: Theme.accent) {
                        startExport()
                    }
                    actionButton("Import backup", systemImage: "square.and.arrow.down", tint: Theme.gain) {
                        showRestoreConfirm = true
                    }
                }
            }
        }
        .confirmationDialog("Restore from backup?", isPresented: $showRestoreConfirm, titleVisibility: .visible) {
            Button("Choose file & replace all data", role: .destructive) { showImporter = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Importing replaces all current holdings, positions, trades and cash with the backup's contents.")
        }
    }

    // MARK: API keys

    private var apiKeysSection: some View {
        section("API keys") {
            VStack(alignment: .leading, spacing: 20) {
                keyField(
                    title: "Finnhub API key",
                    subtitle: "Live prices, ticker search & news",
                    help: "Free: sign up at finnhub.io → Dashboard → copy the API key.",
                    text: $finnhubKey
                )
                keyField(
                    title: "Gemini API key",
                    subtitle: "Primary AI analysis (Gemini Flash)",
                    help: "Free tier: aistudio.google.com → Get API key.",
                    text: $geminiKey
                )
                keyField(
                    title: "Groq API key",
                    subtitle: "Fallback AI when Gemini's limit is reached (Llama 3.3 70B)",
                    help: "Free: console.groq.com → API Keys.",
                    text: $groqKey
                )
                Text("AI analysis uses Gemini first, then falls back to Groq when Gemini's limit is reached. Add at least one key to enable in-app analysis.")
                    .font(.system(size: 12)).foregroundStyle(Theme.inkDim)
                Button { saveKeys() } label: {
                    Text("Save keys")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.onButton)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Capsule().fill(Theme.accentButton))
                }.buttonStyle(.plain)

                Text("Keys are stored securely in the iOS Keychain — never in plain settings or your backup file.")
                    .font(.system(size: 12)).foregroundStyle(Theme.inkDim)
            }
        }
    }

    private func keyField(title: String, subtitle: String, help: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
                Spacer()
                if !text.wrappedValue.isEmpty {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundStyle(Theme.gain)
                }
            }
            Text(subtitle).font(.system(size: 12.5)).foregroundStyle(Theme.inkDim)
            SecureField("Paste key…", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 15).padding(.vertical, 12).fieldBox()
            Text(help).font(.system(size: 12)).foregroundStyle(Theme.inkFaint)
        }
    }

    // MARK: Building blocks

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).vaultLabel()
            content()
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentCard()
        }
    }

    private func actionButton(_ title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity).padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(tint.opacity(0.35), lineWidth: 0.5))
            )
        }.buttonStyle(.plain)
    }

    // MARK: Actions

    private func load() {
        finnhubKey = KeychainService.shared.get(.finnhub) ?? ""
        geminiKey = KeychainService.shared.get(.gemini) ?? ""
        groqKey = KeychainService.shared.get(.groq) ?? ""
        startingCashText = String(Int(Money.convert(settings.startingPaperCash, to: settings.displayCurrency).rounded()))
    }

    private func saveKeys() {
        KeychainService.shared.set(finnhubKey.trimmingCharacters(in: .whitespacesAndNewlines), for: .finnhub)
        KeychainService.shared.set(geminiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: .gemini)
        KeychainService.shared.set(groqKey.trimmingCharacters(in: .whitespacesAndNewlines), for: .groq)
        toastMessage = Toast(message: "API keys saved.", kind: .success)
    }

    private func startExport() {
        do {
            let data = try BackupService.makeBackupData(context: context, settings: settings, cash: paperVM.cash)
            exportDocument = VaultBackupDocument(data: data)
            showExporter = true
        } catch {
            toastMessage = Toast(message: "Couldn't build backup: \(error.localizedDescription)", kind: .error)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            toastMessage = Toast(message: "Import cancelled: \(error.localizedDescription)", kind: .error)
        case .success(let urls):
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let counts = try BackupService.restore(from: data, into: context, settings: settings, paperVM: paperVM)
                toastMessage = Toast(message: "Restored \(counts.holdings) holdings, \(counts.positions) positions, \(counts.trades) trades.", kind: .success)
            } catch {
                toastMessage = Toast(message: "Couldn't read that backup file.", kind: .error)
            }
        }
    }
}

private extension View {
    func fieldBox() -> some View {
        background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Theme.line.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line.opacity(0.12), lineWidth: 0.5)))
    }
}

#Preview(traits: .landscapeLeft) {
    ZStack {
        VaultBackground(performance: 0.2)
        SettingsView(settings: AppSettings(), paperVM: PaperTradingViewModel())
            .environment(AppSettings())
    }
    .modelContainer(MockData.previewContainer())
}
