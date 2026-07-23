//
//  NetworkStatusMonitor.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import Foundation
import Network
import Observation

/// 端末が通信可能かを監視して、チャット画面へ知らせます。
@Observable
@MainActor
final class NetworkStatusMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "app.frienday.network-monitor")

    private(set) var isConnected = true

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            Task { @MainActor in
                self?.isConnected = isConnected
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
