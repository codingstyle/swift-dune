//
//  Cursor.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 10/10/2026.
//

import Foundation


enum CursorShape {
    case arrow
    case hand
    case up
    case right
    case down
    case left
}


/// Draws the hardcoded 16×16 game cursors.
///
/// Each shape is an AND/OR mask, MSB first (bit 15 is the leftmost pixel).
/// An AND bit keeps the background. AND clear with OR set draws colour 0x0F.
/// AND clear with OR clear draws black.
@MainActor
final class Cursor {
    static let size = 16

    private static let white: UInt8 = 0x0F
    private static let black: UInt8 = 0x00
  
    private let engine = DuneEngine.shared

    var shape: CursorShape = .arrow

    func render(_ buffer: PixelBuffer) {
        let mouseCoords = engine.mouse.coordinates
      
        let image = CursorImage.image(for: shape)
        let originX = max(0, Int(mouseCoords.x) &- image.hotspotX)
        let originY = max(0, Int(mouseCoords.y) &- image.hotspotY)

        if originX >= buffer.width || originY >= buffer.height {
            return
        }

        let width = min(Cursor.size, buffer.width &- originX)
        let height = min(Cursor.size, buffer.height &- originY)
        let pixels = buffer.rawPointer

        var row = 0

        while row < height {
            let andMask = image.andMask[row]
            let orMask = image.orMask[row]
            let rowOffset = (originY &+ row) &* buffer.width &+ originX
            var col = 0

            while col < width {
                let bit: UInt16 = 0x8000 >> col

                if andMask & bit == 0 {
                    pixels[rowOffset &+ col] = (orMask & bit) != 0 ? Cursor.white : Cursor.black
                }

                col &+= 1
            }

            row &+= 1
        }
    }
}


private struct CursorImage {
    let hotspotX: Int
    let hotspotY: Int
    let andMask: [UInt16]
    let orMask: [UInt16]

    static func image(for shape: CursorShape) -> CursorImage {
        switch shape {
        case .arrow:
            return arrow
        case .hand:
            return hand
        case .up:
            return up
        case .right:
            return right
        case .down:
            return down
        case .left:
            return left
        }
    }

    // Hotspot (0, 0).
    private static let arrow = CursorImage(
        hotspotX: 0,
        hotspotY: 0,
        andMask: [
            0b0011111111111111,
            0b0001111111111111,
            0b0000111111111111,
            0b0000011111111111,
            0b0000001111111111,
            0b0000000111111111,
            0b0000000011111111,
            0b0000000001111111,
            0b0000000000111111,
            0b0000000000111111,
            0b0000000111111111,
            0b0001000011111111,
            0b0011000011111111,
            0b1111100001111111,
            0b1111100001111111,
            0b1111110001111111,
        ],
        orMask: [
            0b0000000000000000,
            0b0100000000000000,
            0b0110000000000000,
            0b0111000000000000,
            0b0111100000000000,
            0b0111110000000000,
            0b0111111000000000,
            0b0111111100000000,
            0b0111111110000000,
            0b0111110000000000,
            0b0110110000000000,
            0b0100011000000000,
            0b0000011000000000,
            0b0000001100000000,
            0b0000001100000000,
            0b0000000000000000,
        ]
    )

    // Busy hand, hotspot (1, 0).
    private static let hand = CursorImage(
        hotspotX: 1,
        hotspotY: 0,
        andMask: [
            0b1100111111111111,
            0b1000001111111111,
            0b1000000111111111,
            0b1110000001111111,
            0b1111000000111111,
            0b1100000000000111,
            0b1100000000000011,
            0b1000000000000011,
            0b0000000000000001,
            0b0000000000000001,
            0b1000000000000000,
            0b1100000000000000,
            0b1110000000000000,
            0b1111000000000000,
            0b1111110000000000,
            0b1111111100000000,
        ],
        orMask: [
            0b0000000000000000,
            0b0011000000000000,
            0b0001110000000000,
            0b0000011000000000,
            0b0000001110000000,
            0b0000110100000000,
            0b0001011011111000,
            0b0001100111011000,
            0b0110110000111100,
            0b0011000010101100,
            0b0000001110111100,
            0b0001111111011110,
            0b0000111111111110,
            0b0000001110111110,
            0b0000000001111110,
            0b0000000001111110,
        ]
    )

