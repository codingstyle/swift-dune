//
//  SceneryDetailsView.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 13/01/2024.
//

import Foundation
import SwiftUI

struct SceneryDetailsView: View {
    @ObservedObject var viewModel: EditorViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Scenery")
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
                    .background(.blue)
            }
            
            Spacer()
            
            Button("Save to PNG") {
                viewModel.saveBufferAsPNG(to: "SCENERY.PNG")
            }
        }
        .padding()
    }
}
