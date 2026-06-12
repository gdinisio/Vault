//
//  VaultBackground.swift
//  Vault
//
//  Flat system background, exactly like Apple's own apps — white in light,
//  true black in dark. Liquid Glass materials and content provide the depth;
//  the canvas stays quiet (and free: no gradients, blurs or repeating
//  animations compositing behind every screen).
//
//  `performance` is retained in the API for call-site stability and possible
//  future ambient treatments, but deliberately unused — a tinted canvas reads
//  as decoration, not information.
//

import SwiftUI

struct VaultBackground: View {
    /// Overall portfolio performance, normalised to roughly -1...1. Unused —
    /// see header note.
    var performance: Double = 0

    var body: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
    }
}

#Preview("Light") {
    VaultBackground(performance: 0.6)
}

#Preview("Dark") {
    VaultBackground(performance: -0.6)
        .preferredColorScheme(.dark)
}
