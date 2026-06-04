//
//  ToastView.swift
//  Vault
//
//  Non-blocking toast that slides in from the top and auto-dismisses.
//

import SwiftUI

struct Toast: Equatable, Identifiable {
    enum Kind { case error, info, success }
    let id = UUID()
    var message: String
    var kind: Kind = .error
}

struct ToastView: View {
    let toast: Toast

    private var tint: Color {
        switch toast.kind {
        case .error: return Theme.loss
        case .info: return Theme.accent
        case .success: return Theme.gain
        }
    }

    private var symbol: String {
        switch toast.kind {
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(toast.message)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 18)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(tint)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .frame(maxWidth: 460)
        .padding(.horizontal, 24)
    }
}

// MARK: - Presenter modifier

private struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast {
                ToastView(toast: toast)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(3))
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            self.toast = nil
                        }
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: toast)
    }
}

extension View {
    /// Presents a toast that slides in from the top and auto-dismisses after 3s.
    func toast(_ toast: Binding<Toast?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}

#Preview {
    ZStack {
        Theme.bgDeep.ignoresSafeArea()
        VStack(spacing: 16) {
            ToastView(toast: Toast(message: "Couldn't reach Finnhub. Showing last-known prices.", kind: .error))
            ToastView(toast: Toast(message: "Prices updated.", kind: .success))
        }
    }
}
