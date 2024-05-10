//
//  DuneNode.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 14/01/2024.
//

import Foundation


struct DuneNodeParams {
    var name: String
    var params: Dictionary<String, Any>
    
    init(_ name: String, _ params: Dictionary<String, Any> = [:]) {
        self.name = name
        self.params = params
    }
}


class DuneNode {
    var name: String
    var isActive: Bool = false {
        willSet {
            if newValue {
                onEnable()
            } else {
                onDisable()
            }
        }
    }

    private var nodesMap: [String: DuneNode] = [:]

    open var nodes: [DuneNode] = []
    open var activeNodes: [DuneNode] = []
    open var params: Dictionary<String, Any> = [:] {
        didSet {
            onParamsChange()
        }
    }

    init(_ name: String) {
        self.name = name
    }
    
    final func attachNode(_ node: DuneNode) {
        if let existingNode = nodesMap[node.name] {
            print("Node already registered: \(existingNode.name)")
            return
        }
        
        nodesMap[node.name] = node

        nodes.append(node)
    }
    
    
    final func findNode(_ name: String) -> DuneNode? {
        return nodesMap[name]
    }
    
    
    final func setNodeActive(_ name: String, _ active: Bool = true) {
        let node = nodesMap[name]
        node?.isActive = active
    }
    
    
    final func isChildNode(_ name: String) -> Bool {
        return nodes.first { node in
            node.name == name
        } != nil
    }
    
    
    func update(_ elapsedTime: Double) {
        activeNodes = nodes.filter { $0.isActive }
        
        activeNodes.forEach { node in
            node.update(elapsedTime)
        }
    }
    
    func render(_ buffer: PixelBuffer) {
        activeNodes.forEach { node in
            node.render(buffer)
        }
        
    }
    
    func onEnable() {
        
    }
    
    func onDisable() {
        
    }
    
    func onParamsChange() {
        
    }
    
    func onKey(_ key: DuneKeyEvent) {
        activeNodes.forEach { node in
            node.onKey(key)
        }
    }
}
