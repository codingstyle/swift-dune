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
    case fremen = 28
    case fremen2 = 30
    case fremen3 = 32 // and 33
    case gurneyHorizontal = 34 // wtf?
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
}


struct RoomSprite: RoomCommandProtocol {
    var spriteID: UInt8
    var pt: DunePoint
    var paletteOffset: UInt8
    var flipX: Bool
    var flipY: Bool
    var scale: UInt16
}


struct RoomMarker: RoomCommandProtocol {
    var index: Int
    var pt: DunePoint
    var paletteOffset: UInt8
    var flipX: Bool
    var flipY: Bool
    var scale: UInt16
}


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


final class Scenery {
    private let engine = DuneEngine.shared
 
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
        let firstOffset = resource.stream!.readUInt16LE(peek: true)
        let roomCount = firstOffset / 2

        print("")
        print("rooms=\(firstOffset / 2)")

        resource.stream!.seek(UInt32(firstOffset))

        for i in 0..<roomCount {
            var room = Room(offset: resource.stream!.offset)
            let markerCount = resource.stream!.readByte() // Room marker count
            var markerIndex = 0
            
            engine.logger.log(.debug, "--------------------------------------------------------------------------------------")
            engine.logger.log(.debug, "")
            engine.logger.log(.debug, "ROOM #\(i): markers=\(markerCount), offset=\(room.offset)")
            
            // Processes room blocks
            while !resource.stream!.isEOF() && resource.stream!.readUInt16LE(peek: true) != 0xFFFF {
                let command = resource.stream!.readByte()
                
                if command == 0x00 {
                    // Invalid command
                    engine.logger.log(.error, " - Invalid command")
                } else if command <= 0x3F {
                    // Command = 0x01 => Marker
                    // Command <= 0x3F => Sprite blit
                    
                    let modificator = resource.stream!.readByte()
                    var x = Int16(resource.stream!.readByte())
                    let y = Int16(resource.stream!.readByte())
                    let paletteOffset = resource.stream!.readByte()
                    let addByte = (modificator & 0x02 != 0)
                    
                    if addByte {
                        x += 256
                    }
                    
                    let flipY = (modificator & 0x20 != 0)
                    let flipX = (modificator & 0x40 != 0)
                    let scaleFactor = Int((modificator & 0x1C) >> 2)
                    
                    if command == 0x01 {
                        let roomMarker = RoomMarker(
                            index: markerIndex,
                            pt: DunePoint(x, y),
                            paletteOffset: paletteOffset,
                            flipX: flipX,
                            flipY: flipY,
                            scale: transformScale[scaleFactor]
                        )
                        
                        room.commands.append(roomMarker)
                        markerIndex += 1

                        engine.logger.log(.debug, " - Marker: x=\(x), y=\(y), flipX=\(flipX), flipY=\(flipY), scaleFlag=\(scaleFactor), modificator=\(String.fromByte(modificator))")
                    } else {
                        let roomSprite = RoomSprite(
                            spriteID: command - 1,
                            pt: DunePoint(x, y),
                            paletteOffset: paletteOffset,
                            flipX: flipX,
                            flipY: flipY,
                            scale: transformScale[scaleFactor]
                        )
                        room.commands.append(roomSprite)
                        
                        engine.logger.log(.debug, " - Sprite: id=\(command), x=\(x), y=\(y), flipX=\(flipX), flipY=\(flipY), scaleFlag=\(scaleFactor), paletteOffset=\(paletteOffset), modificator=\(String.fromByte(modificator))")
                    }
                } else {
                    let paletteIndex = command & 0x7F
                    let drawCommand = resource.stream!.readByte()

                    if (drawCommand >> 6) == 2 {
                        parsePolygon(&room, command, drawCommand, paletteIndex)
                    } else if (drawCommand >> 6) == 3 {
                        // Line
                        let x1 = Int16(resource.stream!.readUInt16LE())
                        let y1 = Int16(resource.stream!.readUInt16LE())
                        let x2 = Int16(resource.stream!.readUInt16LE())
                        let y2 = Int16(resource.stream!.readUInt16LE())

                        engine.logger.log(.debug, " - Line: x1=\(x1), y1=\(y1), x2=\(x2), y2=\(y2)")
                        
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
        
        let frameInfo = characterSprite.frame(at: Int(character.rawValue))
        let scale = CGFloat((frameInfo.width << 8) / marker.scale) / CGFloat(frameInfo.width)
        
        var fx: SpriteEffect {
            return .transform(offset: marker.paletteOffset, flipX: marker.flipX, flipY: marker.flipY, scale: scale)
        }
     
        characterSprite.setPalette()
        characterSprite.drawFrame(character.rawValue, x: Int16(marker.pt.x), y: Int16(marker.pt.y), buffer: buffer, effect: fx)
    }
    
    
    private func drawRoomSprite(_ roomSprite: RoomSprite, _ sprite: Sprite, _ roomIndex: Int, _ buffer: PixelBuffer) {
        let frameInfo = sprite.frame(at: Int(roomSprite.spriteID))
        let scale = CGFloat((frameInfo.width << 8) / roomSprite.scale) / CGFloat(frameInfo.width)

        var fx: SpriteEffect {
            return .transform(offset: roomSprite.paletteOffset, flipX: roomSprite.flipX, flipY: roomSprite.flipY, scale: scale)
        }
        
        sprite.setPalette()
        sprite.drawFrame(UInt16(roomSprite.spriteID), x: Int16(roomSprite.pt.x), y: Int16(roomSprite.pt.y), buffer: buffer, effect: fx)
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
        Primitives.drawLine(roomLine.pt1, roomLine.pt2, Int(roomLine.paletteOffset), buffer)
    }
}


extension Scenery {
    private func parsePolygon(_ room: inout Room, _ command: UInt8, _ drawCommand: UInt8, _ paletteIndex: UInt8) {
        engine.logger.log(.debug, " - Polygon:")
        
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
            polygonSideDown: polygonSideDown
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
        engine.logger.log(.debug, "   - Section: x0=\(x0), y0=\(y0), x1=\(x1), y1=\(y1), startY=\(startY)")
        
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
        
        let bp6 = Int16(signY)
        let bp4 = Int16(signX)
        var bp2 = Int16(signY)
        var bp0 = Int16(signX)
        
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
        
        var ax = Int16(truncatingIfNeeded: majorDelta / 2)
        var cx = Int16(truncatingIfNeeded: majorDelta)
        var x0 = x0

        repeat {
            ax += Int16(truncatingIfNeeded: minorDelta)
            
            var dx: Int16
            var bx: Int16
            
            if ax >= majorDelta {
                ax -= Int16(truncatingIfNeeded: majorDelta)
                dx = bp4
                bx = bp6
            } else {
                dx = bp0
                bx = bp2
            }
            
            dx += Int16(x0)
            
            if bx == 1 {
                polygonSide.append(x0)
            }
            
            x0 = UInt16(bitPattern: dx)
            
            cx -= 1
        } while cx > 0
    }
}
