//
//  Scenery.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 09/01/2024.
//

import Foundation

enum RoomCharacter: UInt16 {
    case leto = 0
    case jessica = 2
    case thufir = 4
    case duncan = 6
    case gurney = 8
    case stilgar = 10
    case liet = 12
    case chani = 14
    case harah = 16
    case baron = 18
    case feyd = 20 // and 21
    case emperor = 22
    case sardaukar = 24
    case smuggler = 26
    case fremen = 28  // + 33 for face change
    case fremen2 = 30 // + 33 for face change
    case fremen3 = 32 // and 33
    case gurneyWounded = 34
}

enum SceneryType: String {
    case palace = "PALACE.HSQ"
    case sietch = "SIET.HSQ"
    case village = "VILG.HSQ"
    case harkonnen = "HARK.HSQ"
}


protocol RoomCommandProtocol {
}


struct RoomLine: RoomCommandProtocol {
    var pt1: DunePoint
    var pt2: DunePoint
    var paletteOffset: UInt8
}


struct RoomPolygon: RoomCommandProtocol {
    var command: UInt8
    var drawCommand: UInt8
    var paletteOffset: UInt8
    var hGradient: Int16
    var vGradient: Int16
    var startY: UInt16
    var finalY: UInt16
    var polygonSideUp: [UInt16]
    var polygonSideDown: [UInt16]
    /// Bit 8 of the polygon command. The span is still filled left to right, but the gradient and noise land on the mirrored x.
    var reverseGradient: Bool
}


struct RoomSprite: RoomCommandProtocol {
    var spriteID: UInt16
    var pt: DunePoint
    var paletteOffset: UInt8
    var flipX: Bool
    var flipY: Bool
    var scale: UInt16
}


struct RoomMarker: RoomCommandProtocol {
    /// DOS standing slot. The room lists markers front to back in the file, and the engine consumes that list from the end, so slot 0 is the last marker in the file.
    var index: Int
    var pt: DunePoint
    var paletteOffset: UInt8
    var flipX: Bool
    var flipY: Bool
    var scale: UInt16
}


@MainActor
struct RoomSpriteIndices {
    var sprite: Sprite
    var indexStart: Int
    var indexEnd: Int
    
    init(_ spriteName: String, _ indexStart: Int, _ indexEnd: Int) {
        self.sprite = Sprite(spriteName)
        self.indexStart = indexStart
        self.indexEnd = indexEnd
    }
}



struct Room {
    var offset: UInt32 = 0
    var commands: [RoomCommandProtocol] = []
}


@MainActor
final class Scenery {
    private var resource: Resource
    private var spriteIndices: [RoomSpriteIndices] = []
    private var characterSprite: Sprite
    
    // Conversion of scale factors
    private let transformScale: [UInt16] = [ 0x100, 0x120, 0x140, 0x160, 0x180, 0x1C0, 0x200, 0x280 ]
        

    var rooms: [Room] = []
    var roomCount: Int {
        return rooms.count
    }
    
    var characters: Dictionary<Int, RoomCharacter> = [:]

