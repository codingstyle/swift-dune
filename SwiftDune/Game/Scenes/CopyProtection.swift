//
//  CopyProtection.swift
//  Dune
//
//  Created by Christophe Buguet on 31/08/2024.
//

import Foundation

final class CopyProtection: DuneNode {
    private let engine = DuneEngine.shared
    
    private var thumbnails: Video?
    private var sentences: Sentence?
    private var gameFont: GameFont?
    
    private var selectedFrameIndex: Int = 0
    private let textBoxRect = DuneRect(24, 150, 296, 20)
    private let thumbnailPosition = DunePoint(80, 35)
    private let paletteIndex: UInt8 = 6
    private let sentenceIndex: UInt16 = 229
    private var input: String = ""

    private let errorMessage = "Program aborted at the request of the protection comittee."
    private let manualPages: [UInt8] = [
        20, // Book (frame #0, page 20)
        11, // Worm (frame #1, page 11)
        24, // Vegetation (frame #2, page 24)
        13, // Harvester (frame #3, page 13)
        25, // Balcony (frame #4, page 25)
        27, // Stilgar+sietch (frame #5, page 27)
        17, // Sietch interior (frame #6, page 17)
        23, // Paul+Chani (frame #7, page 23)
        26, // Smuggler (frame #8, page 26)
        14, // Chani (frame #9, page 14)
        8,  // Gurney (frame #10, page 8)
        5,  // Stilgar+water (frame #11, page 5)
        21, // Armory (frame #12, page 21)
        29, // Village (frame #13, page 28)
        31, // Emperor (frame #14, page 31)
        30, // Harah (frame #15, page 30)
        16, // Arrakeen (frame #16, page 16)
        9,  // Liet (frame #17, page 9)
        19, // Sietch entrance (frame #18, page 19)
        28, // Map (frame #19, page 28)
        15, // Feyd (frame #20, page 15)
        22, // Leto (frame #21, page 22)
        12, // Jessica (frame #22, page 12)
        7,  // Baron (frame #23, page 7)
        18, // Duncan (frame #24, page 18)
        10, // Globe (frame #25, page 10)
        6,  // Desert (frame #26, page 6)
        4,  // Paul (frame #27, page 4)
        3,  // Palace (frame #28, page 3)
    ]
        
    init() {
        super.init("CopyProtection")
    }
    
    
    override func onEnable() {
        thumbnails = Video("PRT.HNM")
        sentences = Sentence(.command, language: .french)
        gameFont = GameFont()

        selectedFrameIndex = Math.random(0, 28)
        thumbnails?.setFrameIndex(selectedFrameIndex)
    }
    
    
    override func onDisable() {
        thumbnails = nil
        sentences = nil
        gameFont = nil
        selectedFrameIndex = 0
        input = ""
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let thumbnails = thumbnails,
              let sentences = sentences,
              let gameFont = gameFont else {
            return
        }
        
        let frame = thumbnails.frame(at: selectedFrameIndex)
        let frameWidth = frame.videoBlock!.width
        
        thumbnails.renderFrame(buffer, pt: thumbnailPosition)
        let text = sentences.sentence(at: sentenceIndex)
        
        gameFont.paletteIndex = paletteIndex
        gameFont.render("\(text) \(input)", rect: textBoxRect, buffer: buffer, alignment: .left)
    }
    
    
    override func onKey(_ event: DuneKeyEvent) {
        if !event.char.isEmpty && input.count < 2 {
            input.append(event.char)
        }
        
        if event.specialKey == .keyReturn && input.count > 0 {
            verifyInput()
        }
    }
    
    
    private func verifyInput() {
        let pageNumber = Int(input)!
        
        if manualPages[selectedFrameIndex] != pageNumber {
            engine.exitProgram(errorMessage)
            return
        }
        
        // User passed the protection, end node and switch to main game
        engine.sendEvent(self, .nodeEnded)
    }
}
