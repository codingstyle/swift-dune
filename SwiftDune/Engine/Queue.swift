//
//  Queue.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 14/01/2024.
//

import Foundation

final class Queue<T> {
    private var items: Array<T> = []
    
    func empty() {
        items.removeAll()
    }
    
    func enqueue(_ item: T) {
        items.append(item)
    }
    
    func dequeueFirst() -> T? {
        if items.isEmpty {
            return nil
        }
        
        return items.removeFirst()
    }
    
    func dequeueLast() -> T? {
        if items.isEmpty {
            return nil
        }
        
        return items.popLast()
    }
}