    init(_ fileName: String) {
        self.resource = Resource(fileName)
        self.characterSprite = Sprite("PERS.HSQ")
        
        if fileName == "SIET.SAL" {
            self.spriteIndices = [
                RoomSpriteIndices("SIET0.HSQ", 0, 0),
                RoomSpriteIndices("SIET1.HSQ", 1, 12),
                RoomSpriteIndices("BOTA.HSQ", 13, 13)
            ]
        } else if fileName == "VILG.SAL" {
            self.spriteIndices = [
                RoomSpriteIndices("VILG.HSQ", 0, 8)
            ]
        } else if fileName == "HARK.SAL" {
            self.spriteIndices = [
                RoomSpriteIndices("FORT.HSQ", 0, 4),
                RoomSpriteIndices("BUNK.HSQ", 5, 7)
            ]
        } else if fileName == "PALACE.SAL" {
            self.spriteIndices = [
                RoomSpriteIndices("POR.HSQ", 0, 2),
                RoomSpriteIndices("POR.HSQ", 3, 3),
                RoomSpriteIndices("PROUGE.HSQ", 4, 4),
                RoomSpriteIndices("COMM.HSQ", 5, 7),
                RoomSpriteIndices("EQUI.HSQ", 8, 9),
                RoomSpriteIndices("BALCON.HSQ", 10, 11),
                RoomSpriteIndices("CORR.HSQ", 12, 13),
                RoomSpriteIndices("SERRE.HSQ", 14, 14),
            ]
        }

        
        parseRooms()
    }
    
    
    func parseRooms() {
        // The file starts with one little-endian offset per room. The first
        // offset is also the byte length of that table.
        let firstOffset = resource.stream!.readUInt16LE()
        let roomCount = Int(firstOffset / 2)
        guard roomCount > 0 else { return }

        var offsets = [firstOffset]
        if roomCount > 1 {
            for _ in 1..<roomCount {
                offsets.append(resource.stream!.readUInt16LE())
            }
        }

        for offset in offsets {
            resource.stream!.seek(UInt32(offset))

            var room = Room(offset: UInt32(offset))
            let markerCount = Int(resource.stream!.readByte())
            var markerIndex = 0

            // Processes room blocks. 0xFFFF ends the room and must be consumed.
            while !resource.stream!.isEOF() {
                let cmd = resource.stream!.readUInt16LE()
                if cmd == 0xFFFF {
                    break
                }

                if cmd & 0x8000 == 0 {
                    // Low 9 bits == 1 is a standing-person marker. Anything else is a sprite blit.
                    var x = Int16(resource.stream!.readByte())
                    let y = Int16(resource.stream!.readByte())
                    let paletteOffset = resource.stream!.readByte()

                    if cmd & 0x0200 != 0 {
                        x += 256
                    }

                    let flipY = cmd & 0x2000 != 0
                    let flipX = cmd & 0x4000 != 0
                    let scaleFactor = Int((cmd >> 10) & 7)
                    let partId = Int(cmd & 0x1FF)

                    if partId == 1 {
                        let slot = markerIndex < markerCount ? markerCount - 1 - markerIndex : -1
                        let roomMarker = RoomMarker(
                            index: slot,
                            pt: DunePoint(x, y),
                            paletteOffset: paletteOffset,
                            flipX: flipX,
                            flipY: flipY,
                            scale: transformScale[scaleFactor]
                        )

                        room.commands.append(roomMarker)
                        markerIndex += 1
                    } else if partId > 1 {
                        let roomSprite = RoomSprite(
                            spriteID: UInt16(partId - 1),
                            pt: DunePoint(x, y),
                            paletteOffset: paletteOffset,
                            flipX: flipX,
                            flipY: flipY,
                            scale: transformScale[scaleFactor]
                        )
                        room.commands.append(roomSprite)
                    }
                } else {
                    let paletteIndex = UInt8(cmd & 0xFF)
                    let drawCommand = UInt8(cmd >> 8)

                    if drawCommand >> 6 == 2 {
                        parsePolygon(&room, paletteIndex, drawCommand, paletteIndex)
                    } else if drawCommand >> 6 == 3 {
                        // Bit cast, matching the DOS word used as a signed coordinate.
                        let x1 = Int16(bitPattern: resource.stream!.readUInt16LE())
                        let y1 = Int16(bitPattern: resource.stream!.readUInt16LE())
                        let x2 = Int16(bitPattern: resource.stream!.readUInt16LE())
                        let y2 = Int16(bitPattern: resource.stream!.readUInt16LE())

                        let line = RoomLine(pt1: DunePoint(x1, y1), pt2: DunePoint(x2, y2), paletteOffset: paletteIndex)
                        room.commands.append(line)
                    }
                }
            }
            
            rooms.append(room)
        }
    }
    
    
    func setPalette(_ roomIndex: Int) {
        guard let sprite = sprite(at: roomIndex) else {
            return
        }
        
        sprite.setPalette()
    }
    
    
    func drawRoom(_ index: Int, buffer: PixelBuffer) {
        guard rooms.indices.contains(index) else { return }
        let room = rooms[index]
        
        var i = 0
        
        guard let sprite = sprite(at: index) else {
            return
        }
        
        sprite.setPalette()
        
        while i < room.commands.count {
            let command = room.commands[i]
            
            if command is RoomSprite {
                drawRoomSprite(command as! RoomSprite, sprite, index, buffer)
            } else if command is RoomPolygon {
                drawPolygon(command as! RoomPolygon, buffer)
            } else if command is RoomLine {
                drawLine(command as! RoomLine, buffer)
            } else if command is RoomMarker {
                drawCharacter(command as! RoomMarker, buffer)
            }
            
            i += 1
        }
    }
    
    
    private func drawCharacter(_ marker: RoomMarker, _ buffer: PixelBuffer) {
        guard let character = characters[marker.index] else {
            return
        }

        let fx = SpriteEffect.transform(
            offset: marker.paletteOffset,
            flipX: marker.flipX,
            flipY: marker.flipY,
            scaleStep: marker.scale
        )

        characterSprite.setPalette()
        let base = character.rawValue
        characterSprite.drawFrame(base, x: Int16(marker.pt.x), y: Int16(marker.pt.y), buffer: buffer, effect: fx)
        characterSprite.drawFrame(base + 1, x: Int16(marker.pt.x), y: Int16(marker.pt.y), buffer: buffer, effect: fx)
    }
    
    
    private func drawRoomSprite(_ roomSprite: RoomSprite, _ sprite: Sprite, _ roomIndex: Int, _ buffer: PixelBuffer) {
        let fx = SpriteEffect.transform(
            offset: roomSprite.paletteOffset,
            flipX: roomSprite.flipX,
            flipY: roomSprite.flipY,
            scaleStep: roomSprite.scale
        )

        sprite.setPalette()
        sprite.drawFrame(roomSprite.spriteID, x: Int16(roomSprite.pt.x), y: Int16(roomSprite.pt.y), buffer: buffer, effect: fx)
    }
    
    
    private func sprite(at index: Int) -> Sprite? {
        for s in spriteIndices {
            if index >= s.indexStart && index <= s.indexEnd {
                return s.sprite
            }
        }
        
        return nil
    }
    
    
    private func drawPolygon(_ roomPolygon: RoomPolygon, _ buffer: PixelBuffer) {
        Primitives.fillPolygon(roomPolygon, buffer, isOffset: roomPolygon.paletteOffset <= 64)
    }
    
    
    private func drawLine(_ roomLine: RoomLine, _ buffer: PixelBuffer) {
        Primitives.drawLine(roomLine.pt1, roomLine.pt2, Int(roomLine.paletteOffset), buffer, isOffset: false)
    }
}


