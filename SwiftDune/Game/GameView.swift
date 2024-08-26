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
                .frame(minWidth: 640, minHeight: 400)
                .aspectRatio(contentMode: .fit)
        }
        .onAppear {
            NSApplication.shared.keyWindow?.contentAspectRatio = NSSize(width: 320, height: 200)
            viewModel.engine.run()
        }
        .onDisappear {
            viewModel.engine.stop()
        }
        .safeAreaPadding(.all, 0)
        .navigationTitle("Dune")
        .preferredColorScheme(.dark)
    }
}
