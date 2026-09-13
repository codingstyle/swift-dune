//
//  Attack.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 08/05/2024.
//

import Foundation

struct AttackParticle {
    var position: DunePoint = .zero
    var width: UInt16 = 0
    var height: UInt16 = 0
    var spriteId: UInt16 = 0
    var velocity: DunePoint = .zero
    var flags: UInt8 = 0
    var accumX: UInt8 = 0
    var accumY: UInt8 = 0
}


private struct AttackTimer<T: FixedWidthInteger> {
    var value: T
    let limit: T
    
    mutating func tick() -> Bool {
        value = value &- 1
        return triggered
    }
    
    var triggered: Bool {
        return value < limit
    }
}


final class Attack: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    private var attackSprite: Sprite?
    
    private var transitionIn: TransitionEffect = .none
    private var transitionOut: TransitionEffect = .none
    
    private var rngSeed: UInt32 = 0x01d2
    private var maskedRngSeed: UInt32 = 0x0273
    private var randomBits: UInt16 = 0x7302
    
    private var tickAccumulator: TimeInterval = 0.0
    
    private let maskedLcgPrime: UInt32 = 0x0E56D
    private let lcgPrime: UInt32 = 0xCBD1

    private var timer0 = AttackTimer<Int8>(value: 0, limit: 0)
    private var timer1 = AttackTimer<Int8>(value: 0, limit: 0)
    private var burstLo: UInt8 = 0
    private var burstHi: UInt8 = 0
    private var timer4 = AttackTimer<Int16>(value: 0, limit: 0)
    private var timer6 = AttackTimer<Int8>(value: 0, limit: 0)
    private var timer7 = AttackTimer<Int8>(value: 0, limit: 17)
    
    private var isMassiveAttack: UInt8 = 0
    
    private let maxAttackParticles = 64
    private var particleCount = 0
    private var particles: [AttackParticle] = []

    private let skyPaletteStart = 128
    private let skyPaletteCount = 28

    private var skyPalette: [UInt32] = []
    private var skyTargetPalette: [UInt32] = []
    private var flashPalette53: [UInt32] = []
    private var flashPalette54: [UInt32] = []
    private var flashPalette55: [UInt32] = []
  
    private let firstAirBombSpriteId: UInt16 = 28
    
    // DOS installs the particle task with add_frame_task(interval: 3) on the 200Hz
    // PIT, so it ticks at ~66.8Hz instead of once per rendered frame.
    private let attackTickInterval: TimeInterval = 3.0 * 0.00499253 // (pitTickDuration = 0.00499253)
    private let maxAttackTicksPerFrame = 4
    
    private let initialParticlePositions: [DunePoint] = [
        DunePoint(125, 101),
        DunePoint(100, 101),
        DunePoint(239, 122),
        DunePoint(271, 125)
    ]
    
    private let initialParticleVelocities: [DunePoint] = [
        DunePoint(-6, 4),
        DunePoint(-4, 6),
        DunePoint(-4, -6),
        DunePoint(-6, -4)
    ]
    
    init() {
        super.init("Attack")
    }

    
    override func onEnable() {
        attackSprite = Sprite("ATTACK.HSQ")
        attackSprite?.setPalette()
        engine.palette.stash()
      
        particles = [AttackParticle](repeating: AttackParticle(), count: maxAttackParticles)
        skyPalette = [UInt32](repeating: 0, count: skyPaletteCount)
        skyTargetPalette = [UInt32](repeating: 0, count: skyPaletteCount)
        flashPalette53 = [UInt32](repeating: 0, count: skyPaletteCount)
        flashPalette54 = [UInt32](repeating: 0, count: skyPaletteCount)
        flashPalette55 = [UInt32](repeating: 0, count: skyPaletteCount)
      
        loadFlashPalettes()
        captureSkyPalette()
        resetSimulation()
    }
    
    
    override func onDisable() {
        attackSprite = nil
        currentTime = 0.0
        transitionIn = .none
        transitionOut = .none
        isMassiveAttack = 0

        particles = []
        skyPalette = []
        skyTargetPalette = []
        flashPalette53 = []
        flashPalette54 = []
        flashPalette55 = []
        
        resetSimulation()
    }
    
    override func onParamsChange() {
        if let transitionInParam = params["transitionIn"] {
            self.transitionIn = transitionInParam as! TransitionEffect
        }

        if let transitionOutParam = params["transitionOut"] {
            self.transitionOut = transitionOutParam as! TransitionEffect
        }
        
        if let massiveAttack = params["massiveAttack"] {
            self.isMassiveAttack = (massiveAttack as! Bool) ? 1 : 0
        }
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        tickAccumulator += elapsedTime
        
        var ticks = 0
        
        while tickAccumulator >= attackTickInterval && ticks < maxAttackTicksPerFrame {
            stepFrame()
            tickAccumulator -= attackTickInterval
            ticks += 1
        }
        
        if currentTime > duration {
            EventManager.nodeEndedEvent.notify(NodeEventData(self.name))
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard attackSprite != nil else {
            return
        }
        
        applySkyPalette()
        drawBackground()
        drawParticles()
        
        var fx: SpriteEffect {
            if currentTime < 2.0 {
                switch transitionIn {
                case .dissolveIn(let fxDuration):
                    return .dissolveIn(start: 0.0, duration: fxDuration, current: currentTime)
                default:
                    return .none
                }
            }
            
            if currentTime > duration - 2.0 {
                switch transitionOut {
                case .dissolveOut(let fxDuration):
                    return .dissolveOut(end: duration, duration: fxDuration, current: currentTime)
                default:
                    return .none
                }
            }
            
            return .none
        }
        
        contextBuffer.render(to: buffer, effect: fx)
    }
    
    
    private func resetSimulation() {
        rngSeed = 0x01d2
        maskedRngSeed = 0x0273
        randomBits = 0x7302
        tickAccumulator = 0.0
        timer0 = AttackTimer<Int8>(value: 0, limit: 0)
        timer1 = AttackTimer<Int8>(value: 0, limit: 0)
        burstLo = 0
        burstHi = 0
        timer4 = AttackTimer<Int16>(value: 0, limit: 0)
        timer6 = AttackTimer<Int8>(value: 0, limit: 0)
        timer7 = AttackTimer<Int8>(value: 0, limit: 17)
        particleCount = 0
        
        var i = 0
        while i < maxAttackParticles {
            particles[i] = AttackParticle()
            i += 1
        }
    }
    
    
    private func loadFlashPalettes() {
        copyFlashPalette(53, into: &flashPalette53)
        copyFlashPalette(54, into: &flashPalette54)
        copyFlashPalette(55, into: &flashPalette55)
    }
    
    
    private func copyFlashPalette(_ resourceIndex: Int, into destination: inout [UInt32]) {
        guard let chunk = attackSprite?.paletteChunk(atResource: resourceIndex) else {
            return
        }
        
        var i = 0
        let count = min(skyPaletteCount, chunk.count)
        
        while i < count {
            destination[i] = chunk.chunk[i]
            i += 1
        }
    }
    
    
    private func captureSkyPalette() {
        var i = 0
        
        while i < skyPaletteCount {
            let color = engine.palette.rawPointer[skyPaletteStart + i]
            skyPalette[i] = color
            skyTargetPalette[i] = color
            i += 1
        }
    }
    
    
    private func applySkyPalette() {
        var i = 0
        
        while i < skyPaletteCount {
            engine.palette.rawPointer[skyPaletteStart + i] = skyPalette[i]
            i += 1
        }
    }
    
    
    private func drawBackground() {
        guard let attackSprite = attackSprite else {
            return
        }
        
        contextBuffer.clearBuffer()
        
        var x: Int16 = 0
        
        while x < 320 {
            attackSprite.drawFrame(2, x: x, y: 0, buffer: contextBuffer)
            attackSprite.drawFrame(3, x: x, y: 81, buffer: contextBuffer)
            x += 40
        }

        attackSprite.drawFrame(49, x: 0, y: 76, buffer: contextBuffer)
        attackSprite.drawFrame(1, x: 0, y: 134, buffer: contextBuffer)
    }
    
    
    private func drawParticles() {
        guard let attackSprite = attackSprite else {
            return
        }
        
        var i = 0
        
        while i < particleCount {
            let particle = particles[i]
            
            if (particle.flags & 0x80) == 0 && Int(particle.spriteId) < attackSprite.frameCount {
                attackSprite.drawFrame(particle.spriteId, x: particle.position.x, y: particle.position.y, buffer: contextBuffer)
            }
            
            i += 1
        }
    }
    
    
    private func maskedRandomNumber(_ mask: UInt16) -> UInt16 {
        let product = rngSeed &* maskedLcgPrime &+ 1
        rngSeed = product
        
        return UInt16(truncatingIfNeeded: (product >> 8)) & mask
    }
    
    
    private func randomNumber() -> UInt16 {
        let product = maskedRngSeed &* lcgPrime &+ 1
        maskedRngSeed = product
        
        return UInt16(truncatingIfNeeded: (product >> 8))
    }
    
    
    private func rotateRandomBits(_ count: Int) {
        randomBits = (randomBits &<< count) | (randomBits &>> (16 - count))
    }
    
    
    private func stepFrame() {
        _ = timer7.tick()
        
        if timer7.triggered {
            updateSkyFlash(timer7.value == 16)
        }
        
        if timer4.tick() {
            if timer6.tick() {
                let randomVal = randomNumber()
                timer6.value = Int8(truncatingIfNeeded: randomVal & 0x7F)
                timer4.value = Int16(randomVal >> 8)
            } else {
                let randomVal = randomNumber()
                let x = Int16(((randomVal & 0x80) << 1) | (randomVal >> 8))
                let y = Int16(randomVal & 0x7F)
                
                if y >= 48 && y < 96 && x < 320 {
                    let spriteId = firstAirBombSpriteId &+ (UInt16(y) % 8)
                    spawnParticle(spriteId, at: DunePoint(x, y), velocity: .zero)
                }
            }
        }
        
        if timer0.tick() {
            spawnAttackParticle()
        }
        
        if particleCount == 0 {
            return
        }
        
        let count = particleCount
        var i = 0
        
        while i < count {
            updateParticle(&i)
        }
    }
    
    
    private func spawnAttackParticle() {
        if timer1.tick() {
            if (randomBits & 3) == 0 {
                timer7.value = 11
                
                if (randomBits & 0x0C) == 0 {
                    timer7.value = 17
                }
            }
            
            var ax = randomNumber()
            
            if isMassiveAttack != 0 {
                ax &= 0xFFEF
            }
            
            var cx = ax
            let masked = maskedRandomNumber(7)
            timer1.value = Int8(truncatingIfNeeded: masked & 0xFF)
            
            if (masked & 0xFF) >= 4 {
                cx |= 0x4000
            }
            
            burstLo = UInt8(truncatingIfNeeded: cx)
            burstHi = UInt8(truncatingIfNeeded: cx >> 8)
        }
        
        timer0.value = 8
        
        if (burstLo & 0x10) == 0 {
            let index = Int((burstHi & 6) >> 1)
            finishSpawn(
                spriteId: (UInt16(index) + 1) * 4,
                originPacked: UInt16(burstLo),
                velocity: initialParticleVelocities[index]
            )
        } else {
            var al = burstHi & 0x3F
            var ah = burstHi & 0xC0
            
            if (ah & 0x40) != 0 {
                rotateRandomBits(1)
                
                if (randomBits & 1) != 0 {
                    var cl: UInt8 = 0x0A
                    
                    if (ah & 0x80) != 0 {
                        cl = 0 &- cl
                    }
                    
                    al = al &+ cl
                    
                    if (al & 0x80) != 0 {
                        ah ^= 0x80
                        al = 0
                    }
                    
                    if al >= 0x40 {
                        al = 0x3F
                        ah ^= 0x80
                    }
                    
                    ah |= al
                    burstHi = ah
                }
            }
            
            al = al &+ 0xE0
            finishSpawn(spriteId: 0x14, originPacked: UInt16(burstLo), velocity: travelHeadingDeltas(al))
        }
    }
    
    
    private func finishSpawn(spriteId: UInt16, originPacked: UInt16, velocity: DunePoint) {
        let origin = Int((originPacked & 0x0C) >> 2)
        let position = initialParticlePositions[origin]
        
        if spawnParticle(spriteId, at: position, velocity: velocity) {
            particles[particleCount - 1].accumX = 0
            particles[particleCount - 1].accumY = 0
        }
    }
    
    
    @discardableResult
    private func spawnParticle(_ spriteId: UInt16, at center: DunePoint, velocity: DunePoint) -> Bool {
        guard let attackSprite = attackSprite else {
            return false
        }
        
        if particleCount >= maxAttackParticles || Int(spriteId) >= attackSprite.frameCount {
            return false
        }
        
        let frame = attackSprite.frame(at: Int(spriteId))
        let x = saturatingSub(center.x, frame.width / 2)
        let y = saturatingSub(center.y, frame.height / 2)
        
        particles[particleCount] = AttackParticle(
            position: DunePoint(x, y),
            width: frame.width,
            height: frame.height,
            spriteId: spriteId,
            velocity: velocity,
            flags: 0,
            accumX: 0,
            accumY: 0
        )
        particleCount += 1
        
        return true
    }
    
    
    private func removeParticle(_ index: Int) {
        if particleCount == 0 || index >= particleCount {
            return
        }
        
        particles[index].flags |= 0x80
        
        if index < particleCount - 1 {
            var i = index
            
            while i < particleCount - 1 {
                particles[i] = particles[i + 1]
                i += 1
            }
        }
        
        particleCount -= 1
    }
    
    
    private func moveParticle(_ index: Int, delta: DunePoint) {
        particles[index].position.x = particles[index].position.x &+ delta.x
        particles[index].position.y = particles[index].position.y &+ delta.y
    }
    
    
    private func saturatingSub(_ value: Int16, _ amount: UInt16) -> Int16 {
        let result = Int32(value) - Int32(amount)
        
        if result < Int32(Int16.min) {
            return Int16.min
        }
        
        return Int16(result)
    }
    
    
    private func updateParticle(_ index: inout Int) {
        var spriteId = particles[index].spriteId
        var velocity = particles[index].velocity
        let lo = spriteId & 0xFF
        
        if lo < 0x14 {
            spriteId >>= 2
            rotateRandomBits(1)
            spriteId = (spriteId &<< 1) | (randomBits & 1)
            rotateRandomBits(1)
            spriteId = (spriteId &<< 1) | (randomBits & 1)
        } else if lo < 0x1C {
            var accumX = Int8(bitPattern: particles[index].accumX)
            var accumY = Int8(bitPattern: particles[index].accumY)
            var vx = Int8(truncatingIfNeeded: velocity.x)
            var vy = Int8(truncatingIfNeeded: velocity.y)
            
            (accumX, vy) = stepAxis(accumX, velocity: vy)
            (accumY, vx) = stepAxis(accumY, velocity: vx)
            
            particles[index].accumX = UInt8(bitPattern: accumX)
            particles[index].accumY = UInt8(bitPattern: accumY)
            
            // vx/vy now hold this tick's pixel step. The particle keeps its
            // heading velocity, otherwise the accumulator has nothing to add.
            velocity = DunePoint(Int16(vx), Int16(vy))
            
            rotateRandomBits(3)
            spriteId = (randomBits & 7) + 0x14
        } else {
            spriteId = spriteId &+ 1
            
            if (spriteId & 0xFF) > 0x2D {
                removeParticle(index)
                index += 1
                return
            }
        }
        
        particles[index].spriteId = spriteId
        
        // DOS troop_icon_move_and_redraw(dx=velocity.y, bx=velocity.x)
        moveParticle(index, delta: DunePoint(velocity.y, velocity.x))
        
        let particle = particles[index]
        let right = particle.position.x &+ Int16(bitPattern: particle.width)
        let bottom = particle.position.y &+ Int16(truncatingIfNeeded: particle.height)
        
        var shouldRemove = UInt16(bitPattern: particle.position.x) >= 320
        if !shouldRemove {
            shouldRemove = right < 0
        }
        if !shouldRemove {
            shouldRemove = bottom < 0
        }
        
        if shouldRemove {
            removeParticle(index)
        }
        
        index += 1
    }
    
    
    private func stepAxis(_ accum: Int8, velocity: Int8) -> (Int8, Int8) {
        let (newAccum, step) = stepAxisAccumulate(accum, magnitude: velocity.magnitude)
        
        if velocity < 0 {
            return (newAccum, 0 &- step)
        }
        
        return (newAccum, step)
    }
    
    
    private func stepAxisAccumulate(_ accum: Int8, magnitude: UInt8) -> (Int8, Int8) {
        let sum = UInt16(magnitude &+ UInt8(bitPattern: accum))
        let rotated = (sum &>> 5) | (sum &<< 11)
        let newAccum = Int8(truncatingIfNeeded: rotated >> 11)
        let step = Int8(truncatingIfNeeded: rotated)
        
        return (newAccum, step)
    }
    
    
    private func travelHeadingDeltas(_ value: UInt8) -> DunePoint {
        let bl = value &+ 0x20
        let bh = bl & 0x7F
        
        var bx: UInt16
        var dx: Int16
        
        if bh < 0x40 {
            bx = 0xFFE0
            
            if Int8(bitPattern: bl) >= 0 {
                dx = Int16(Int8(bitPattern: value))
            } else {
                var al = value &- 0x80
                al = 0 &- al
                bx = UInt16(bitPattern: 0 &- Int16(bitPattern: bx))
                dx = Int16(Int8(bitPattern: al))
            }
        } else {
            dx = 0x20
            var al = value &- 0x40
            
            if Int8(bitPattern: bl) < 0 {
                dx = 0 &- dx
                al = al &- 0x80
                al = 0 &- al
            }
            
            bx = UInt16(bitPattern: Int16(Int8(bitPattern: al)))
        }
        
        let v0 = Int8(bitPattern: UInt8(truncatingIfNeeded: bx))
        let v1 = Int8(bitPattern: UInt8(truncatingIfNeeded: UInt16(bitPattern: dx)))
        
        return DunePoint(Int16(v0), Int16(v1))
    }
    
    
    private func updateSkyFlash(_ loadBrightPalette: Bool) {
        if !loadBrightPalette && timer7.value != 10 {
            lerpSkyPalette()
            return
        }
        
        if loadBrightPalette {
            copyColors(flashPalette55, into: &skyPalette)
        } else {
            copyColors(flashPalette54, into: &skyPalette)
        }
        
        copyColors(flashPalette53, into: &skyTargetPalette)
        applySkyPalette()
    }
    
    
    private func lerpSkyPalette() {
        let divisor = Int16(max(timer7.value, 1))
        var i = 0
        
        while i < skyPaletteCount {
            skyPalette[i] = lerpColor(skyPalette[i], skyTargetPalette[i], divisor: divisor)
            i += 1
        }
        
        applySkyPalette()
    }
    
    
    private func copyColors(_ source: [UInt32], into destination: inout [UInt32]) {
        var i = 0
        
        while i < skyPaletteCount {
            destination[i] = source[i]
            i += 1
        }
    }
    
    
    private func lerpColor(_ from: UInt32, _ to: UInt32, divisor: Int16) -> UInt32 {
        let r = lerpChannel(from & 0xFF, to & 0xFF, divisor: divisor)
        let g = lerpChannel((from >> 8) & 0xFF, (to >> 8) & 0xFF, divisor: divisor)
        let b = lerpChannel((from >> 16) & 0xFF, (to >> 16) & 0xFF, divisor: divisor)
        
        return 0xFF000000 | (b << 16) | (g << 8) | r
    }
    
    
    private func lerpChannel(_ from: UInt32, _ to: UInt32, divisor: Int16) -> UInt32 {
        let from6 = Int16(from >> 2)
        let to6 = Int16(to >> 2)
        let mixed = from6 + (to6 - from6) / divisor
        
        return UInt32(clamping: mixed << 2)
    }
}
