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
    private var resource: Resource
    private let language: SentenceLanguage
    
    convenience init(_ type: SentenceType, language: SentenceLanguage = .french) {
        let fileName = type.rawValue.replacingOccurrences(of: "x", with: "\(language.rawValue)")
        self.init(fileName, language: language)
    }
    
    init(_ fileName: String, language: SentenceLanguage = .french) {
        self.resource = Resource(fileName)
        self.language = language
    }
    
    
    func sentenceCount() -> UInt16 {
        resource.stream!.seek(0)
        let firstSentence = resource.stream!.readUInt16LE();
        return (firstSentence / 2)
    }
    
    
    func sentence(at index: UInt16, printableOnly: Bool = false, convertSpecialChars: Bool = false) -> String {
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
        
        let str = String(bytes: bytes, encoding: .isoLatin1)!
      
        if convertSpecialChars {
          return str
            .replacingOccurrences(of: "|", with: "é")
            .replacingOccurrences(of: "\\", with: "ê")
            .replacingOccurrences(of: "}", with: "è")
            .replacingOccurrences(of: "{", with: "à")
            .replacingOccurrences(of: "^", with: "ô")
            .replacingOccurrences(of: "_", with: "û")
            .replacingOccurrences(of: "~", with: "ù")
        }
      
        return str
    }


    /// Write `value` over the sentence's digit field. A French ordinal day
    /// also receives "er" for a bare 1 and "è " otherwise.
    func formattedSentence(at index: UInt16, value: UInt16, timesTen: Bool = false, ordinal: Bool = false) -> String {
        var bytes = sentence(at: index).unicodeScalars.map { UInt8(truncatingIfNeeded: $0.value) }
        
        replaceDigits(&bytes, value, timesTen: timesTen)
      
        if ordinal {
            applyOrdinalSuffix(&bytes)
        }
      
        return String(bytes: bytes, encoding: .isoLatin1) ?? ""
    }
    
    
    func dumpInfo() {
        let count = sentenceCount()
        
        for i in 0..<count {
            let s = sentence(at: i)
            Logger.shared.log(.debug, "Sentence #\(i): \(s)")
        }
    }


    private func replaceDigits(_ bytes: inout [UInt8], _ value: UInt16, timesTen: Bool) {
        var start = 0
        while start < bytes.count && !isDigit(bytes[start]) {
            start += 1
        }
        var end = start
        while end < bytes.count && isDigit(bytes[end]) {
            end += 1
        }
        if timesTen {
            guard end >= 6 else { return }
            bytes[end - 1] = 0x30
            writeDigits(&bytes, end - 6, value, count: 5)
        } else {
            guard end >= 3 else { return }
            writeDigits(&bytes, end - 3, min(value, 999), count: 3)
        }
    }


    private func writeDigits(_ bytes: inout [UInt8], _ start: Int, _ value: UInt16, count: Int) {
        var place = 1
        var remainingPlaces = count - 1
        while remainingPlaces > 0 {
            place *= 10
            remainingPlaces -= 1
        }
        var leading = true
        var remaining = Int(value)
        var index = 0
        while index < count {
            let digit = remaining / place
            remaining %= place
            if place > 1 { place /= 10 }
            let last = index == count - 1
            if digit == 0 && leading && !last {
                bytes[start + index] = 0x20
            } else {
                leading = false
                bytes[start + index] = 0x30 + UInt8(digit)
            }
            index += 1
        }
    }


    private func applyOrdinalSuffix(_ bytes: inout [UInt8]) {
        var start = 0
        while start < bytes.count && !isDigit(bytes[start]) {
            start += 1
        }
        var end = start
        while end < bytes.count && isDigit(bytes[end]) {
            end += 1
        }
        guard end >= 2, end + 2 <= bytes.count else { return }
        let tens = bytes[end - 2]
        let unit = Int(bytes[end - 1] & 0x0f)
        let frenchOne = unit == 1 && language == .french && tens != 0x20
        let index = (tens == 0x31 || unit >= 4 || frenchOne) ? 0 : unit
        let suffix = ordinalSuffix(index)
        bytes[end] = suffix.0
        bytes[end + 1] = suffix.1
    }


    private func ordinalSuffix(_ index: Int) -> (UInt8, UInt8) {
        switch language {
        case .english:
            let suffixes: [(UInt8, UInt8)] = [
                (0x74, 0x68), (0x73, 0x74), (0x6e, 0x64), (0x72, 0x64)
            ]
            return suffixes[index]
        case .french:
            let suffixes: [(UInt8, UInt8)] = [
                (0x7d, 0x20), (0x65, 0x72), (0x7d, 0x20), (0x7d, 0x20)
            ]
            return suffixes[index]
        case .german:
            return (0x2e, 0x20)
        }
    }


    private func isDigit(_ byte: UInt8) -> Bool {
        byte >= 0x30 && byte <= 0x39
    }
}
