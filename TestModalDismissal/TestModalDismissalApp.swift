//
//  TestModalDismissalApp.swift
//  TestModalDismissal
//
//  Created by Art Huang on 2022/9/5.
//

import ComposableArchitecture
import SwiftUI

struct AppState: Equatable {
  var colors: [Color]

  var contentState: BaseState<ContentState> {
    get {
      .init(
        wrapped: .init(id: 0),
        colors: colors
      )
    }
    set {
      colors = newValue.colors
    }
  }
}

enum AppAction: Equatable {
  case onAppear
  case dismissAll
  case content(ContentAction)
}

struct AppEnvironment {
  var notificationCenter: NotificationCenter
}

extension AppEnvironment {
  static var live = Self(
    notificationCenter: .default
  )
}

let dismissAllNotification = Notification.Name("dismissAllNotification")

let appReducer = Reducer<
  AppState,
  AppAction,
  AppEnvironment
>.combine(
  contentReducer.pullback(
    state: \.contentState,
    action: /AppAction.content,
    environment: { environment in
      .init(dismissAll: {
        .fireAndForget {
          environment.notificationCenter.post(
            name: dismissAllNotification,
            object: nil,
            userInfo: nil
          )
        }
      })
    }
  ),
  .init { state, action, environment in
    enum DismissAllNotificationId {}

    switch action {
    case .onAppear:
      return environment.notificationCenter
        .publisher(for: dismissAllNotification)
        .compactMap { _ in .dismissAll }
        .eraseToEffect()
        .cancellable(id: DismissAllNotificationId.self)

    case .dismissAll:
      if state.colors.count > 1 {
        return .init(value: .content(.onDismiss))
      } else {
        return .none
      }

    case .content:
      return .none
    }
  }
)

@main
struct TestModalDismissalApp: App {
  typealias ViewStoreType = ViewStore<AppState, AppAction>
  let store = Store<AppState, AppAction>(
    initialState: .init(colors: [.white]),
    reducer: appReducer,
    environment: .live
  )

  var body: some Scene {
    WindowGroup {
      WithViewStore(store) { viewStore in
        ContentView(store: store.scope(
          state: \.contentState,
          action: AppAction.content
        ))
        .onAppear {
          viewStore.send(.onAppear)
        }
      }
    }
  }
}
