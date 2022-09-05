//
//  TestModalDismissalApp.swift
//  TestModalDismissal
//
//  Created by Art Huang on 2022/9/5.
//

import SwiftUI

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
  case content(ContentAction)
}

struct AppEnvironment {}

extension AppEnvironment {
  static var live = Self()
}

let appReducer = Reducer<
  AppState,
  AppAction,
  AppEnvironment
>.combine(
  contentReducer.pullback(
    state: \.contentState,
    action: /AppAction.content,
    environment: { _ in .live }
  )
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
      }
    }
  }
}
