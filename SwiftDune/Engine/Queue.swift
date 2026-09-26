//
//  Queue.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 14/01/2024.
//

import Foundation

/// FIFO used for input events. Input arrives on the main thread while the
/// game loop drains it on a background thread, so every access is locked.
final class Queue<T> {
    private var items: Array<T> = []
    private let lock = NSLock()
    
    func empty() {
        lock.lock(); defer { lock.unlock() }
        items.removeAll()
    }
    
    func enqueue(_ item: T) {
        lock.lock(); defer { lock.unlock() }
        items.append(item)
    }
    
    func dequeueFirst() -> T? {
        lock.lock(); defer { lock.unlock() }
        if items.isEmpty {
            return nil
        }
        
        return items.removeFirst()
    }
    
    func dequeueLast() -> T? {
        lock.lock(); defer { lock.unlock() }
        if items.isEmpty {
            return nil
        }
        
        return items.popLast()
    }
}
