//
//  Sentence.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 27/08/2023.
//

import Foundation

enum SentenceType: String {
    case phrase1 = "PHRASEx1.HSQ"
    case phrase2 = "PHRASEx2.HSQ"
    case command = "COMMANDx.HSQ"
}

enum SentenceLanguage: Int {
    case english = 1
    case french = 2
    case german = 3
}



final class Sentence {
    private let engine = DuneEngine.shared
    private var resource: Resource
    
    convenience init(_ type: SentenceType, language: SentenceLanguage = .french) {
        let fileName = type.rawValue.replacingOccurrences(of: "x", with: "\(language.rawValue)")
        self.init(fileName)
    }
    
    init(_ fileName: String) {
        self.resource = Resource(fileName)
    }
    
    
    func sentenceCount() -> UInt16 {
        let firstSentence = resource.stream!.readUInt16LE();
        resource.stream!.seek(0)
        return (firstSentence / 2)
    }
    
    
    func sentence(at index: UInt16, printableOnly: Bool = false) -> String {
        resource.stream!.seek(UInt32(index) * 2)

        let start = resource.stream!.readUInt16LE()
        resource.stream!.seek(UInt32(start))

        var current: UInt8 = 0
        var bytes: [UInt8] = []
        
        while true {
            current = resource.stream!.readByte()
            
            if (current == 0x2E || current == 0x0D) && printableOnly {
                continue
            }
            
            if current == 0xFF {
                break
            }
            
            bytes.append(current)
        }
        
        return String(bytes: bytes, encoding: .isoLatin1)!
    }
    
    
    func dumpInfo() {
        let count = sentenceCount()
        
        for i in 0..<count {
            let s = sentence(at: i)
            engine.logger.log(.debug, "Sentence #\(i): \(s)")
        }
    }
}
