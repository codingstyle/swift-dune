//
//  TextDetailsView.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 27/10/2023.
//

import Foundation
import AppKit
import SwiftUI

struct TextDetailsView: View {
    @ObservedObject var viewModel: EditorViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Text")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                if let dialogue = viewModel.sentence {
                  Button("Copy All") {
                    copyAllLines(dialogue)
                  }
                }
            }

            if let dialogue = viewModel.sentence {
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(0..<dialogue.sentenceCount(), id: \.self) { index in
                            let line = line(at: index, in: dialogue)

                            Text(line)
                                .fontDesign(.monospaced)
                                .textSelection(.enabled)
                                .padding(.bottom, 5)
                                .contextMenu {
                                    Button("Copy") {
                                        copyToPasteboard(line)
                                    }
                                }
                        }
                    }
                    .textSelection(.enabled)
                }
            }

            Spacer()
        }
        .padding()
    }


    private func line(at index: UInt16, in dialogue: Sentence) -> String {
        let sentence = dialogue.sentence(at: index, convertSpecialChars: true)
        return "\(String(format: "0x%04X", index)) • \(sentence)"
    }


    private func copyAllLines(_ dialogue: Sentence) {
        let text = (0..<dialogue.sentenceCount())
            .map { line(at: $0, in: dialogue) }
            .joined(separator: "\n")
        copyToPasteboard(text)
    }


    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
