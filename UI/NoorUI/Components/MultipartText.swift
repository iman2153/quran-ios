//
//  MultipartText.swift
//
//
//  Created by Mohamed Afifi on 2023-07-14.
//

import SwiftUI

private struct TextPart {
    enum Kind {
        case plain
        case sura
        case verse(lineLimit: Int?)
    }

    // MARK: Internal

    let kind: Kind
    let text: String

    @ViewBuilder
    func view(ofSize size: MultipartText.FontSize) -> some View {
        switch kind {
        case .plain:
            Text(text)
                .font(size.plainFont)
        case .sura:
            if NSLocale.preferredLanguages.first != "ar" {
                Text(text)
                    .padding(.top, 5)
                    .frame(alignment: .center)
                    .font(size.suraFont)
            }
        case .verse(let lineLimit):
            Text(text)
                .lineLimit(lineLimit)
                .font(size.verseFont)
        }
    }
}

public struct MultipartText: ExpressibleByStringInterpolation {
    enum FontSize {
        case body
        case caption

        // MARK: Internal

        var plainFont: Font {
            switch self {
            case .body: return .body
            case .caption: return .caption
            }
        }

        var suraFont: Font {
            switch self {
            case .body: return .custom(.suraNames, size: 20, relativeTo: .body)
            case .caption: return .custom(.suraNames, size: 17, relativeTo: .caption)
            }
        }

        var verseFont: Font {
            switch self {
            case .body: return .custom(.quran, size: 20, relativeTo: .body)
            case .caption: return .custom(.quran, size: 17, relativeTo: .caption)
            }
        }
    }

    public struct StringInterpolation: StringInterpolationProtocol {
        // MARK: Lifecycle

        public init(literalCapacity: Int, interpolationCount: Int) {}

        // MARK: Public

        public mutating func appendLiteral(_ literal: String) {
            parts.append(.init(kind: .plain, text: literal))
        }

        public mutating func appendInterpolation(sura: String) {
            parts.append(.init(kind: .sura, text: sura))
        }

        public mutating func appendInterpolation(verse: String, lineLimit: Int? = nil) {
            parts.append(.init(kind: .verse(lineLimit: lineLimit), text: verse))
        }

        public mutating func appendInterpolation(_ plain: String) {
            parts.append(.init(kind: .plain, text: plain))
        }

        // MARK: Fileprivate

        fileprivate var parts: [TextPart] = []
    }

    // MARK: Lifecycle

    public init(stringInterpolation: StringInterpolation) {
        parts = stringInterpolation.parts
    }

    public init(stringLiteral value: StringLiteralType) {
        parts = [.init(kind: .plain, text: value)]
    }

    // MARK: Internal

    @ViewBuilder
    func view(ofSize size: FontSize) -> some View {
        HStack(spacing: 0) {
            ForEach(0 ..< parts.count, id: \.self) { i in
                parts[i].view(ofSize: size)
            }
        }
    }

    // MARK: Private

    private let parts: [TextPart]
}

extension MultipartText {
    public static func text(_ plain: String) -> MultipartText {
        MultipartText(stringLiteral: plain)
    }
}