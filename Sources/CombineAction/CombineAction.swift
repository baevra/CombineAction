import Foundation
import Combine
import CombineExt

public enum ActionError<Failure: Error>: Error {
  case notEnabled
  case actionError(Failure)

  public var notEnabledError: Error? {
    guard case .notEnabled = self else { return nil }
    return ActionError.notEnabled
  }

  public var actionError: Failure? {
    guard case let .actionError(error) = self else { return nil }
    return error
  }
}

final public  class Action<Input, Output, Failure: Error> {
  public typealias WorkFactory = (Input) -> AnyPublisher<Output, Failure>

  public let inputs: PassthroughSubject<Input, Never> = .init()
  public let cancellations: PassthroughSubject<Void, Never> = .init()
  public let elements: AnyPublisher<Output, Never>
  public let errors: AnyPublisher<ActionError<Failure>, Never>
  public let isExecuting: AnyPublisher<Bool, Never>
  public let isEnabled: AnyPublisher<Bool, Never>

  public let workFactory: WorkFactory
  public let enableCondition: AnyPublisher<Bool, Never>

  private let elementsSubject = PassthroughSubject<Output, Never>()
  private let errorsSubject = PassthroughSubject<ActionError<Failure>, Never>()
  private let isExecutingSubject = PassthroughSubject<Bool, Never>()
  private let isEnabledSubject = PassthroughSubject<Bool, Never>()

  private var subscriptions = Set<AnyCancellable>()
  private var executionStream: AnyCancellable?

  public init(
    enableCondition: AnyPublisher<Bool, Never> = Just(true).eraseToAnyPublisher(),
    workFactory: @escaping WorkFactory
  ) {
    self.enableCondition = enableCondition
    self.workFactory = workFactory

    elements = elementsSubject
      .share(replay: 1)
      .eraseToAnyPublisher()

    errors = errorsSubject
      .eraseToAnyPublisher()

    isExecuting = isExecutingSubject
      .prepend(false)
      .removeDuplicates()
      .eraseToAnyPublisher()

    isEnabled = isEnabledSubject
      .prepend(true)
      .removeDuplicates()
      .eraseToAnyPublisher()

    isExecuting
      .combineLatest(enableCondition) { !$0 && $1 }
      .subscribe(isEnabledSubject)
      .store(in: &subscriptions)

    inputs
      .withLatestFrom(isEnabled) { ($0, $1) }
      .sink { [unowned self] input, isEnabled in
        guard isEnabled else { return errorsSubject.send(.notEnabled) }
        execute(input: input)
      }
      .store(in: &subscriptions)

    cancellations
      .sink { [unowned self] input in
        cancel()
      }
      .store(in: &subscriptions)
  }

  private func execute(input: Input) {
    isExecutingSubject.send(true)

    executionStream = workFactory(input)
      .sink(
        receiveCompletion: { [unowned self] completion in
          isExecutingSubject.send(false)
          guard case let .failure(error) = completion else { return }
          errorsSubject.send(.actionError(error))
        },
        receiveValue: { [unowned self] value in
          elementsSubject.send(value)
        }
      )
  }

  public func cancel() {
    isExecutingSubject.send(false)
    executionStream?.cancel()
  }

  public func execute(_ value: Input) {
    inputs.send(value)
  }
}
