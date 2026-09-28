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
    
    convenience init(_ type: SentenceType, language: SentenceLanguage = .english) {
        let fileName = type.rawValue.replacingOccurrences(of: "x", with: "\(language.rawValue)")
        self.init(fileName)
    }
    
    init(_ fileName: String) {
        self.resource = Resource(fileName)
    }
    
    
    func sentenceCount() -> UInt16 {
        // The offset table's first entry, read from the start of the file
        // (reading at the current position ran past the end after a
        // sentence had been read: crash on the flat map's DUNE MAP box).
        resource.stream!.seek(0)
        let firstSentence = resource.stream!.readUInt16LE();
        resource.stream!.seek(0)
        return (firstSentence / 2)
    }
    
    
    /// The raw bytes of a sentence up to (not including) the 0xFF end.
    func rawBytes(at index: UInt16) -> [UInt8] {
        guard UInt32(index) < UInt32(sentenceCount()) else { return [] }
        resource.stream!.seek(UInt32(index) * 2)
        let start = resource.stream!.readUInt16LE()
        resource.stream!.seek(UInt32(start))
        var bytes: [UInt8] = []
        while !resource.stream!.isEOF() {
            let current = resource.stream!.readByte()
            if current == 0xFF { break }
            bytes.append(current)
        }
        return bytes
    }


    /// `printableOnly` drops carriage returns. It used to drop 0x2E as well,
    /// which removed every full stop from the dialogue.
    func sentence(at index: UInt16, printableOnly: Bool = false) -> String {
        resource.stream!.seek(UInt32(index) * 2)

        let start = resource.stream!.readUInt16LE()
        resource.stream!.seek(UInt32(start))

        var current: UInt8 = 0
        var bytes: [UInt8] = []
        
        while true {
            current = resource.stream!.readByte()
            
            if current == 0x0D && printableOnly {
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
