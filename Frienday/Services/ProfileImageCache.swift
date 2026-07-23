//
//  ProfileImageCache.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import Foundation
import UIKit

/// プロフィール画像をメモリとディスクにキャッシュします。
final class ProfileImageCache: @unchecked Sendable {
    static let shared = ProfileImageCache()

    private let imageCache = NSCache<NSURL, UIImage>()
    private let responseCache: URLCache
    private let session: URLSession

    private init() {
        responseCache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 128 * 1024 * 1024,
            directory: nil
        )

        let configuration = URLSessionConfiguration.default
        configuration.urlCache = responseCache
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)

        imageCache.countLimit = 100
        imageCache.totalCostLimit = 32 * 1024 * 1024
    }

    /// URLが同じ場合はキャッシュを優先し、ない場合だけ通信します。
    func image(for url: URL) async throws -> UIImage {
        let cacheKey = url as NSURL
        if let image = imageCache.object(forKey: cacheKey) {
            return image
        }

        let request = URLRequest(
            url: url,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 30
        )

        if let cachedResponse = responseCache.cachedResponse(for: request),
           let image = UIImage(data: cachedResponse.data) {
            storeInMemory(image, for: cacheKey)
            return image
        }

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }

        responseCache.storeCachedResponse(
            CachedURLResponse(response: response, data: data, storagePolicy: .allowed),
            for: request
        )
        storeInMemory(image, for: cacheKey)
        return image
    }

    private func storeInMemory(_ image: UIImage, for key: NSURL) {
        let width = image.size.width * image.scale
        let height = image.size.height * image.scale
        let cost = Int(width * height * 4)
        imageCache.setObject(image, forKey: key, cost: cost)
    }
}
