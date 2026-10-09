//
//  Book.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 24/08/2024.
//

import Foundation

enum BookTopic: UInt16 {
    case allTopics = 214
    case politics = 215
    case paulOnDune = 216
    case spice = 217
    case fremen = 218
}


struct BookChapter {
    var topic: BookTopic
    var enabled: Bool
    var pages: [UInt16]
  
  init(_ topic: BookTopic, _ enabled: Bool, _ pages: [UInt16]) {
    self.topic = topic
    self.enabled = enabled
    self.pages = pages
  }
}


final class Book: DuneNode {
    private var currentPageBuffer = PixelBuffer(width: 320, height: 152)
    private var previousPageBuffer = PixelBuffer(width: 320, height: 152)
    private var bookSprite: Sprite?
    private var flipSound: Sound?
    private var font: GameFont?
    private var commands: Sentence?
    private var phrases: Sentence?
    private var credits: Credits?
    
    // BOOK.HSQ sprites 5...13, in this letter order.
    private static let dropCapLetters: [UInt8] = [0x41, 0x44, 0x45, 0x4C, 0x4F, 0x50, 0x53, 0x54, 0x55]
    private static let dropCapWidths: [Int] = [33, 30, 28, 33, 25, 24, 24, 23, 31]
    private let bookTextColor: UInt8 = 0x64
    private let bookFrameColor: UInt8 = 0x53
  
    // TODO: enable only the pages depending on game state progress
    private let bookChapters: [BookChapter] = [
      BookChapter(.politics, true, [ 421, 426, 428, 429 ] ),
      BookChapter(.paulOnDune, true, [ 422, 427, 433 ] ),
      BookChapter(.spice, true, [ 424, 425, 430 ]),
      BookChapter(.fremen, false, [ 423, 431, 432 ])
    ]

    private let menuItemsBook: [BookTopic] = [.allTopics, .politics, .paulOnDune, .spice, .fremen]

    private let pageFlipDuration = 1.0
    private var animationStartTime = 0.0
    private var flipping = false
    private var flipForward = true
  
    private var renderedPageIndex = -1
    private var pageIndex = 0
    
    init() {
        super.init("Book")
    }
    
    
    override func onEnable() {
        bookSprite = Sprite("BOOK.HSQ")
        flipSound = Sound("SD2.HSQ", player: engine.audioPlayer)
        font = GameFont()
        commands = Sentence(.command)
        phrases = Sentence(.phrase2)
        credits = Credits()

        EventManager.uiStateChangedEvent.notify(UIStateEventData(
          items: menuItemsBook.map({ topic in
            topic.rawValue
          })
        ))
      
        EventManager.bookStateChangedEvent.addListener(self) { event in
            if event.action == .turnPageLeft && self.pageIndex > 0 {
                self.beginPageTurn(forward: false)
            }
          
            if event.action == .turnPageRight {
                self.beginPageTurn(forward: true)
            }
        }
    }
    
    
    override func onDisable() {
        EventManager.bookStateChangedEvent.removeListener(self)
      
        credits = nil
        bookSprite = nil
        flipSound = nil
        font = nil
        commands = nil
        currentPageBuffer.clearBuffer()
        previousPageBuffer.clearBuffer()
        flipping = false
        renderedPageIndex = -1
        pageIndex = 0
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        if currentTime == 0.0 {
            let music = Music("WATER.HSQ", player: engine.audioPlayer)
            engine.audioPlayer.play(music, loop: true)
        }
      
        if pageIndex == 1 {
            if !credits!.isActive {
                credits!.embedded = true
                credits!.onEnable()
                credits!.isActive = true
            }
      
            credits!.update(elapsedTime)
        } else {
            if credits!.isActive {
                credits!.isActive = false
                credits!.onDisable()
            }
        }
      
        currentTime += elapsedTime
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        prerenderCurrentPage()

        if flipping && currentTime - animationStartTime >= pageFlipDuration {
            flipping = false
        }
      
        if flipping {
            let effect: SpriteEffect = flipForward
                ? .pageFlip(start: animationStartTime, duration: pageFlipDuration, current: currentTime)
                : .pageFlipBack(start: animationStartTime, duration: pageFlipDuration, current: currentTime)
            currentPageBuffer.render(to: buffer, effect: effect, previous: previousPageBuffer)
        } else {
          currentPageBuffer.render(to: buffer, effect: .none)
        }
    }
  
  
    private func getAllPages() -> [UInt16] {
        var pages: [UInt16] = [0]
        var i = 0
      
        while i < bookChapters.count {
            var j = 0
          
            while j < bookChapters[i].pages.count {
                pages.append(bookChapters[i].pages[j])
                j += 1
            }
          
            i += 1
        }
      
        pages.append(1)
      
        return pages
    }


    private func beginPageTurn(forward: Bool) {
        guard !flipping else {
            return
        }
      
        let pages = getAllPages()
        let index = Int(pages.firstIndex(of: UInt16(truncatingIfNeeded: pageIndex))!)
      
        if forward && index < pages.count - 1 {
            pageIndex = Int(pages[index + 1])
        } else if index > 0 && !forward {
            pageIndex = Int(pages[index - 1])
        } else {
            pageIndex = forward ? 1 : 0
            return
        }

        guard let flipSound = flipSound else {
          return
        }
  
        flipSound.play()
      
        previousPageBuffer.copyPixels(from: currentPageBuffer)
        flipForward = forward
        animationStartTime = currentTime
        flipping = true
    }


