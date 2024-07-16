//
//  SpriteDetailsView.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 11/10/2023.
//

import Foundation
import SwiftUI

struct PaletteView: View {
    @Binding var palette: [NSColor]
    
    let paletteColumns: [GridItem] = [GridItem](repeating: GridItem(.fixed(12), spacing: 1), count: 16)
    
    var body: some View {
        LazyVGrid(columns: paletteColumns, alignment: .leading, spacing: 1) {
            ForEach(0..<256) { i in
                Rectangle()
                    .fill(Color(nsColor: palette[i]))
                    .frame(width: 12, height: 8)
                    .border(.gray)
                    .padding(0)
            }
        }
    }
}

struct SpriteDetailsView: View {
    @ObservedObject var viewModel: EditorViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Image")
                .font(.title2)
                .fontWeight(.bold)

            if let image = viewModel.spriteImage {
                let imageWidth = image.size.width * (image.size.width < 5 ? 25 : 2)
                let imageHeight = image.size.height * (image.size.width < 5 ? 25 : 2)

                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: imageWidth, height: imageHeight)
                    .aspectRatio(contentMode: .fill)
                    .border(.black)
                    .background(.clear)
            }

            Spacer()

            Text("Palette")
                .font(.title2)
                .fontWeight(.bold)

            if !viewModel.palette.isEmpty {
                PaletteView(palette: $viewModel.palette)
            }
            
            if let sprite = viewModel.sprite {
                if sprite.alternatePalettesCount > 0 {
                    Spacer()

                    Text("Palette selection")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Picker("Palette", selection: $viewModel.selectedPaletteIndex) {
                        Text("Default palette").tag(-1)

                        ForEach(0..<viewModel.sprite!.alternatePalettesCount, id: \.self) { index in
                            Text("Alternate \(index)").tag(index)
                        }
                    }
                }
            }
        }
        .padding()
        .onChange(of: viewModel.selectedPaletteIndex) { newValue in
            viewModel.updateSpritePalette(newValue)
        }
    }
}
