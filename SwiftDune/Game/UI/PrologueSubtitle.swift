//
//  PrologueSubtitle.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 28/03/2024.
//

import Foundation


final class PrologueSubtitle: DuneNode {
    private let engine = DuneEngine.shared
    private var gameFont: GameFont?
    private var sentences: Sentence?
    private var sentenceNumber: UInt16 = 0
    private let textBoxRect = DuneRect(0, 152, 320, 48)
    
    init() {
        super.init("PrologueSubtitle")
    }
    
    
    override func onEnable() {
        gameFont = GameFont()
        sentences = Sentence(.command, language: .french)
    }
    
    
    override func onDisable() {
        gameFont = nil
        sentences = nil
        sentenceNumber = 0
    }
    
    
    override func onParamsChange() {
        if let sentenceNumberParam = params["sentenceNumber"] {
            self.sentenceNumber = UInt16(truncatingIfNeeded: (sentenceNumberParam as! Int))
        }
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let gameFont = gameFont,
              let sentences = sentences else {
            return
        }
        
        if sentenceNumber == 0 {
            return
        }
        
        let sentence = sentences.sentence(at: sentenceNumber)
        gameFont.paletteIndex = 25
        gameFont.render(sentence, rect: textBoxRect, buffer: buffer, alignment: .justify)
    }
}
