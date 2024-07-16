//
//  GameView.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 09/10/2023.
//

import Foundation
import SwiftUI
import Charts


struct IconButton: View {
    var imageSystemName: String
    var action: () -> Void
    
    init(_ imageSystemName: String, _ action: @escaping () -> Void) {
        self.imageSystemName = imageSystemName
        self.action = action
    }
    
    var body: some View {
        Button(action: action, label: {
            ZStack(alignment: .center) {
                Image(systemName: imageSystemName)
                    .font(.system(size: 20))
                    .frame(width: 20, height: 20, alignment: .center)
            }
            .frame(maxWidth: 20)
            .padding(10)
        })
    }
}


struct FPSChartView: View {
    var fpsChartData: [GameFPSData]
    
    var averageFPS: Double {
        if fpsChartData.count < 5 {
            return 0.0
        }
        
        return fpsChartData.suffix(5).reduce(0) { $0 + ($1.fps / 5.0) }
    }
    
    var body: some View {
        let xMax = fpsChartData.count > 0 && fpsChartData.last!.time > 2.0 ? fpsChartData.last!.time : 2.0
        let areaGradient = LinearGradient(
                gradient: Gradient (
                    colors: [
                        Color(.blue).opacity(0.1),
                        Color(.blue).opacity(0.0)
                    ]
                ),
                startPoint: .top,
                endPoint: .bottom
            )
        
        ZStack {
            Chart(fpsChartData) {
                LineMark(
                    x: .value("Time", $0.time),
                    y: .value("Frame", $0.fps)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.blue)
                
                
                AreaMark(
                    x: .value("Time", $0.time),
                    y: .value("Frame", $0.fps)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(areaGradient)
            }
            .frame(maxWidth: 300, maxHeight: 100)
            .clipped()
            .chartLegend(.hidden)
            .chartXScale(domain: (xMax - 2.0)...xMax)
            .chartYScale(domain: 0...80)
            .padding()
            
            Text("\(String(format: "%.1f", averageFPS)) fps")
                .foregroundStyle(.blue.opacity(0.1))
                .font(.system(size: 30.0, weight: .heavy))
                .frame(alignment: .topLeading)
        }
    }
}


struct GameView: View {
    @StateObject var viewModel = GameViewModel()
    
    var body: some View {
        VStack {
            HStack {
                IconButton("camera") {
                    viewModel.screenshot()
                }
                
                IconButton("arrow.clockwise") {
                    viewModel.reset()
                }
                
                IconButton(viewModel.isRunning ? "pause.fill" : "play.fill") {
                    viewModel.togglePlayPause()
                }
                
                FPSChartView(fpsChartData: viewModel.fpsChartData)

                if !viewModel.palette.isEmpty {
                    PaletteView(palette: $viewModel.palette)
                }
            }
            .frame(minHeight: 120)
            .padding()
            
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
