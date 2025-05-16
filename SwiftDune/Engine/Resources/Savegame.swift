//
//  Savegame.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 19/03/2025.
//


enum GameVersion {
  case v21 // 2.1 (floppy)
  case v23 // 2.3 (floppy)
  case v24 // 2.4 (floppy)
  case v37 // 3.7 (PC-CD)
  case v38 // 3.8 (PC-CD)
}

struct MapState {
  
}

struct SietchState {
  
}

struct TroopState {
  
}

struct GameState {
  var mapState: MapState
  var sietchState: [SietchState]
  var troopsState: [TroopState]
}
