//
//  VideoListView.swift
//  DuneEditor
//
//  Created by Christophe Buguet on 31/08/2024.
//

import Foundation
import SwiftUI

struct VideoListItem: View {
    var video: Video
    var index: Int
    
    var frame: VideoFrame {
        video.frame(at: index)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Frame #\(index)")
            Text("Size: \(frame.videoBlock!.width) x \(frame.videoBlock!.height)")
                .font(.caption)
        }
    }
}

struct VideoListItemSelection: Hashable {
    var index: Int
}


struct VideoListView: View {
    @ObservedObject var viewModel: EditorViewModel
    @State var selection: VideoListItemSelection?
    
    var body: some View {
        List(selection: $selection) {
            if viewModel.video != nil {
                Section("Video frames") {
                    ForEach(0..<viewModel.video!.frameCount, id: \.self) { i in
                        NavigationLink(value: VideoListItemSelection(index: i), label: {
                            VideoListItem(video: viewModel.video!, index: i)
                        })
                    }
                }
            }
        }
        .onChange(of: selection) { newValue in
            guard let value = newValue else {
                return
            }
            
            viewModel.clearBuffer()
            viewModel.updateVideoFrame(value.index)
            return
        }
    }
}
