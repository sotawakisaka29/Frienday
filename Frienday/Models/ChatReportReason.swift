//
//  ChatReportReason.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import Foundation

/// 不適切なメッセージを通報するときの理由です。
enum ChatReportReason: String, CaseIterable, Identifiable {
    case harassment
    case spam
    case personalInformation
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .harassment:
            return "嫌がらせ・暴言"
        case .spam:
            return "迷惑行為・スパム"
        case .personalInformation:
            return "個人情報の投稿"
        case .other:
            return "その他"
        }
    }
}
