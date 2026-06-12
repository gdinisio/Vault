//
//  SettingsView.swift
//  Vault
//
//  Settings tab: display currency, paper trading, manual backup
//  (export/import to Files), and API keys (Keychain) with setup help.
//
//  A single flat scroll. Each group is a section title + a hairline-separated
//  set of rows — actions are plain rows (Stocks/Settings idiom), never tinted
//  buttons. Explanatory prose lives in group footers and the API help sheet.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Bindable var paperVM: PaperTradingViewModel

    @Environment(\.modelContext) private var context
    @Query private var paperPositions: [PaperPosition]
    @Query private var paperTrades: [PaperTrade]

    @State private var finnhubKey = ""
    @State private var geminiKey = ""
    @State private var groqKey = ""
    @State private var startingCashAmount: Double = 10_000
    @State private var toastMessage: Toast?

    // Backup state
    @State private var exportDocument: VaultBackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var showRestoreConfirm = false

    // Paper reset + help sheets
    @State private var showResetConfirm = false
    @State private var showAPIHelp = false
    @State private var showBackupHelp = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                currencyGroup
                paperGroup
                backupGroup
                apiGroup
            }
            .vaultPagePadding()
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .toast($toastMessage)
        .onAppear(perform: load)
        .sheet(isPresented: $showAPIHelp) { APIHelpView() }
        .sheet(isPresented: $showBackupHelp) { BackupHelpView() }
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

    private var currencyGroup: some View {
        cardGroup("Display currency") {
            Picker("Currency", selection: Binding(
                get: { settings.displayCurrency },
                set: { settings.displayCurrency = $0 }
            )) {
                ForEach(DisplayCurrency.allCases, id: \.self) { c in
                    Text("\(c.symbol)  \(c.rawValue)").tag(c)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
    }

    // MARK: Paper cash

    private var paperGroup: some View {
        cardGroup("Paper trading") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Starting cash balance")
                        .font(.subheadline).foregroundStyle(Theme.inkDim)
                    Spacer()
                    Text(Money.currency0(Money.toBase(startingCashAmount, from: settings.displayCurrency), currency: settings.displayCurrency))
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                }
                Slider(value: $startingCashAmount, in: 10_000...50_000, step: 10_000) {
                    Text("Starting cash")
                } minimumValueLabel: {
                    Text("\(settings.displayCurrency.symbol)10k").font(.caption2.monospacedDigit()).foregroundStyle(Theme.inkDim)
                } maximumValueLabel: {
                    Text("\(settings.displayCurrency.symbol)50k").font(.caption2.monospacedDigit()).foregroundStyle(Theme.inkDim)
                }
                .tint(Theme.accent)
                .sensoryFeedback(.selection, trigger: startingCashAmount)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)

            rowDivider
            actionRow("Apply starting cash", systemImage: "checkmark", tint: Theme.accent) {
                applyStartingCash()
            }
            rowDivider
            actionRow("Reset Paper Trading", systemImage: "arrow.counterclockwise", tint: Color(.systemRed)) {
                showResetConfirm = true
            }
        }
        .confirmationDialog("Reset all paper trading data?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Delete positions & reset cash", role: .destructive) { resetPaperTrading() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every open position and all trade history, and resets your cash to the configured starting amount.")
        }
    }

    // MARK: Backup

    private var backupGroup: some View {
        cardGroup("Backup & restore", help: { showBackupHelp = true }) {
            actionRow("Export backup", systemImage: "square.and.arrow.up", tint: Theme.accent) {
                startExport()
            }
            rowDivider
            actionRow("Import backup", systemImage: "square.and.arrow.down", tint: Theme.gain) {
                showRestoreConfirm = true
            }
        }
        .confirmationDialog("Restore from backup?", isPresented: $showRestoreConfirm, titleVisibility: .visible) {
            Button("Choose file & replace all data", role: .destructive) { showImporter = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Importing replaces all current holdings, positions, trades, watchlists and cash with the backup's contents.")
        }
    }

    // MARK: API keys

    private var apiGroup: some View {
        cardGroup("API keys", help: { showAPIHelp = true }) {
            keyFieldRow("Finnhub", text: $finnhubKey)
            rowDivider
            keyFieldRow("Gemini", text: $geminiKey)
            rowDivider
            keyFieldRow("Groq", text: $groqKey)
            rowDivider
            actionRow("Save API keys", systemImage: "key.fill", tint: Theme.accent) {
                saveKeys()
            }
        }
    }

    // MARK: Building blocks

    /// A titled group: a prominent section title (optionally with a “?” help
    /// affordance) above a hairline-separated, rounded-clipped set of rows. No
    /// fill — structure comes from the title, dividers and spacing (the app's
    /// flat content surface). When a group offers help, the sheet carries all
    /// the explanation so the surface itself needs no footer prose.
    private func cardGroup(_ title: String,
                           help: (() -> Void)? = nil,
                           @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                groupTitle(title)
                if let help {
                    Spacer()
                    helpButton(label: title, action: help)
                }
            }
            .padding(.horizontal, 4)
            VStack(spacing: 0) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentCard()
        }
    }

    /// Prominent group header — matches the app's content section titles
    /// ("Holdings", "Allocation") rather than the small uppercase field label.
    /// On this fill-less flat surface the title is the only separator between
    /// groups, so it needs primary-colour weight to be easy to spot.
    private func groupTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Theme.ink)
    }

    /// The “?” affordance opening a group's help sheet — progressive disclosure
    /// keeps the surface clean while detail stays one tap away.
    private func helpButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 24))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) help")
    }

    /// A full-width tappable action row — label + leading glyph, no chevron
    /// (actions don't navigate). Destructive variants pass a red tint.
    private func actionRow(_ title: String, systemImage: String, tint: Color = Theme.ink, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                    .foregroundStyle(tint)
                    .frame(width: 22)
                Text(title)
                    .font(.body)
                    .foregroundStyle(tint)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableRowStyle(cornerRadius: 0))
    }

    /// One API key: label + “set” check, with a monospaced secure field below.
    private func keyFieldRow(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
                Spacer()
                if !text.wrappedValue.isEmpty {
                    Image(systemName: "checkmark.circle.fill").font(.subheadline).foregroundStyle(Theme.gain)
                }
            }
            SecureField("Paste key…", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 14).padding(.vertical, 11).fieldBox()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
    }

    /// Hairline separator between rows, inset to the content edge.
    private var rowDivider: some View {
        Divider().overlay(Theme.line.opacity(0.08)).padding(.leading, 18)
    }

    // MARK: Actions

    private func load() {
        finnhubKey = KeychainService.shared.get(.finnhub) ?? ""
        geminiKey  = KeychainService.shared.get(.gemini)  ?? ""
        groqKey    = KeychainService.shared.get(.groq)    ?? ""
        let converted = Money.convert(settings.startingPaperCash, to: settings.displayCurrency)
        let snapped   = (converted / 10_000).rounded() * 10_000
        startingCashAmount = min(50_000, max(10_000, snapped))
    }

    private func applyStartingCash() {
        let base = Money.toBase(startingCashAmount, from: settings.displayCurrency)
        settings.startingPaperCash = base
        paperVM.resetCash(to: base)
        Haptics.success()
        toastMessage = Toast(message: "Paper balance set to \(Money.currency(base, currency: settings.displayCurrency)).", kind: .success)
    }

    private func resetPaperTrading() {
        paperPositions.forEach { context.delete($0) }
        paperTrades.forEach   { context.delete($0) }
        let base = Money.toBase(startingCashAmount, from: settings.displayCurrency)
        settings.startingPaperCash = base
        paperVM.resetCash(to: base)
        try? context.save()
        Haptics.success()
        toastMessage = Toast(message: "Paper trading reset. All positions and trades cleared.", kind: .success)
    }

    private func saveKeys() {
        KeychainService.shared.set(finnhubKey.trimmingCharacters(in: .whitespacesAndNewlines), for: .finnhub)
        KeychainService.shared.set(geminiKey.trimmingCharacters(in: .whitespacesAndNewlines),  for: .gemini)
        KeychainService.shared.set(groqKey.trimmingCharacters(in: .whitespacesAndNewlines),    for: .groq)
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
                let data   = try Data(contentsOf: url)
                let counts = try BackupService.restore(from: data, into: context, settings: settings, paperVM: paperVM)
                toastMessage = Toast(message: "Restored \(counts.holdings) holdings, \(counts.positions) positions & \(counts.watchItems) watch items.", kind: .success)
            } catch {
                toastMessage = Toast(message: "Couldn't read that backup file.", kind: .error)
            }
        }
    }
}

