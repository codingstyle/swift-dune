//
//  FontDetailsView.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 17/10/2023.
//

import Foundation
import SwiftUI

struct FontDetailsView: View {
    @ObservedObject var viewModel: EditorViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Font")
                .font(.title2)
                .fontWeight(.bold)

            if let image = viewModel.spriteImage {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 640, height: 400)
                    .aspectRatio(contentMode: .fill)
                    .border(.black)
            }

            Spacer()
        }
        .padding()
    }
}
