//
//  GameViewModel.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 09/10/2023.
//

import Foundation
import AppKit
import CoreGraphics
import SwiftUI


final class GameViewModel: ObservableObject {
    let engine = DuneEngine.shared

    init() {
        engine.rootNode.attachNode(Main())
        engine.rootNode.setNodeActive("Main", true)
    }
}
