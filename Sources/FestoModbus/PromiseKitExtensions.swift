//
//  File.swift
//  
//
//  Created by Dmitriy Borovikov on 14.10.2021.
//

import Foundation
import PromiseKit

func attempt<T>(retry count: Int = 1, delay: DispatchTimeInterval = .milliseconds(500), _ body: @escaping () -> Promise<T>) -> Promise<T> {
    var attempts = 0
    func attempt() -> Promise<T> {
        attempts += 1
        return body().recover { error -> Promise<T> in
            guard attempts < count else { throw error }
            return after(delay)
                .then(on: nil, attempt)
        }
    }
    return attempt()
}
