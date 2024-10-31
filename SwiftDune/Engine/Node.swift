//
//  DuneNode.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 14/01/2024.
//

import Foundation


@propertyWrapper
struct DuneNodeParam<T> {
    private var initialValue: T
    private var currentValue: T
    var name: String
    
    var wrappedValue: T {
        get {
            return currentValue
        }
        
        set {
            currentValue = newValue
        }
    }
    
    init(_ name: String, _ initialValue: T) {
        self.initialValue = initialValue
        self.currentValue = initialValue
        self.name = name
    }
    
    mutating func reset() {
        currentValue = initialValue
    }
}


struct DuneNodeParams {
    var name: String
    var params: Dictionary<String, Any>
    
    init(_ name: String, _ params: Dictionary<String, Any> = [:]) {
        self.name = name
        self.params = params
    }
}


enum RenderPriority: Int {
    case none = 0
    case background = 1
    case foreground = 2
}


class DuneNode: Comparable {
    var engine: DuneEngine {
        return DuneEngine.shared
    }

    var name: String
    var renderPriority: RenderPriority = .none
    
    var isActive: Bool = false {
        willSet {
            if newValue {
                onEnable()
            } else {
                onDisable()
            }
        }
    }

    open var currentTime: TimeInterval = 0.0
    open var duration: TimeInterval = 99999.0

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
            engine.logger.log(.debug, "Node already registered: \(existingNode.name)")
            return
        }
        
        nodesMap[node.name] = node
        nodes.append(node)
    }
    
    
    final func findNode(_ name: String) -> DuneNode? {
        return nodesMap[name]
    }
    
    
  final func setNodeActive(_ name: String, _ active: Bool = true, _ renderPriority: RenderPriority = .background) {
        let node = nodesMap[name]
        node?.isActive = active
        node?.renderPriority = active ? renderPriority : .none
    }
    
    
    final func isChildNode(_ name: String) -> Bool {
        return nodes.first { node in
            node.name == name
        } != nil
    }
    
    
    func update(_ elapsedTime: TimeInterval) {
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
  
  
    func onKey(_ event: DuneKeyEvent) {
        activeNodes.forEach { node in
            node.onKey(event)
        }
    }
  
  
    func onClick(_ event: DuneMouseClickEvent) {
        activeNodes.forEach { node in
            node.onClick(event)
        }
    }
  
  
    static func < (lhs: DuneNode, rhs: DuneNode) -> Bool {
        return lhs.renderPriority.rawValue < rhs.renderPriority.rawValue
    }
    
    static func == (lhs: DuneNode, rhs: DuneNode) -> Bool {
        return lhs.name == rhs.name
    }
}