extension Scenery {
    private func parsePolygon(_ room: inout Room, _ command: UInt8, _ drawCommand: UInt8, _ paletteIndex: UInt8) {
        // engine.logger.log(.debug, " - Polygon:")
        
        var polygonSideDown = [UInt16]()
        var polygonSideUp = [UInt16]()
        
        let hGradient = 16 * Int16(resource.stream!.readSByte())
        let vGradient = 16 * Int16(resource.stream!.readSByte())
        
        let startX = resource.stream!.readUInt16LE()
        let startY = resource.stream!.readUInt16LE()

        // Part 1
        var x: UInt16
        var y: UInt16
        var lastX = startX & 0x3FFF
        var lastY = startY
        
        repeat {
            x = resource.stream!.readUInt16LE()
            y = resource.stream!.readUInt16LE()
            
            addPolygonSection(lastX, lastY, x & 0x3FFF, y, startY, &polygonSideDown)
            
            lastX = x & 0x3FFF
            lastY = y
        } while (x & 0x4000) == 0
        
        let finalX = lastX
        let finalY = lastY
        
        // Part 2
        lastX = startX
        lastY = startY
        
        if (x & 0x8000) == 0 {
            repeat {
                x = resource.stream!.readUInt16LE()
                y = resource.stream!.readUInt16LE()
                
                addPolygonSection(lastX, lastY, x & 0x3FFF, y, startY, &polygonSideUp)
                
                lastX = x & 0x3FFF
                lastY = y
            } while (x & 0x8000) == 0
        }

        addPolygonSection(lastX, lastY, finalX, finalY, startY, &polygonSideUp)
        
        let polygon = RoomPolygon(
            command: command,
            drawCommand: drawCommand,
            paletteOffset: paletteIndex,
            hGradient: hGradient,
            vGradient: vGradient,
            startY: startY,
            finalY: finalY,
            polygonSideUp: polygonSideUp,
            polygonSideDown: polygonSideDown,
            reverseGradient: drawCommand & 0x01 != 0
        )
        
        room.commands.append(polygon)
    }
    
    
    private func addPolygonSectionHorizontal(_ x0: UInt16, _ x1: UInt16, _ polygonSide: inout [UInt16]) {
        polygonSide.append(min(x0, x1))
    }
    
    
    private func addPolygonSectionVertical(_ x0: UInt16, _ y0: UInt16, _ deltaY: Int, _ signY: Int, _ polygonSide: inout [UInt16]) {
        var y0 = Int(y0)
        
        if signY < 0 {
            y0 -= deltaY
        } else {
            y0 += deltaY
        }
        
        var n = deltaY + 1
        
        repeat {
            polygonSide.append(x0)
            n -= 1
        } while n > 0
    }
    
    
    private func addPolygonSection(_ x0: UInt16, _ y0: UInt16, _ x1: UInt16, _ y1: UInt16, _ startY: UInt16, _ polygonSide: inout [UInt16]) {
        // engine.logger.log(.debug, "   - Section: x0=\(x0), y0=\(y0), x1=\(x1), y1=\(y1), startY=\(startY)")
        
        var deltaX = -(Int(x0) - Int(x1))
        var deltaY = -(Int(y0) - Int(y1))
        
        if deltaX == 0 && deltaY == 0 {
            return
        }
        
        if deltaY == 0 {
            addPolygonSectionHorizontal(x0, x1, &polygonSide)
            return
        }
        
        var signY = 1
        
        if deltaY < 0 {
            deltaY = -deltaY
            signY = -signY
        }
        
        if deltaX == 0 {
            addPolygonSectionVertical(x0, y0, deltaY, signY, &polygonSide)
            return
        }
        
        var signX = 1
        
        if deltaX < 0 {
            signX = -signX
            deltaX = -deltaX
        }
        
        let bp6 = signY
        let bp4 = signX
        var bp2 = signY
        var bp0 = signX
        
        var minorDelta = deltaY
        var majorDelta = deltaX
        
        if deltaX > deltaY {
            bp2 = 0
        } else {
            if deltaY == 0 {
                return
            }
            
            swap(&minorDelta, &majorDelta)
            bp0 = 0
        }
        
        // Full-width error term. A checked Int16 add traps once the longer
        // axis passes 16384, which is inside the 16-bit coordinate range.
        var ax = majorDelta / 2
        var cx = majorDelta
        var x = Int(x0)

        repeat {
            ax += minorDelta
            
            let dx: Int
            let bx: Int
            
            if ax >= majorDelta {
                ax -= majorDelta
                dx = bp4
                bx = bp6
            } else {
                dx = bp0
                bx = bp2
            }
            
            if bx == 1 {
                polygonSide.append(UInt16(truncatingIfNeeded: x))
            }
            
            x += dx
            cx -= 1
        } while cx > 0
    }
}
