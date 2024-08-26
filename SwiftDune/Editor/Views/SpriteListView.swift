//
//  EditorSpriteView.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 11/10/2023.
//

import Foundation
import SwiftUI

struct SpriteAnimationListItem: View {
    var sprite: Sprite
    var index: Int
    
    var body: some View {
        let animation = sprite.animation(at: index)
        
        VStack(alignment: .leading) {
            Text("Animation #\(index)")
            Text("Size: \(animation.width) x \(animation.height)")
                .font(.caption)
            Text("Frames: \(animation.frames.count)")
                .font(.caption)
        }
    }
}

struct SpriteFrameListItem: View {
    var sprite: Sprite
    var index: Int
    
    var body: some View {
        let frame = sprite.frame(at: index)
        
        VStack(alignment: .leading) {
            Text("Frame #\(index)")
            Text("Size: \(frame.width) x \(frame.height)")
                .font(.caption)
            Text("Compressed: \(frame.isCompressed ? "YES" : "NO")")
                .font(.caption)
        }
    }
}


enum SpriteListItemType {
    case animation
    case frame
}


struct SpriteListItemSelection: Hashable {
    var index: Int
    var itemType: SpriteListItemType
}


struct SpriteListView: View {
    @ObservedObject var viewModel: EditorViewModel
    @State var selection: SpriteListItemSelection?
    
    var body: some View {
        List(selection: $selection) {
            if viewModel.sprite != nil && viewModel.sprite!.frameCount > 0 {
                Section("Frames") {
                    ForEach(0..<viewModel.sprite!.frameCount, id: \.self) { i in
                        NavigationLink(value: SpriteListItemSelection(index: i, itemType: .frame), label: {
                            SpriteFrameListItem(sprite: viewModel.sprite!, index: i)
                        })
                    }
                }
            }

            if viewModel.sprite != nil && viewModel.sprite!.animationCount > 0 {
                Section("Animations") {
                    ForEach(0..<viewModel.sprite!.animationCount, id: \.self) { i in
                        NavigationLink(value: SpriteListItemSelection(index: i, itemType: .animation), label: {
                            SpriteAnimationListItem(sprite: viewModel.sprite!, index: i)
                        })
                    }
                }
            }
        }
        .onChange(of: selection) { newValue in
            guard let value = newValue else {
                return
            }
            
            switch value.itemType {
            case .frame:
                viewModel.clearBuffer()
                viewModel.updateSpriteFrame(value.index)
                return
            case .animation:
                viewModel.clearBuffer()
                viewModel.startAnimation(value.index)
                return
            } 
        }
    }
}
