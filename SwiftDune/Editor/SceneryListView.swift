//
//  SceneListView.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 13/01/2024.
//

import Foundation
import SwiftUI


struct SceneryRoomListItem: View {
    var scenery: Scenery
    var index: Int
    
    var markerCount: Int {
        return scenery.rooms[index].commands.filter { $0 is RoomMarker }.count
    }
    
    var polygonCount: Int {
        return scenery.rooms[index].commands.filter { $0 is RoomPolygon }.count
    }

    var lineCount: Int {
        return scenery.rooms[index].commands.filter { $0 is RoomLine }.count
    }

    var spriteCount: Int {
        return scenery.rooms[index].commands.filter { $0 is RoomSprite }.count
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Room #\(index)")
            Text("Sprites: \(spriteCount), Markers: \(markerCount)")
                .font(.caption)
            Text("Polygons: \(polygonCount), Lines: \(lineCount)")
                .font(.caption)
        }
    }
}

struct SceneryListItemSelection: Hashable {
    var index: Int
}


struct SceneryListView: View {
    @ObservedObject var viewModel: EditorViewModel
    @State var selection: SceneryListItemSelection?
    
    var body: some View {
        List(selection: $selection) {
            if viewModel.scenery != nil && viewModel.scenery!.roomCount > 0 {
                Section("Rooms") {
                    ForEach(0..<viewModel.scenery!.roomCount, id: \.self) { i in
                        NavigationLink(value: SceneryListItemSelection(index: i), label: {
                            SceneryRoomListItem(scenery: viewModel.scenery!, index: i)
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
            viewModel.updateSceneryRoom(value.index)
            return
        }
    }
}