    private func prerenderCurrentPage() {
        guard renderedPageIndex != pageIndex || pageIndex == 1 else {
            return
        }

        if pageIndex == 0 {
            renderCover(currentPageBuffer)
        } else if pageIndex == 1 {
            renderCredits(currentPageBuffer)
        } else {
            renderPage(currentPageBuffer)
        }

        renderedPageIndex = pageIndex
    }
    

    private func renderCover(_ buffer: PixelBuffer) {
        guard let bookSprite = bookSprite else {
            return
        }
        
        bookSprite.setPalette()
        buffer.clearBuffer()

        bookSprite.drawFrame(0, x: 0, y: 0, buffer: buffer)
        bookSprite.drawFrame(1, x: 0, y: 0, buffer: buffer)
        bookSprite.drawFrame(2, x: 0, y: 0, buffer: buffer)
    }
  
  
    private func renderCredits(_ buffer: PixelBuffer) {
        guard let credits = credits else {
          return
        }

        credits.render(buffer)
    }
    
    
    private func renderPage(_ buffer: PixelBuffer) {
      guard let bookSprite = bookSprite,
            let phrases = phrases,
            let font = font,
            let commands = commands else {
            return
        }
      
        let pageSentence = phrases.sentence(at: UInt16(truncatingIfNeeded: pageIndex))
        
        bookSprite.setPalette()
        buffer.clearBuffer()
        
      
        // Page background
        var y: Int16 = 0
        
        while y < 152 {
            var x: Int16 = 0
            
            while x < 320 {
                bookSprite.drawFrame(3, x: x, y: y, buffer: buffer)
                x += 33
            }
            
            y += 29
        }
        
        // Page text. The first letter is a BOOK.HSQ drop cap when one exists.
        font.paletteIndex = bookTextColor
        let textRect = DuneRect(60, 10, 200, 132)
        let cap = dropCap(for: pageSentence.first!.asciiValue!)
        let body = cap == nil ? pageSentence : String(pageSentence.dropFirst())
        let textLayout = font.render(body, rect: textRect, buffer: buffer, firstLineIndent: cap?.width ?? 0)

        if let cap = cap {
            let spriteY = max(0, textLayout.firstLineY - 0x13)
            bookSprite.drawFrame(cap.frame, x: textRect.x, y: Int16(spriteY), buffer: buffer)
        }

        let endY = textLayout.lastLineY
      
        // Page frame
        let frameColor = Int(bookFrameColor)
        Primitives.drawLine(DunePoint(0, 0), DunePoint(319, 0), frameColor, buffer, isOffset: false)
        Primitives.drawLine(DunePoint(0, 0), DunePoint(0, 151), frameColor, buffer, isOffset: false)
        Primitives.drawLine(DunePoint(319, 0), DunePoint(319, 151), frameColor, buffer, isOffset: false)
        Primitives.drawLine(DunePoint(0, 151), DunePoint(319, 151), frameColor, buffer, isOffset: false)

        // Flourish decoration
        let flourishY = endY + ((0x8C - endY) / 2)
      
        if flourishY < 0x8A {
            bookSprite.drawFrame(4, x: 147, y: Int16(flourishY), buffer: buffer)
        }

        // Page number
        var pageNumber = 0
        var topicNumber = BookTopic.allTopics.rawValue
        var i = 0
      
        while i < bookChapters.count {
          let pages = bookChapters[i].pages
          var j = 0
          
          while j < pages.count {
            if pages[j] == pageIndex {
                pageNumber = j + 1
                topicNumber = bookChapters[i].topic.rawValue + 32
                break
            }
            
            j += 1
          }
          
          if pageNumber > 0 {
            break
          }
          
          i += 1
        }
  
        // Draw page number
        font.paletteIndex = bookFrameColor
        font.render("\(pageNumber)", rect: DuneRect(306, 3, 14, 9), buffer: buffer, alignment: .left, style: .small)

        // Draw current topic
        if pageNumber > 1 {
          let topic = commands.sentence(at: topicNumber)
          font.paletteIndex = bookTextColor
          font.render(topic, rect: DuneRect(250, 139, 70, 13), buffer: buffer)
        }

    }

  
    private func dropCap(for ascii: UInt8) -> (frame: UInt16, width: Int)? {
        var i = 0

        while i < Self.dropCapLetters.count {
            if Self.dropCapLetters[i] == ascii {
                return (UInt16(5 + i), Self.dropCapWidths[i])
            }

            i += 1
        }

        return nil
    }
}


enum BookAction: Equatable {
  case turnPageLeft
  case turnPageRight
  case topic(_ topic: BookTopic)
  case close
}


struct BookStateEventData {
  var action: BookAction
}


extension EventManager {
    static let bookStateChangedEvent = DuneEvent<BookStateEventData>()
}
