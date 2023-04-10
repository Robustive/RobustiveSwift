//
//  Usecase.swift
//  
//
//  Created by 斉藤  祐輔 on 2023/04/03.
//

import Foundation
import Combine

public protocol Scenes {
    associatedtype Basics
    associatedtype Alternatives
    associatedtype Goals
}

public protocol Scenario : Scenes {
    init()
    
    /// 引数で渡されたActorがこのユースケースを実行できるかを返します。
    func authorize<T>(_ actor: T, toInteract usease: Usecase<Self>) throws -> Bool where T : Actor
    
    /// 引数で渡されたSceneを次のSceneとして返します。
    func just(next: Usecase<Self>) -> AnyPublisher<Usecase<Self>, Error>
    
    /// 自身が表すユースケースのSceneを実行した結果として、次のSceneがあれば次のSceneを返すFutureを、ない（シナリオの最後の）場合には nil を返します。
    func next(to currentScene: Usecase<Self>) -> AnyPublisher<Usecase<Self>, Error>?
}

extension Scenario {
    
    public func just(next: Usecase<Self>) -> AnyPublisher<Usecase<Self>, Error> {
        return Deferred {
            Future<Usecase<Self>, Error> { promise in
                promise(.success(next))
            }
        }
        .eraseToAnyPublisher()
    }
}

public enum Usecase<S: Scenario> {
    // 晴れの日コースのシーン
    case basic(scene: S.Basics)
    // 雨の日コースのシーン
    case alternate(scene: S.Alternatives)
    // 最後のシーン（＝Boundary）
    case last(scene: S.Goals)
    
    private func recursive<T>(_ actor: T, scenario: [Self]) -> AnyPublisher<[Self], Error> where T : Actor {
        guard let lastScene = scenario.last else { fatalError() }
        
        // 終了条件
        guard let future = S().next(to: lastScene) else {
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
    
    /// Actorに準拠するクラスのインスタンスを引数に取り、再帰的にnext()を実行します。
    public func interacted<T: Actor>(by actor: T) -> AnyPublisher<[Self], Error> {
        // 権限確認
        do {
            guard try S().authorize(actor, toInteract: self) else {
                return Fail(error: RobustiveError.Interaction.notAuthorized(usecase: self, actor: actor))
                    .eraseToAnyPublisher()
            }
        } catch let error {
            return Fail(error: RobustiveError.System.error(causedBy: error))
                .eraseToAnyPublisher()
        }
        
        return self.recursive(actor, scenario: [self])
    }
    
    public func interacted<T: Actor>(by actor: T, receiveCompletion: ((Subscribers.Completion<Error>) -> Void)? = nil, receiveValue: @escaping ((S.Goals, [Self]) -> Void)) -> AnyCancellable {
        return self.interacted(by: actor)
            .sink { completion in
                if case .failure(let error) = completion {
                    print("[USECASE: \(S.self) interacted by \(actor.userType)\n    encountered: \(error)]")
                }
                receiveCompletion?(completion)
            } receiveValue: { scenario in
                let (usecase, actor, logs) = self.readable(scenario, interactedBy: actor)
                print("[USECASE: \(usecase) interacted by \(actor)\n    \(logs.joined(separator: "\n    "))]")
                guard case let .last(goal) = scenario.last else {
                    fatalError()
                }
                receiveValue(goal, scenario)
            }
    }
    
    /// 実行したユースケースの名前、アクター名、通ったシナリオ（シーン名配列）のタプルを返します。
    public func readable<T: Actor>(_ scenario: [Self], interactedBy actor: T) -> (String, String, [String]) {
        return ("\(S.self)", "\(actor.userType)", scenario.map { scene in
            switch scene {
            case let .basic(scene):
                return ".basic(\(scene))"
            case let .alternate(scene):
                return ".alternate(\(scene))"
            case let .last(scene):
                return ".goal(\(scene))"
            }
        })
    }
}
