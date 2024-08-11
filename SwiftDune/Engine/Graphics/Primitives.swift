//
//  Primitives.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 30/01/2024.
//

import Foundation

struct Primitives {
    /**
     Bresenham line plotting algorithm
     */
    static func drawLine(_ pt1: DunePoint, _ pt2: DunePoint, _ paletteIndex: Int, _ buffer: PixelBuffer, isOffset: Bool = true) {
        var x0 = Int(pt1.x)
        var y0 = Int(pt1.y)
        let x1 = Int(pt2.x)
        let y1 = Int(pt2.y)
        let dx = abs(x1 - x0)
        let sx = x0 < x1 ? 1 : -1
        let dy = -abs(y1 - y0)
        let sy = y0 < y1 ? 1 : -1
        var err = dx + dy
        var e2: Int
        
        let paletteIndexWithOffset = UInt8((isOffset ? 127 : 0) + paletteIndex)

        while true {
            let destIndex = y0 * buffer.width + x0
            buffer.rawPointer[destIndex] = paletteIndexWithOffset

            if x0 == x1 && y0 == y1 {
                break
            }
            
            e2 = 2 * err
            
            if e2 >= dy {
                err += dy
                x0 += sx
            }
            
            if e2 <= dx {
                err += dx
                y0 += sy
            }
        }
    }
    
    
    /**
     Fast ellipse plotting algorithm using only integer arithmetic
     @see https://dai.fmph.uniba.sk/upload/0/01/Ellipse.pdf
     */
    static func drawEllipse(_ center: DunePoint, _ radius: DunePoint, _ buffer: PixelBuffer) {
        let rx = Int(radius.x)
        let ry = Int(radius.y)
        let cy = Int(center.y)
        let cx = Int(center.x)

        let twoASquare = Int(2 * rx * rx)
        let twoBSquare = Int(2 * ry * ry)
        var x = rx
        var y = Int(0)
        var xChange = (ry * ry) * (1 - (2 * rx))
        var yChange = rx * rx
        var ellipseError = 0
        var stoppingX = twoBSquare * rx
        var stoppingY = 0

        func plotPoint(_ x: Int, _ y: Int) {
            if x < 0 || x > buffer.width || y < 0 || y > buffer.height {
                return
            }

            var destIndex = y * buffer.width + x
            let initialColor = buffer.rawPointer[destIndex]
            
            var i = 0
            var j = 0
            
            while i < 4 {
                j = 0
                
                while j < 4 {
                    if y + j >= buffer.height || x + i >= buffer.width {
                        break
                    }
                    
                    destIndex = (y + j) * buffer.width + (x + i)
                    buffer.rawPointer[destIndex] = initialColor
                    j += 1
                }
                
                i += 1
            }
        }
        
        
        // Subroutine for plotting points on the four quadrants
        func plotEllipsePoints() {
            if (cx + x) % 4 != 0 {
                return
            }

            plotPoint(cx + x, cy + y)
            plotPoint(cx - x, cy + y)
            plotPoint(cx + x, cy - y)
            plotPoint(cx - x, cy - y)
        }
        
        while stoppingX >= stoppingY {
            plotEllipsePoints()
            
            y += 1
            stoppingY += twoASquare
            ellipseError += yChange
            yChange += twoASquare
            
            if (2 * ellipseError) + xChange > 0 {
                x -= 1
                stoppingX -= twoBSquare
                ellipseError += xChange
                xChange += twoBSquare
            }
        }
        
        // 1st point set is done; start the 2nd set of points
        x = 0
        y = ry
        xChange = ry * ry
        yChange = rx * rx * (1 - (2 * ry))
        ellipseError = 0
        stoppingX = 0
        stoppingY = twoASquare * ry
        
        while stoppingX <= stoppingY {
            plotEllipsePoints()
            
            x += 1
            stoppingX += twoBSquare
            ellipseError += xChange
            xChange += twoBSquare
            
            if (2 * ellipseError) + yChange > 0 {
                y -= 1
                stoppingY -= twoASquare
                ellipseError += yChange
                yChange += twoASquare
            }
        }
    }
    
    
    // @see https://github.com/madmoose/dune/blob/master/room.cpp
    
