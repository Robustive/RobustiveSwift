//
//  Usecase.swift
//  
//
//  Created by 斉藤  祐輔 on 2023/04/03.
//

import Foundation
import Combine

public protocol Usecase {
    /// 自身が表すユースケースのSceneを実行した結果として、次のSceneがあれば次のSceneを返すFutureを、ない（シナリオの最後の）場合には nil を返します。
    func next() -> AnyPublisher<Self, Error>?
    
    /// 引数で渡されたSceneを次のSceneとして返します。
    /// next関数の実装時、特にドメイン的な処理がSceneが続く場合に使います。
    func just(next: Self) -> AnyPublisher<Self, Error>
    
    /// 引数で渡されたActorがこのユースケースを実行できるかを返します。
    func authorize<T>(_ actor: T) throws -> Bool where T : Actor
    
    /// Actorに準拠するクラスのインスタンスを引数に取り、再帰的にnext()を実行します。
    func interacted<T>(by actor: T) -> AnyPublisher<[Self], Error> where T : Actor
}


extension Usecase {
    
    public func just(next: Self) -> AnyPublisher<Self, Error> {
        return Deferred {
            Future<Self, Error> { promise in
                promise(.success(next))
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func recursive<T>(_ actor: T, scenario: [Self]) -> AnyPublisher<[Self], Error> where T : Actor {
        guard let lastScene = scenario.last else { fatalError() }
        
        // 終了条件
        guard let future = lastScene.next() else {
            return Deferred {
                Future<[Self], Error> { promise in
                    promise(.success(scenario))
                }
            }
            .receive(on: DispatchQueue.main) // sink後の処理はメインスレッドで行われるようにする
            .eraseToAnyPublisher()
        }
        
        // 再帰呼び出し
        return future
            .flatMap { nextScene -> AnyPublisher<[Self], Error> in
                var _scenario = scenario
                _scenario.append(nextScene)
                return self.recursive(actor, scenario: _scenario)
            }
            .eraseToAnyPublisher()
    }
    
    public func interacted<T: Actor>(by actor: T) -> AnyPublisher<[Self], Error> {
        // 権限確認
        do {
            guard try self.authorize(actor) else {
                return Fail(error: RobustiveError.Interaction.notAuthorized(usecase: self, actor: actor))
                    .eraseToAnyPublisher()
            }
        } catch let error {
            return Fail(error: RobustiveError.System.error(causedBy: error))
                .eraseToAnyPublisher()
        }
        
        return self.recursive(actor, scenario: [self])
    }
}
