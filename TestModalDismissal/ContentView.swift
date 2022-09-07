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
  var isPresentingAlert: Bool
  var isPresentingConfirmationDialog: Bool

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
        colors: colors,
        isPresentingAlert: isPresentingAlert,
        isPresentingConfirmationDialog: isPresentingConfirmationDialog
      )
    }
    set {
      guard let nextState = newValue else {
        return
      }
      colors = nextState.colors
      isPresentingAlert = nextState.isPresentingAlert
      isPresentingConfirmationDialog = nextState.isPresentingConfirmationDialog
    }
  }

  var alertState: AlertState<ContentAction>? {
    if isPresentingAlert && colors.endIndex - 1 == wrapped.id {
      return .init(
        title: .init("Alert"),
        primaryButton: .default(
          .init("Dismiss All"),
          action: .send(.dismissAll)
        ),
        secondaryButton: .cancel(.init("Cancel"))
      )
    } else {
      return nil
    }
  }

  var confirmationDialogState: ConfirmationDialogState<ContentAction>? {
    if isPresentingConfirmationDialog && colors.endIndex - 1 == wrapped.id {
      return .init(
        title: .init("Action Sheet"),
        buttons: [
          .default(
            .init("Dismiss All"),
            action: .send(.dismissAll)
          ),
          .cancel(.init("Cancel"))
        ]
      )
    } else {
      return nil
    }
  }
}

indirect enum ContentAction: Equatable {
  case setNextColor
  case dismissAll
  case onDismiss
  case readyToDismiss
  case presentAlert
  case alertCancelTapped
  case presentConfirmationDialog
  case confirmationDialogCancelTapped
  case next(ContentAction)
}

struct ContentEnvironment {
  var dismissAll: () -> Effect<ContentAction, Never>
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

  case .dismissAll:
    return environment.dismissAll()

  case .onDismiss:
    if state.colors.indices.contains(state.id + 1) {
      return .init(value: .next(.onDismiss))
    } else {
      var shouldDelay = false

      if state.isPresentingAlert {
        state.isPresentingAlert = false
        shouldDelay = true
      }

      if state.isPresentingConfirmationDialog {
        state.isPresentingConfirmationDialog = false
        shouldDelay = true
      }

      if shouldDelay {
        return .init(value: .readyToDismiss)
          .delay(for: 0.1, scheduler: DispatchQueue.main)
          .eraseToEffect()
      } else {
        return .init(value: .readyToDismiss)
      }
    }

  case .readyToDismiss:
    // leave this to parent
    return .none

  case .presentAlert:
    state.isPresentingAlert = true
    return .none

  case .alertCancelTapped:
    state.isPresentingAlert = false
    return .none

  case .presentConfirmationDialog:
    state.isPresentingConfirmationDialog = true
    return .none

  case .confirmationDialogCancelTapped:
    state.isPresentingConfirmationDialog = false
    return .none

  case .next(.readyToDismiss):
    state.colors = .init(state.colors[0...state.id])
    return .init(value: .readyToDismiss)
      .delay(for: 0.6, scheduler: DispatchQueue.main)
      .eraseToEffect()

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

        VStack {
          Button("Present") {
            viewStore.send(.setNextColor)
          }
          .padding()
          .foregroundColor(.white)
          .background(Color.blue)
          .clipShape(Capsule())

          Button("Dismiss All") {
            viewStore.send(.dismissAll)
          }
          .padding()
          .foregroundColor(.white)
          .background(Color.blue)
          .clipShape(Capsule())

          Button("Present Alert") {
            viewStore.send(.presentAlert)
          }
          .padding()
          .foregroundColor(.white)
          .background(Color.blue)
          .clipShape(Capsule())

          Button("Present Action Sheet") {
            viewStore.send(.presentConfirmationDialog)
          }
          .padding()
          .foregroundColor(.white)
          .background(Color.blue)
          .clipShape(Capsule())
        }
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
      .alert(
        store.scope(state: \.alertState),
        dismiss: .alertCancelTapped
      )
      .confirmationDialog(
        store.scope(state: \.confirmationDialogState),
        dismiss: .confirmationDialogCancelTapped
      )
    }
  }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      ContentView(store: .init(
        initialState: .init(
          wrapped: .init(id: 0),
          colors: [.white],
          isPresentingAlert: false,
          isPresentingConfirmationDialog: false
        ),
        reducer: contentReducer,
        environment: .init(dismissAll: { .none })
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
