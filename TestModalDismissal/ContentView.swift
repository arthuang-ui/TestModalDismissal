//
//  ContentView.swift
//  TestModalDismissal
//
//  Created by Art Huang on 2022/9/5.
//

import ComposableArchitecture
import SwiftUI

@dynamicMemberLookup
struct BaseState<State: Equatable & Identifiable>: Equatable, Identifiable {
  var wrapped: State
  var colors: [Color]

  var id: State.ID { wrapped.id }

  subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    wrapped[keyPath: keyPath]
  }

  subscript<Value>(dynamicMember keyPath: WritableKeyPath<State, Value>) -> Value {
    get { wrapped[keyPath: keyPath] }
    set { wrapped[keyPath: keyPath] = newValue }
  }
}

struct ContentState: Equatable, Identifiable {
  var id: Int
}

extension BaseState where State == ContentState {
  var color: Color {
    guard colors.count > wrapped.id else {
      return .white
    }
    return colors[wrapped.id]
  }

  var nextState: BaseState<ContentState>? {
    get {
      guard colors.count > wrapped.id + 1 else {
        return nil
      }
      return .init(
        wrapped: .init(id: wrapped.id + 1),
        colors: colors
      )
    }
    set {
      guard let nextState = newValue else {
        return
      }
      colors = nextState.colors
    }
  }
}

indirect enum ContentAction: Equatable {
  case setNextColor
  case next(ContentAction)
}

struct ContentEnvironment {}

extension ContentEnvironment {
  static var live = Self()
}

let contentReducer = Reducer<
  BaseState<ContentState>,
  ContentAction,
  ContentEnvironment
>.recurse { `self`, state, action, environment in
  switch action {
  case .setNextColor:
    state.colors.append(.random)
    return .none

  case .next:
    return self.optional().pullback(
      state: \.nextState,
      action: /ContentAction.next,
      environment: { $0 }
    )
    .run(&state, action, environment)
  }
}

struct ContentView: View {
  typealias ViewStoreType = ViewStore<BaseState<ContentState>, ContentAction>
  let store: Store<BaseState<ContentState>, ContentAction>

  var body: some View {
    WithViewStore(store) { viewStore in
      ZStack {
        viewStore.color
          .ignoresSafeArea()

        Button("Present") {
          viewStore.send(.setNextColor)
        }
        .padding()
        .foregroundColor(.white)
        .background(Color.blue)
        .clipShape(Capsule())
      }
      .sheet(item: Binding(
        get: { viewStore.nextState },
        set: { _ in }
      )) { _ in
        IfLetStore(
          store.scope(
            state: \.nextState,
            action: ContentAction.next
          ),
          then: ContentView.init
        )
      }
    }
  }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      ContentView(store: .init(
        initialState: .init(wrapped: .init(id: 0), colors: [.white]),
        reducer: contentReducer,
        environment: .live
      ))
    }
  }
}
#endif

private extension Color {
  static var random: Color {
    return Color(
      red: .random(in: 0...1),
      green: .random(in: 0...1),
      blue: .random(in: 0...1)
    )
  }
}

private extension Reducer {
  static func recurse(
    _ reducer: @escaping (Reducer, inout State, Action, Environment) -> Effect<Action, Never>
  ) -> Reducer {
    var `self`: Reducer!
    self = Reducer { state, action, environment in
      reducer(self, &state, action, environment)
    }
    return self
  }
}
