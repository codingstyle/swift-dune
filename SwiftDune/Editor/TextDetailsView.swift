//
//  TextDetailsView.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 27/10/2023.
//

import Foundation
import SwiftUI

struct TextDetailsView: View {
    @ObservedObject var viewModel: EditorViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Text")
                .font(.title2)
                .fontWeight(.bold)

            if let dialogue = viewModel.dialogue {
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(0..<dialogue.sentenceCount(), id: \.self) { index in
                            let sentence = dialogue.sentence(at: index)
                            Text("\(String(format: "%03d", index)) • \(sentence)")
                                .fontDesign(.monospaced)
                                .padding(.bottom, 5)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}
