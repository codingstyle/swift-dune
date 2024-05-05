//
//  VideoDetailsView.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 29/10/2023.
//

import Foundation
import SwiftUI

struct VideoDetailsView: View {
    @ObservedObject var viewModel: EditorViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Video")
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
            }

            Spacer()

            Text("Palette")
                .font(.title2)
                .fontWeight(.bold)

            if !viewModel.palette.isEmpty {
                PaletteView(palette: $viewModel.palette)
            }
        }
        .padding()
    }
}