    // Upward travel arrow, hotspot (4, 0).
    private static let up = CursorImage(
        hotspotX: 4,
        hotspotY: 0,
        andMask: [
            0b1111101111111111,
            0b1111000111111111,
            0b1110000011111111,
            0b1100000001111111,
            0b1000000000111111,
            0b0000000000011111,
            0b0000000000011111,
            0b1110000011111111,
            0b1110000011111111,
            0b1111111111111111,
            0b1111111111111111,
            0b1111111111111111,
            0b1111111111111111,
            0b1111111111111111,
            0b1111111111111111,
            0b1111111111111111,
        ],
        orMask: [
            0b0000000000000000,
            0b0000010000000000,
            0b0000111000000000,
            0b0001111100000000,
            0b0011111110000000,
            0b0111111111000000,
            0b0000111000000000,
            0b0000111000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
        ]
    )

    // Rightward travel arrow, hotspot (4, 2).
    private static let right = CursorImage(
        hotspotX: 4,
        hotspotY: 2,
        andMask: [
            0b1100111111111111,
            0b1100011111111111,
            0b1100001111111111,
            0b0000000111111111,
            0b0000000011111111,
            0b0000000001111111,
            0b0000000011111111,
            0b0000000111111111,
            0b1100001111111111,
            0b1100011111111111,
            0b1100111111111111,
            0b1111111111111111,
            0b1111111111111111,
            0b1111111111111111,
            0b1111111111111111,
            0b1111111111111111,
        ],
        orMask: [
            0b0000000000000000,
            0b0001000000000000,
            0b0001100000000000,
            0b0001110000000000,
            0b0111111000000000,
            0b0111111100000000,
            0b0111111000000000,
            0b0001110000000000,
            0b0001100000000000,
            0b0001000000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
        ]
    )

    // Downward travel arrow, hotspot (4, 0).
    private static let down = CursorImage(
        hotspotX: 4,
        hotspotY: 0,
        andMask: [
            0b1110000011111111,
            0b1110000011111111,
            0b0000000000011111,
            0b0000000000011111,
            0b1000000000111111,
            0b1100000001111111,
            0b1110000011111111,
            0b1111000111111111,
            0b1111101111111111,
            0b1111111111111111,
            0b1111111111111111,
            0b1111111111111111,
            0b1111111111111111,
            0b1111111111111111,
            0b1111111111111111,
            0b1111111111111111,
        ],
        orMask: [
            0b0000000000000000,
            0b0000111000000000,
            0b0000111000000000,
            0b0111111111000000,
            0b0011111110000000,
            0b0001111100000000,
            0b0000111000000000,
            0b0000010000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
        ]
    )

    // Leftward travel arrow, hotspot (5, 2).
    private static let left = CursorImage(
        hotspotX: 5,
        hotspotY: 2,
        andMask: [
            0b1111100111111111,
            0b1111000111111111,
            0b1110000111111111,
            0b1100000001111111,
            0b1000000001111111,
            0b0000000001111111,
            0b1000000001111111,
            0b1100000001111111,
            0b1110000111111111,
            0b1111000111111111,
            0b1111100111111111,
            0b1111111111111111,
            0b1111111111111111,
            0b1111111111111111,
            0b1111111111111111,
            0b1111111111111111,
        ],
        orMask: [
            0b0000000000000000,
            0b0000010000000000,
            0b0000110000000000,
            0b0001110000000000,
            0b0011111100000000,
            0b0111111100000000,
            0b0011111100000000,
            0b0001110000000000,
            0b0000110000000000,
            0b0000010000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
            0b0000000000000000,
        ]
    )
}
