//
//  EditorView.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 11/10/2023.
//

import Foundation
import SwiftUI

struct EditorSelection: Hashable {
    var resourceName: String
    var resourceType: ResourceType
}

struct EditorView: View {
    @StateObject var viewModel = EditorViewModel()
    @State var selection: EditorSelection?
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Globe") {
                    ForEach(ResourceType.globe.files, id: \.self) { r in
                        NavigationLink(r, value: EditorSelection(resourceName: r, resourceType: .globe))
                    }
                }

                Section("Scenes") {
                    ForEach(ResourceType.scene.files, id: \.self) { r in
                        NavigationLink(r, value: EditorSelection(resourceName: r, resourceType: .scene))
                    }
                }
                
                Section("Videos") {
                    ForEach(ResourceType.video.files, id: \.self) { r in
                        NavigationLink(r, value: EditorSelection(resourceName: r, resourceType: .video))
                    }
                }

                Section("Sprites") {
                    ForEach(ResourceType.sprite.files, id: \.self) { r in
                        NavigationLink(r, value: EditorSelection(resourceName: r, resourceType: .sprite))
                    }
                }

                Section("Sprites - No palette") {
                    ForEach(ResourceType.spriteWithoutPalette.files, id: \.self) { r in
                        NavigationLink(r, value: EditorSelection(resourceName: r, resourceType: .spriteWithoutPalette))
                    }
                }

                Section("Sounds") {
                    ForEach(ResourceType.sound.files, id: \.self) { r in
                        NavigationLink(r, value: EditorSelection(resourceName: r, resourceType: .sound))
                    }
                }

                Section("Dialogue") {
                    ForEach(ResourceType.sentence.files, id: \.self) { r in
                        NavigationLink(r, value: EditorSelection(resourceName: r, resourceType: .sentence))
                    }
                }

                Section("Fonts") {
                    ForEach(ResourceType.font.files, id: \.self) { r in
                        NavigationLink(r, value: EditorSelection(resourceName: r, resourceType: .font))
                    }
                }
            }
        } content: {
            if selection?.resourceType == .sprite || selection?.resourceType == .spriteWithoutPalette {
                SpriteListView(viewModel: viewModel)
            } else if selection?.resourceType == .scene {
                SceneryListView(viewModel: viewModel)
            } else if selection?.resourceType == .video {
                VideoListView(viewModel: viewModel)
            } else {
                Text("No content selected")
            }
        } detail: {
            if selection?.resourceType == .sprite || selection?.resourceType == .spriteWithoutPalette {
                SpriteDetailsView(viewModel: viewModel)
            } else if selection?.resourceType == .font {
                FontDetailsView(viewModel: viewModel)
            } else if selection?.resourceType == .sentence {
                TextDetailsView(viewModel: viewModel)
            } else if selection?.resourceType == .video {
                VideoDetailsView(viewModel: viewModel)
            } else if selection?.resourceType == .scene {
                SceneryDetailsView(viewModel: viewModel)
            } else if selection?.resourceType == .globe {
                GlobeDetailsView(viewModel: viewModel)
            } else {
                Text("No content selected")
            }
        }
        .navigationTitle("Dune Editor")
        .onChange(of: selection) { newValue in
            if let resource = newValue {
                viewModel.loadResource(resource)
            }
        }
    }
}