    static func fillPolygon(_ polygon: [DunePoint], _ paletteOffset: Int,_ buffer: PixelBuffer, isOffset: Bool = true) {
        let n = polygon.count
        var minY = Int16.max
        var maxY = Int16.min
        let bufferWidth = Int16(buffer.width)

        // Find the min and max y coordinates to optimize scanline traversal
        for point in polygon {
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        // Scanline fill algorithm
        var y = minY
        
        while y < maxY {
            var intersections: [Int16] = []

            // Find intersections with the polygon edges
            var i = 0

            while i < n {
                let p1 = polygon[i]
                let p2 = polygon[(i + 1) % n]

                // Check if the edge crosses the scanline
                if (p1.y <= y && p2.y > y) || (p2.y <= y && p1.y > y) {
                    let intersectionX = p1.x + (y - p1.y) * (p2.x - p1.x) / (p2.y - p1.y)
                    intersections.append(intersectionX)
                }
                
                i += 1
            }

            // Sort the intersection points
            intersections.sort()

            // Draw horizontal line segments between pairs of intersection points
            i = 0
            
            while i < intersections.count {
                let x0 = max(0, min(intersections[i], bufferWidth - 1))
                let x1 = max(0, min(intersections[i + 1], bufferWidth - 1))
                drawLine(DunePoint(x0, y), DunePoint(x1, y), paletteOffset, buffer, isOffset: isOffset)
                i += 2
            }
            
            y += 1
        }
    }
    
    
    
    static func drawGradientLineWithNoise(_ pixelBuffer: PixelBuffer, _ x: UInt16, _ y: UInt16, _ w: UInt16, _ bp: UInt16, _ si: UInt16, _ di: Int16, _ color: UInt16) {
        var offset = 320 * Int(y) + Int(x)
        var w = w
        var bp = bp
        var color = Int(color)
        
        repeat {
            let lsb = (bp & 1) != 0
            bp >>= 1
            
            if lsb {
                bp ^= si
            }
            
            let v = (bp & 3) + ((UInt16(color) >> 8) & 0xFF) - 1
            color += Int(di)

            pixelBuffer.rawPointer[offset] = UInt8(truncatingIfNeeded: (v & 0xFF))
            offset += 1
            w -= 1
        } while w > 0
    }
    
    
    static func fillPolygonV2(_ polygon: RoomPolygonV2, _ buffer: PixelBuffer, isOffset: Bool = true) {
        let command = (UInt16(polygon.drawCommand) << 8) | (UInt16(polygon.command) & 0xFF)

        let bp: UInt16 = (command & 0x3E00) != 0 ? 1 : 0
        let ds22df: UInt16 = (command & 0x3E00) | 0x2
        let color = (command & 0xFF) << 8

        //if (command & 0x0100) == 0 {
            var y: UInt16 = 0
            
            while y < polygon.finalY - polygon.startY {
                var x0 = polygon.polygonSideUp[Int(y)]
                var x1 = polygon.polygonSideDown[Int(y)]
                
                if x1 < x0 {
                    swap(&x0, &x1)
                }
                
                let w = x1 - x0 + 1
                
                drawGradientLineWithNoise(
                    buffer,
                    x0,
                    y + polygon.startY,
                    w,
                    bp,
                    ds22df,
                    polygon.hGradient,
                    color
                )

                y += 1
            }
        /*} else {
            print("Invalid polygon to draw")
        }*/
    }
    
    
    static func fillRect(_ rect: DuneRect, _ paletteIndex: Int, _ buffer: PixelBuffer, isOffset: Bool = true) {
        var y1 = Int(rect.y)
        let y2 = Int(rect.y) + Int(rect.height)
        let x2 = Int(rect.x) + Int(rect.width)

        let paletteIndexWithOffset = UInt8((isOffset ? 127 : 0) + paletteIndex)
        let initialX1 = Int(rect.x)
        
        while y1 < y2 {
            var x1 = initialX1
            let y1Offset = y1 * buffer.width
            
            while x1 < x2 {
                let destIndex = y1Offset + x1
                buffer.rawPointer[destIndex] = paletteIndexWithOffset
                
                x1 += 1
            }
            
            y1 += 1
        }
    }
}
