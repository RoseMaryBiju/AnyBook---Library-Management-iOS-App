//
//  Sequence+Extension.swift
//  lib ms
//
//  Created by admin12 on 08/05/25.
//

extension Sequence {
    func removingDuplicates<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { element in
            let key = element[keyPath: keyPath]
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }
}
