//
//  GlobeDetailsView.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 12/03/2024.
//

import Foundation
import SwiftUI

struct GlobeDetailsView: View {
    @ObservedObject var viewModel: EditorViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Globe")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack {
                    Button {
                        viewModel.moveGlobe(.up)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10))
                            .frame(width: 10, height: 10)
                            .padding(5)
                    }

                    HStack {
                        Button {
                            viewModel.moveGlobe(.left)
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 10))
                                .frame(width: 10, height: 10)
                                .padding(5)
                        }

                        Button {
                            viewModel.moveGlobe(.right)
                        } label: {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .frame(width: 10, height: 10)
                                .padding(5)

                        }
                    }

                    Button {
                        viewModel.moveGlobe(.down)
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10))
                            .frame(width: 10, height: 10)
                            .padding(5)
                    }
                }
            }

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
