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


struct RoomPolygonPoint {
    var x: Int16
    var y: Int16
    var flag: UInt16
    
    func angle(from centroid: DunePoint) -> Double {
        let dx = Double(self.x - centroid.x)
        let dy = Double(self.y - centroid.y)
        return atan2(dy, dx)
    }
}


struct RoomPolygon: RoomCommandProtocol {
    var paletteOffset: UInt8
    var horizontalEffect: UInt8
    var verticalEffect: UInt8
    var points: [RoomPolygonPoint] = []
    
    var isRect: Bool {
        if points.count != 4 {
            return false
        }
        
        return points[1].x - points[0].x == points[2].x - points[3].x &&
               points[0].y == points[1].y && points[2].y == points[3].y
    }
    
    func asRect() -> DuneRect {
        return DuneRect(points[0].x, points[0].y, UInt16(points[1].x - points[0].x), UInt8(points[3].y - points[0].y))
    }
    
    func asPoints() -> [DunePoint] {
        return points.map { DunePoint($0.x, $0.y) }
    }
    
    func centroid(of points: [RoomPolygonPoint]) -> DunePoint {
        let pointsCount = CGFloat(points.count)
        let xSum = points.reduce(0) { $0 + $1.x }
        let ySum = points.reduce(0) { $0 + $1.y }
        
        let xCenter = Int16(CGFloat(xSum) / pointsCount)
        let yCenter = Int16(CGFloat(ySum) / pointsCount)
        
        return DunePoint(xCenter, yCenter)
    }
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
    private var engine: DuneEngine
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

    init(_ fileName: String, engine: DuneEngine = DuneEngine.shared) {
        self.engine = engine
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

        // let roomOffset = UInt32(roomOffsets[i]) + padding
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
                        /*
                        // V2 Polygon code — WIP
                        let hGradient = resource.stream!.readByte()
                        let vGradient = resource.stream!.readByte()
                        
                        let startX = resource.stream!.readUInt16LE()
                        let startY = resource.stream!.readUInt16LE()

                        // Part 1
                        var x: UInt16 = 0
                        var y: UInt16 = 0
                        var lastX = startX & 0x3FFF
                        var lastY = startY
                        
                        repeat {
                            x = resource.stream!.readUInt16LE()
                            y = resource.stream!.readUInt16LE()
                            
                            // add_gradient_section(lastX, lastY, x & 0x3FFF, y, polygonSideDown)
                            
                            lastX = x & 0x3FFF
                            lastY = y
                        } while (x & 0x4000) == 0
                        
                        // Part 2
                        let finalX = lastX
                        let finalY = lastY
                        
                        lastX = startX
                        lastY = startY
                        
                        if (x & 0x8000) == 0 {
                            repeat {
                                x = resource.stream!.readUInt16LE()
                                y = resource.stream!.readUInt16LE()
                                
                                // add_gradient_section(lastX, lastY, x & 0x3FFF, y, polygonSideUp)
                                
                                lastX = x & 0x3FFF
                                lastY = y
                            } while (x & 0x8000) == 0
                        }

                        // add_gradient_section(lastX, lastY, finalX, finalY, polygonSideUp)
                        
                        y = 0
                        
                        while y != finalY - startY {
                            y += 1
                            
                            let w = polygonSideDown[startY + y] - polygonSideUp[startY + y]
                            
                            if w {
                                // drawNoise(polygonSideUp[y], startY + w, (drawCommand & 0xFF) << 8, 0, 0, 2)
                            }
                        }
                        */
                        
                        
                        // Polygon
                        let horizontalEffect = resource.stream!.readByte()
                        let verticalEffect = resource.stream!.readByte()

                        var polygon = RoomPolygon(paletteOffset: paletteIndex, horizontalEffect: horizontalEffect, verticalEffect: verticalEffect)
                        var cpt: UInt16 = 0
                        var points: [RoomPolygonPoint] = []
                        
                        while cpt < 0xC {
                            var x = resource.stream!.readUInt16LE()
                            let y = resource.stream!.readUInt16LE()
                            let flag = (x & 0xC000) >> 12
                            
                            cpt += flag
                            x = x & 0x0FFF
                            
                            points.append(RoomPolygonPoint(x: Int16(x), y: Int16(y), flag: flag))
                        }
                        
                        // Calculate centroid
                        let center = polygon.centroid(of: points)
                        
                        // Sort points based on angle
                        points = points.sorted { pt1, pt2 in
                            pt1.angle(from: center) < pt2.angle(from: center)
                        }
                        
                        polygon.points = points
                        
                        room.commands.append(polygon)
                         
                        engine.logger.log(.debug, " - Polygon: baseColorIndex=\(paletteIndex), horizontalEffect=\(horizontalEffect), verticalEffect=\(verticalEffect)")
                        
                        polygon.points.forEach { pt in
                            engine.logger.log(.debug, "   -> x=\(pt.x), y=\(pt.y), flag=\(pt.flag)")
                        }
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
        let scale = CGFloat((frameInfo.realWidth << 8) / marker.scale) / CGFloat(frameInfo.realWidth)
        
        var fx: SpriteEffect {
            return .transform(offset: marker.paletteOffset, flipX: marker.flipX, flipY: marker.flipY, scale: scale)
        }
     
        characterSprite.setPalette()
        characterSprite.drawFrame(character.rawValue, x: Int16(marker.pt.x), y: Int16(marker.pt.y), buffer: buffer, effect: fx)
    }
    
    
    private func drawRoomSprite(_ roomSprite: RoomSprite, _ sprite: Sprite, _ roomIndex: Int, _ buffer: PixelBuffer) {
        let frameInfo = sprite.frame(at: Int(roomSprite.spriteID))
        let scale = CGFloat((frameInfo.realWidth << 8) / roomSprite.scale) / CGFloat(frameInfo.realWidth)

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
        if roomPolygon.isRect {
            Primitives.fillRect(roomPolygon.asRect(), Int(roomPolygon.paletteOffset), buffer, isOffset: roomPolygon.paletteOffset <= 64)
        } else {
            Primitives.fillPolygon(roomPolygon.asPoints(), Int(roomPolygon.paletteOffset), buffer, isOffset: roomPolygon.paletteOffset <= 64)
        }
    }
    
    
    private func drawLine(_ roomLine: RoomLine, _ buffer: PixelBuffer) {
        Primitives.drawLine(roomLine.pt1, roomLine.pt2, Int(roomLine.paletteOffset), buffer)
    }
}
