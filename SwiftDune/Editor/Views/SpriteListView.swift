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


enum SpriteListItemType: Hashable {
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
            if let sprite = viewModel.sprite, sprite.frameCount > 0 {
                Section("Frames") {
                    let items = (0..<sprite.frameCount).map {
                        SpriteListItemSelection(index: $0, itemType: .frame)
                    }
                    ForEach(items, id: \.self) { item in
                        NavigationLink(value: item, label: {
                            SpriteFrameListItem(sprite: sprite, index: item.index)
                        })
                    }
                }
            }

            if let sprite = viewModel.sprite, sprite.animationCount > 0 {
                Section("Animations") {
                    let items = (0..<sprite.animationCount).map {
                        SpriteListItemSelection(index: $0, itemType: .animation)
                    }
                    ForEach(items, id: \.self) { item in
                        NavigationLink(value: item, label: {
                            SpriteAnimationListItem(sprite: sprite, index: item.index)
                        })
                    }
                }
            }
        }
        .onChange(of: selection, initial: false) { oldValue, newValue in
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