// MARK: - API Help Sheet

private struct APIHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Vault connects to three free services. Paste each personal key once — it's stored in the iOS Keychain and never leaves your device except to its own service.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkDim)
                        .fixedSize(horizontal: false, vertical: true)

                    serviceBlock(
                        service: "Finnhub",
                        role: "Live prices, search & news",
                        steps: [
                            "Sign up free at finnhub.io.",
                            "Open your Dashboard.",
                            "Copy the API key and paste it into the Finnhub field."
                        ]
                    )
                    serviceBlock(
                        service: "Gemini · primary AI",
                        role: "Powers in-app analysis",
                        steps: [
                            "Sign in at aistudio.google.com.",
                            "Tap Get API key → Create API key.",
                            "Copy and paste it into the Gemini field."
                        ]
                    )
                    serviceBlock(
                        service: "Groq · fallback AI",
                        role: "Used when Gemini's free limit is reached",
                        steps: [
                            "Sign up at console.groq.com.",
                            "Open API Keys → Create API Key.",
                            "Copy and paste it into the Groq field."
                        ]
                    )
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("API Key Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .presentationBackground(.ultraThickMaterial)
        .presentationCornerRadius(Theme.sheetRadius)
        .presentationDetents([.medium, .large])
    }

    private func serviceBlock(service: String, role: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(service)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(role)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.inkDim)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 19, height: 19)
                            .background(Circle().fill(Theme.accent.opacity(0.85)))
                        Text(step)
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.inkDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.line.opacity(0.06)))
        }
    }
}

// MARK: - Backup Help Sheet

private struct BackupHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("A backup is a single JSON file holding your entire Vault — holdings, paper positions and trades, watchlists, cash and settings. Keep one in Files or iCloud Drive so you can restore everything after reinstalling or switching device.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkDim)
                        .fixedSize(horizontal: false, vertical: true)

                    infoBlock(
                        icon: "square.and.arrow.up",
                        title: "Export backup",
                        body: "Builds the snapshot and lets you save it anywhere the Files app reaches — on-device, iCloud Drive or another cloud provider."
                    )
                    infoBlock(
                        icon: "square.and.arrow.down",
                        title: "Import backup",
                        body: "Pick a file you exported earlier. Its contents replace everything currently in the app, so it's best run on a fresh install. You'll be asked to confirm first."
                    )
                    infoBlock(
                        icon: "lock.shield",
                        title: "What isn't included",
                        body: "Your API keys stay in the iOS Keychain and are never written to the backup file. Re-enter them in the API keys section after restoring."
                    )
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Backup & Restore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .presentationBackground(.ultraThickMaterial)
        .presentationCornerRadius(Theme.sheetRadius)
        .presentationDetents([.medium, .large])
    }

    private func infoBlock(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(body)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.inkDim)
                    .fixedSize(horizontal: false, vertical: true)
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
