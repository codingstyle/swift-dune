//
//  SpriteViewModel.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 11/10/2023.
//

import Foundation

class SpriteViewModel: ObservableObject {
    @Published var sprite: Sprite?
    private var engine: DuneEngine
    
    init(_ engine: DuneEngine) {
        self.engine = engine
    }
    
    func load() {
        
    }
}
