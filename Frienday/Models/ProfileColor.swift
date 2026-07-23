//
//  ProfileColor.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import Foundation

/// プロフィールで選べるイメージカラーです。
enum ProfileColor: String, CaseIterable, Identifiable {
    case blue = "#2F80ED"
    case teal = "#008C95"
    case green = "#219653"
    case yellow = "#D9A400"
    case coral = "#EB5757"
    case pink = "#D94F84"
    case purple = "#9B51E0"
    case charcoal = "#4F4F4F"

    var id: String { rawValue }
}
