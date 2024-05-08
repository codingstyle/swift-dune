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
        let engine = DuneEngine.shared
        
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
        
        var color: UInt32 = 0xFF0000FF
        engine.palette.rgbaColor(at: (isOffset ? 127 : 0) + paletteIndex, to: &color)

        while true {
            let destIndex = y0 * buffer.width + x0
            buffer.rawPointer[destIndex] = color

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
    static func drawEllipse(_ center: DunePoint, _ xRadius: Int, _ yRadius: Int, _ buffer: PixelBuffer) {
        let twoASquare = 2 * xRadius * xRadius
        let twoBSquare = 2 * yRadius * yRadius
        var x = xRadius
        var y = 0
        var xChange = (yRadius * yRadius) * (1 - (2 * xRadius))
        var yChange = xRadius * xRadius
        var ellipseError = 0
        var stoppingX = twoBSquare * xRadius
        var stoppingY = 0
        
        let cy = Int(center.y)
        let cx = Int(center.x)

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
        y = yRadius
        xChange = yRadius * yRadius
        yChange = xRadius * xRadius * (1 - (2 * yRadius))
        ellipseError = 0
        stoppingX = 0
        stoppingY = twoASquare * yRadius
        
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
        for y in minY...maxY {
            var intersections: [Int16] = []

            // Find intersections with the polygon edges
            for i in 0..<n {
                let p1 = polygon[i]
                let p2 = polygon[(i + 1) % n]

                // Check if the edge crosses the scanline
                if (p1.y <= y && p2.y > y) || (p2.y <= y && p1.y > y) {
                    let intersectionX = p1.x + (y - p1.y) * (p2.x - p1.x) / (p2.y - p1.y)
                    intersections.append(intersectionX)
                }
            }

            // Sort the intersection points
            intersections.sort()

            // Draw horizontal line segments between pairs of intersection points
            var i = 0
            
            while i < intersections.count {
                let x0 = max(0, min(intersections[i], bufferWidth - 1))
                let x1 = max(0, min(intersections[i + 1], bufferWidth - 1))
                drawLine(DunePoint(x0, y), DunePoint(x1, y), paletteOffset, buffer, isOffset: isOffset)
                i += 2
            }
        }
    }
    
    
    static func fillRect(_ rect: DuneRect, _ paletteIndex: Int, _ buffer: PixelBuffer, isOffset: Bool = true) {
        let engine = DuneEngine.shared

        var y1 = Int(rect.y)
        let y2 = Int(rect.y) + Int(rect.height)
        let x2 = Int(rect.x) + Int(rect.width)

        var color: UInt32 = 0xFF0000FF
        engine.palette.rgbaColor(at: (isOffset ? 127 : 0) + paletteIndex, to: &color)
        
        while y1 < y2 {
            var x1 = Int(rect.x)
            
            while x1 < x2 {
                let destIndex = y1 * buffer.width + x1
                buffer.rawPointer[destIndex] = color
                
                x1 += 1
            }
            
            y1 += 1
        }
    }
    
    
    // TODO: GRADIENTS !!
}
