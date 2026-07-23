//
//  ProfileImageCropView.swift
//  Frienday
//
//  Created by Codex on 23/07/2026.
//

import SwiftUI
import UIKit

/// 切り取り画面へ渡す画像を識別可能な形で保持します。
struct ProfileImageCropItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// 画像の位置と拡大率を調整し、プロフィール用画像に切り取ります。
struct ProfileImageCropView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onComplete: (Data) -> Void

    @State private var zoomScale: CGFloat = 1
    @State private var committedZoomScale: CGFloat = 1
    @State private var normalizedOffset = CGSize.zero
    @State private var committedOffset = CGSize.zero

    private let maximumZoomScale: CGFloat = 5
    private let outputSize: CGFloat = 1_024

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                cropCanvas

                HStack(spacing: 14) {
                    Image(systemName: "photo")
                        .font(.caption)
                        .accessibilityHidden(true)

                    Slider(value: zoomBinding, in: 1...maximumZoomScale)
                        .accessibilityLabel("画像の拡大率")

                    Image(systemName: "photo.fill")
                        .font(.title3)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 20)
            .background(Color.black)
            .navigationTitle("画像の調整")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .foregroundStyle(.white)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        resetAdjustment()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("調整をリセット")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("適用") {
                        completeCropping()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    /// 丸い完成範囲と、移動・拡大できる画像を表示します。
    private var cropCanvas: some View {
        GeometryReader { proxy in
            let cropSize = min(proxy.size.width, proxy.size.height)
            let displayedSize = displayedImageSize(cropSize: cropSize)

            Image(uiImage: image)
                .resizable()
                .frame(width: displayedSize.width, height: displayedSize.height)
                .offset(
                    x: normalizedOffset.width * cropSize,
                    y: normalizedOffset.height * cropSize
                )
                .frame(width: cropSize, height: cropSize)
                .clipped()
                .contentShape(Rectangle())
                .gesture(dragGesture(cropSize: cropSize))
                .simultaneousGesture(magnificationGesture)
                .overlay {
                    ZStack {
                        Rectangle()
                            .fill(.black.opacity(0.48))
                        Circle()
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                    .allowsHitTesting(false)
                }
                .overlay {
                    Circle()
                        .stroke(.white, lineWidth: 2)
                        .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 16)
    }

    private var zoomBinding: Binding<CGFloat> {
        Binding {
            zoomScale
        } set: { newValue in
            zoomScale = min(max(newValue, 1), maximumZoomScale)
            normalizedOffset = constrainedOffset(normalizedOffset, zoomScale: zoomScale)
            committedZoomScale = zoomScale
            committedOffset = normalizedOffset
        }
    }

    /// ドラッグ量を画像サイズに依存しない位置に変換します。
    private func dragGesture(cropSize: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard cropSize > 0 else { return }
                let proposedOffset = CGSize(
                    width: committedOffset.width + value.translation.width / cropSize,
                    height: committedOffset.height + value.translation.height / cropSize
                )
                normalizedOffset = constrainedOffset(proposedOffset, zoomScale: zoomScale)
            }
            .onEnded { _ in
                committedOffset = normalizedOffset
            }
    }

    /// ピンチ操作を1倍から5倍までの拡大率に反映します。
    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoomScale = min(max(committedZoomScale * value.magnification, 1), maximumZoomScale)
                normalizedOffset = constrainedOffset(normalizedOffset, zoomScale: zoomScale)
            }
            .onEnded { _ in
                committedZoomScale = zoomScale
                committedOffset = normalizedOffset
            }
    }

    /// 画像が切り取り範囲の外側まで常に埋めるよう、移動範囲を制限します。
    private func constrainedOffset(_ offset: CGSize, zoomScale: CGFloat) -> CGSize {
        let baseSize = normalizedBaseImageSize
        let maximumX = max((baseSize.width * zoomScale - 1) / 2, 0)
        let maximumY = max((baseSize.height * zoomScale - 1) / 2, 0)

        return CGSize(
            width: min(max(offset.width, -maximumX), maximumX),
            height: min(max(offset.height, -maximumY), maximumY)
        )
    }

    /// 画面上でアスペクトフィルされた画像サイズを返します。
    private func displayedImageSize(cropSize: CGFloat) -> CGSize {
        CGSize(
            width: normalizedBaseImageSize.width * zoomScale * cropSize,
            height: normalizedBaseImageSize.height * zoomScale * cropSize
        )
    }

    private var normalizedBaseImageSize: CGSize {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGSize(width: 1, height: 1)
        }

        let aspectFillScale = max(1 / imageSize.width, 1 / imageSize.height)
        return CGSize(
            width: imageSize.width * aspectFillScale,
            height: imageSize.height * aspectFillScale
        )
    }

    /// 画像の位置と拡大率を初期状態に戻します。
    private func resetAdjustment() {
        zoomScale = 1
        committedZoomScale = 1
        normalizedOffset = .zero
        committedOffset = .zero
    }

    /// 現在の調整結果を正方形JPEGとして出力します。
    private func completeCropping() {
        let baseSize = normalizedBaseImageSize
        let renderedSize = CGSize(
            width: baseSize.width * zoomScale * outputSize,
            height: baseSize.height * zoomScale * outputSize
        )
        let drawingRect = CGRect(
            x: (outputSize - renderedSize.width) / 2 + normalizedOffset.width * outputSize,
            y: (outputSize - renderedSize.height) / 2 + normalizedOffset.height * outputSize,
            width: renderedSize.width,
            height: renderedSize.height
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: outputSize, height: outputSize),
            format: format
        )
        let croppedImage = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: outputSize, height: outputSize))
            image.draw(in: drawingRect)
        }

        guard let data = croppedImage.jpegData(compressionQuality: 0.88) else { return }
        onComplete(data)
    }
}

#Preview {
    ProfileImageCropView(
        image: UIImage(systemName: "person.crop.square") ?? UIImage(),
        onCancel: {},
        onComplete: { _ in }
    )
}
