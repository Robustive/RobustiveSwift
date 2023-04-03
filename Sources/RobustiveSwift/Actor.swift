//
//  Actor.swift
//  
//
//  Created by 斉藤  祐輔 on 2023/04/03.
//

import Foundation

public enum UserTypes {
    case anyone
    case signedIn
}

public protocol Actor {
    associatedtype User
    var user: User? { get }
    var userType: UserTypes { get }
}

extension Actor {
    public var userType: UserTypes {
        guard let _ = self.user else {
            return .anyone
        }
        return .signedIn
    }
}
