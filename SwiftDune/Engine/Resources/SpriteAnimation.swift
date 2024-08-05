//
//  SpriteAnimation.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 04/08/2024.
//

import Foundation


struct SpriteAnimationFrame {
    var groups: [SpriteAnimationImageGroup] = []
}


struct SpriteAnimationImageGroup {
    var offset: UInt32 = 0
    var images: [SpriteAnimationImage] = []
}


struct SpriteAnimationImage {
    var imageNumber: UInt16
    var xOffset: Int16
    var yOffset: Int16
}



struct SpriteAnimation {
    var x: Int16 = 0
    var y: Int16 = 0
    var width: UInt16 = 0
    var height: UInt16 = 0
    var definitionOffset: UInt32 = 0
    
    var frames: [SpriteAnimationFrame] = []
    
    static func parseAnimations(_ resource: Resource, animationOffset: UInt32) -> [SpriteAnimation] {
        let engine = DuneEngine.shared

        if animationOffset >= resource.stream!.size - 2 {
            // No animations found
            return []
        }
        
        // Find starting position for anims
        resource.stream!.seek(animationOffset)
        
        // let animationSize = resource.stream!.size - animationOffset

        // Read header (should be 0x0000)
        let header = resource.stream!.readUInt16()
        
        if (header != 0x0000) {
            engine.logger.log(.error, "parseAnimations(): ERROR - header=0x0000")
            // No animation found
            resource.stream!.seek(animationOffset)
            return []
        }
        
        if resource.fileName == "SHAI.HSQ" {
            return parseShaiAnimations(resource, animationOffset: animationOffset)
        } else if resource.fileName == "DEATH1.HSQ" {
            return parseDeathAnimations(resource, animationOffset: animationOffset)
        } else if resource.fileName == "ATTACK.HSQ" {
            // TODO: parse animations
        }
        
        return parseCharacterAnimations(resource, animationOffset: animationOffset)
    }
    
    
    static func parseCharacterAnimations(_ resource: Resource, animationOffset: UInt32) -> [SpriteAnimation] {
        let engine = DuneEngine.shared
        
        let animationHeaderSize: UInt32 = 14
        let blockSize = resource.stream!.readUInt16LE() // Block size
        
        if animationOffset + UInt32(blockSize) > resource.stream!.size {
            engine.logger.log(.error, "parseAnimations(): ERROR - Offset and size are above the resource size. animationOffset=\(animationOffset), blockSize=\(blockSize), resourceSize=\(resource.stream!.size)")
            resource.stream!.seek(animationOffset)
            return []
        }
        
        let animX = resource.stream!.readUInt16LE()
        
        if animX > 320 {
            engine.logger.log(.error, "parseAnimations(): ERROR - animX > 320. Something was not parsed correctly")
            resource.stream!.seek(animationOffset)
            return []
        }
        
        var animations: [SpriteAnimation] = []
        let animY = resource.stream!.readUInt16LE()
        let animWidth = resource.stream!.readUInt16LE()
        let animHeight = resource.stream!.readUInt16LE()
        let animDefinitionOffset = UInt32(resource.stream!.readUInt16LE())
        
        engine.logger.log(.debug, "parseAnimations(): Animation header: size=\(blockSize), x=\(animX), y=\(animY), width=\(animWidth), height=\(animHeight), offset=\(animDefinitionOffset)")
        
        // Reads the first image group def: this is the size of image group header
        let imageGroupSize = resource.stream!.readUInt16LE(peek: true) / 2
        var imageGroupIndex: [UInt16] = []

        for _ in 0..<imageGroupSize - 1 {
            imageGroupIndex.append(resource.stream!.readUInt16LE())
        }
        
        var imageGroups: [SpriteAnimationImageGroup] = []

        for i: Int in 0..<imageGroupIndex.count {
            var group = SpriteAnimationImageGroup()
            group.offset = UInt32(imageGroupIndex[i])

            resource.stream!.seek(animationOffset + animationHeaderSize + group.offset)
            
            // Add image reference in group whil byte until we meet 0x00 marking end of image group
            while resource.stream!.readByte(peek: true) != 0 {
                let bytes = resource.stream!.readBytes(3)
                let groupImage = SpriteAnimationImage(
                    imageNumber: UInt16(bytes[0] - 1),
                    xOffset: Int16(bytes[1]),
                    yOffset: Int16(bytes[2])
                )
                
                group.images.append(groupImage)
            }
            
            resource.stream?.skip(1) // 0x00
            imageGroups.append(group)
        }

        // Animation groups
        resource.stream!.seek(animationOffset + animationHeaderSize + animDefinitionOffset - 2)
        
        let animGroupOffset = resource.stream!.offset
        var animGroupIndex: [UInt16] = []

        while animGroupIndex.isEmpty || (animGroupIndex.last! < resource.stream!.readUInt16LE(peek: true) && resource.stream!.readUInt16LE(peek: true) & 0xFF00 == 0) {
            animGroupIndex.append(resource.stream!.readUInt16LE())
        }

        for i: Int in 0..<animGroupIndex.count {
            var animation = SpriteAnimation(
                x: Int16(animX),
                y: Int16(animY),
                width: animWidth,
                height: animHeight,
                definitionOffset: animDefinitionOffset
            )
            
            resource.stream!.seek(animGroupOffset + UInt32(animGroupIndex[i]))
            
            var animationFrame = SpriteAnimationFrame()
            
            while !resource.stream!.isEOF() && resource.stream!.readByte(peek: true) != 0xFF {
                let byteValue = resource.stream!.readByte()
                
                if byteValue == 0x00 {
                    animation.frames.append(animationFrame)
                    animationFrame = SpriteAnimationFrame()
                    continue
                }
                
                // Group indexes start at 02
                
                let groupIndex = min(Int(byteValue - 2), imageGroups.count - 1)
                animationFrame.groups.append(imageGroups[groupIndex])
            }

            resource.stream!.skip(1) // 0xFF
            
            if animationFrame.groups.count > 0 {
                animation.frames.append(animationFrame)
            }
            
            animations.append(animation)
        }
        
        return animations
    }
    
    
    static func parseShaiAnimations(_ resource: Resource, animationOffset: UInt32) -> [SpriteAnimation] {
        let engine = DuneEngine.shared
        let blockSize = resource.stream!.readUInt16LE() // Block size
        
        if animationOffset + UInt32(blockSize) > resource.stream!.size {
            engine.logger.log(.error, "parseShaiAnimations(): ERROR - Offset and size are above the resource size. animationOffset=\(animationOffset), blockSize=\(blockSize), resourceSize=\(resource.stream!.size)")
            return []
        }

        var animations: [SpriteAnimation] = []

        var animation = SpriteAnimation()
        animation.x = 0
        animation.y = 0
        animation.width = 320
        animation.height = 200
        animation.definitionOffset = animationOffset
        
        var maxSpriteIndex: UInt16 = 0
        var group = SpriteAnimationImageGroup()
        
        while !resource.stream!.isEOF() {
            if resource.stream!.offset < resource.stream!.size - 8 {
                let x1 = resource.stream!.readUInt16LE()
                let y1 = resource.stream!.readUInt16LE()
                let x2 = resource.stream!.readUInt16LE()
                let y2 = resource.stream!.readUInt16LE()

                // Blit region to clear previous sprite
                if x1 < x2 && y1 < y2 && x1 != maxSpriteIndex + 1 {
                    var frame = SpriteAnimationFrame()
                    frame.groups.append(group)
                    animation.frames.append(frame)
                    animation.frames.append(frame)

                    group = SpriteAnimationImageGroup()
                    continue
                }
             
                resource.stream!.seek(resource.stream!.offset - 8)
            }
            
            let spriteIndex = resource.stream!.readUInt16LE()
            let x = resource.stream!.readUInt16LE()
            let y = resource.stream!.readUInt16LE()
            
            maxSpriteIndex = spriteIndex
            
            let groupImage = SpriteAnimationImage(
                imageNumber: UInt16(spriteIndex),
                xOffset: Int16(x),
                yOffset: Int16(y)
            )
            
            group.images.append(groupImage)
        }

        var frame = SpriteAnimationFrame()
        frame.groups.append(group)
        animation.frames.append(frame)

        animations.append(animation)
        return animations
    }
    
    
    static func parseDeathAnimations(_ resource: Resource, animationOffset: UInt32) -> [SpriteAnimation] {
        let engine = DuneEngine.shared
        let blockSize = resource.stream!.readUInt16LE() // Block size
        
        if animationOffset + UInt32(blockSize) > resource.stream!.size {
            engine.logger.log(.error, "parseDeathAnimations(): ERROR - Offset and size are above the resource size. animationOffset=\(animationOffset), blockSize=\(blockSize), resourceSize=\(resource.stream!.size)")
            return []
        }
        
        let frameMaxIndexPerFile = [25, 21, 33]
        var spriteMaxIndex: UInt16 = 0

        var animations: [SpriteAnimation] = []
        
        var animation = SpriteAnimation()
        animation.x = 0
        animation.y = 0
        animation.width = 320
        animation.height = 200
        animation.definitionOffset = animationOffset
        
        var group = SpriteAnimationImageGroup()
        var lastWord: UInt16 = 0x0000
        
        while !resource.stream!.isEOF() {
            // End of frame
            if resource.stream!.readUInt16LE(peek: true) == 0xFFFF {
                lastWord = resource.stream!.readUInt16LE()
                
                if group.images.count == 0 && animation.frames.count > 0 {
                    let lastFrame = animation.frames.last!
                    animation.frames.append(lastFrame)
                    continue
                } else {
                    var frame = SpriteAnimationFrame()
                    frame.groups.append(group)
                    animation.frames.append(frame)
                    
                    group = SpriteAnimationImageGroup()
                }

                continue
            }
            
            
            if spriteMaxIndex > 0 && spriteMaxIndex == frameMaxIndexPerFile[animations.count] && lastWord == 0xFFFF {
                animations.append(animation)
                
                animation = SpriteAnimation()
                animation.x = 0
                animation.y = 0
                animation.width = 320
                animation.height = 200
                animation.definitionOffset = animationOffset
                
                spriteMaxIndex = 0
            }
            
            let spriteIndex = resource.stream!.readUInt16LE()
            let x = resource.stream!.readUInt16LE()
            let y = resource.stream!.readUInt16LE()
            
            spriteMaxIndex = max(spriteMaxIndex, spriteIndex)
            lastWord = y
            
            let groupImage = SpriteAnimationImage(
                imageNumber: UInt16(spriteIndex),
                xOffset: Int16(x),
                yOffset: Int16(y)
            )
            
            engine.logger.log(.debug, "parseDeathAnimations(): animation=\(animations.count) frame=\(animation.frames.count), index=\(spriteIndex), x=\(x), y=\(y)")
            
            group.images.append(groupImage)
        }

        animations.append(animation)
        return animations
    }
}
