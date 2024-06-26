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
        let xMax = viewModel.fpsChartData.count > 0 && viewModel.fpsChartData.last!.time > 2.0 ? viewModel.fpsChartData.last!.time : 2.0
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
        
        VStack {
            HStack {
                Button(action: {
                    viewModel.screenshot()
                }, label: {
                    Image(systemName: "camera")
                        .font(.system(size: 20))
                        .frame(width: 20, height: 20)
                        .padding(10)
                })
                
                Button(action: {
                    viewModel.reset()
                }, label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 20))
                        .frame(width: 20, height: 20)
                        .padding(10)
                })

                Button(action: {
                    viewModel.togglePlayPause()
                }, label: {
                    Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .frame(width: 20, height: 20)
                        .padding(10)
                })
                
                Chart(viewModel.fpsChartData) {
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
            }
            .padding()
            
            RenderView(engine: $viewModel.engine)
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
