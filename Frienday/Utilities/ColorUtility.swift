//
//  ColorUtility.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import SwiftUI

extension Color {
    /// `#RRGGBB`形式の文字列をSwiftUIの色に変換します。
    init(profileHex hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let rgb = Int(value, radix: 16) else {
            self = Color.accentColor
            return
        }

        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
