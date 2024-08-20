//
//  GameView.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 09/10/2023.
//

import Foundation
import SwiftUI
import Charts

struct GameView: View {
    @StateObject var viewModel = GameViewModel()
    
    var body: some View {
        VStack {
            MetalRenderView()
                .tag(MetalRenderView.tagID)
                .frame(width: 640, height: 400)
                .aspectRatio(contentMode: .fill)
                .border(.gray)
        }
        .onDisappear {
            viewModel.engine.stop()
        }
        .navigationTitle("Dune")
    }
}
