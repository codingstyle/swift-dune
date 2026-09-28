//
//  Book.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 24/08/2024.
//

import Foundation

enum BookTopic {
    case politics
    case paulOnDune
    case spice
    case fremen
}

enum BookMenuAction {
    case handled
    case close
}


struct BookChapter {
    var topic: BookTopic
    var name: String
    var enabled: Bool
}


struct BookPage {
    var number: UInt8
    var content: String
    var firstLetter: String
}


/*
 
 PHRASEx2.HSQ -> 421-433
 COMMANDx.HSQ -> 214-218
 
 Letters (starting at frame 4)
 A, D, E, L, O, P, S, T, U
 
 */


final class Book: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    private var bookSprite: Sprite?
    private var font: GameFont?
    private var phraseBank: Sentence?
    private var pageOpen = false
    private var selectedTopic = 0
    
    // COMMAND1.HSQ stores these at the compact Swift sentence indices below.
    // They correspond to dune-re-ref's 0xe3/0xe5/0xe6/0xe7/0xe4 records:
    // ALL TOPICS, PAUL ON DUNE, SPICE, THE FREMEN, CLOSE BOOK.
    private let menuItemsBook: [UInt16] = [214, 216, 217, 218, 215]
    
    init() {
        super.init("Book")
    }
    
    
    override func onEnable() {
        bookSprite = Sprite("BOOK.HSQ")
        font = GameFont()
        // The first Leto conversation is in PHRASE11.HSQ.  Keep this tied to
        // the binary phrase-bank index used by dune-re-ref (0x81f -> entry
        // 0x1e after the DOS one-based lookup), rather than inventing book
        // text in the Swift layer.
        phraseBank = Sentence(.phrase1, language: .english)
        pageOpen = false
        selectedTopic = 0
        contextBuffer.tag = 0
    }
    
    
    override func onDisable() {
        bookSprite = nil
        font = nil
        phraseBank = nil
        pageOpen = false
        contextBuffer.tag = 0
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        EventManager.uiStateChangedEvent.notify(UIStateEventData(
            leftPanel: .bookOpen,
            rightPanel: .rect,
            items: menuItemsBook,
            day: GameState.shared.day,
            phase: GameState.shared.phase
        ))
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        if pageOpen {
            renderPage(buffer)
        } else {
            renderCover(buffer)
        }
    }
    

    private func renderCover(_ buffer: PixelBuffer) {
        guard let bookSprite = bookSprite else {
            return
        }
        
        bookSprite.setPalette()

        if contextBuffer.tag != 0x01 {
            contextBuffer.clearBuffer()

            bookSprite.drawFrame(0, x: 0, y: 0, buffer: contextBuffer)
            bookSprite.drawFrame(1, x: 0, y: 0, buffer: contextBuffer)
            bookSprite.drawFrame(2, x: 0, y: 0, buffer: contextBuffer)

            contextBuffer.tag = 0x01
        }
        
        contextBuffer.render(to: buffer, effect: .none)
    }
    
    
    private func renderPage(/*_ page: BookPage, */_ buffer: PixelBuffer) {
        guard let bookSprite = bookSprite else {
            return
        }
        
        bookSprite.setPalette()

        if contextBuffer.tag != 0x02 {
            contextBuffer.clearBuffer()
            
            var y: Int16 = 0
            
            while y < 152 {
                var x: Int16 = 0
                
                while x < 320 {
                    bookSprite.drawFrame(3, x: x, y: y, buffer: contextBuffer)
                    x += 33
                }
                
                y += 29
            }
            
            Primitives.drawLine(DunePoint(0, 0), DunePoint(319, 0), 94, contextBuffer, isOffset: false)
            Primitives.drawLine(DunePoint(0, 0), DunePoint(0, 151), 94, contextBuffer, isOffset: false)
            Primitives.drawLine(DunePoint(319, 0), DunePoint(319, 151), 94, contextBuffer, isOffset: false)
            Primitives.drawLine(DunePoint(0, 151), DunePoint(319, 151), 94, contextBuffer, isOffset: false)

            contextBuffer.tag = 0x02
        }

        if let font = font, let phraseBank = phraseBank {
            font.paletteIndex = 0x64
            let heading: String
            switch selectedTopic {
            case 1:
                heading = "PAUL ON DUNE"
            case 2:
                heading = "SPICE"
            case 3:
                heading = "THE FREMEN"
            default:
                heading = "DUKE LETO ATREIDES"
            }
            font.render(heading, rect: DuneRect(32, 8, 256, 12), buffer: contextBuffer, alignment: .center, style: .small)

            let text = GameText.shared.phrase(30).replacingOccurrences(of: "\u{FE}", with: " ")
            font.render(text, rect: DuneRect(28, 30, 264, 82), buffer: contextBuffer, alignment: .left, style: .small)
            font.render("PAGE 1", rect: DuneRect(270, 134, 36, 10), buffer: contextBuffer, alignment: .center, style: .small)
        }
        
        contextBuffer.render(to: buffer, effect: .none)
    }


    func menuAction(for event: DuneMouseClickEvent) -> BookMenuAction? {
        let point = event.point

        if pageOpen {
            if point.y < 152 && point.x >= 250 {
                return .handled
            }
            if point.y < 152 && point.x < 70 {
                return .handled
            }
        }

        guard point.x >= 92 && point.x < 228 && point.y >= 159 && point.y < 199 else {
            return nil
        }

        let index = Int((point.y - 159) / 8)
        if index == 4 {
            return .close
        }

        guard index >= 0 && index < 4 else {
            return .handled
        }

        selectedTopic = index
        pageOpen = true
        contextBuffer.tag = 0
        return .handled
    }
}
