//
//  RobustiveError.swift
//  
//
//  Created by 斉藤  祐輔 on 2023/04/03.
//

import Foundation

public enum RobustiveError: Error {
    enum Interaction<T: Usecase, U: Actor>: LocalizedError {
        case notAuthorized(usecase: T, actor: U)
        
        var errorDescription: String? {
            switch self {
            case let .notAuthorized(usecase, actor): return "The usecase '\(usecase)' is not authorized the actor '\(actor)'."
            }
        }
    }
    
    enum System: LocalizedError {
        case error(causedBy: Error)
        
        var errorDescription: String? {
            switch self {
            case let .error(causedBy): return "The system error is occurred: '\(causedBy.localizedDescription)'."
            }
        }
    }
}
