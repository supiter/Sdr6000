//
//  SdrView.swift
//  Sdr6000
//
//  Created by Douglas Adams on 6/3/23.
//

import ComposableArchitecture
import SwiftUI

import ClientDialog
import FlexApi
import LoginDialog
import LogView
import MessagesView
import ObjectsView
import Panafalls
import RadioPicker
import Shared

struct SdrView: View {
  let store: StoreOf<Sdr6000>
  
  @Environment(\.openWindow) var openWindow

  @Dependency(\.apiModel) var apiModel
  @Dependency(\.objectModel) var objectModel
  @Dependency(\.streamModel) var streamModel
  
  var body: some View {
    WithViewStore(self.store, observe: {$0} ) { viewStore in
      
      PanafallsView(store: Store(initialState: PanafallsFeature.State(), reducer: PanafallsFeature()),
                    objectModel: objectModel)
      .toolbar{
        ToolbarItem (placement: .navigation){
          Button(viewStore.connectionStatus == .connected ? "Disconnect" : "Connect") {
            viewStore.send(.ConnectDisconnect)
          }
          .frame(width: 100)
          .disabled(viewStore.connectionStatus == .inProcess)
//          .keyboardShortcut(viewStore.connectionStatus == .connected ? .cancelAction : .defaultAction)
          .padding(.leading, 20)
        }
      }
        
      // ---------- Initialization ----------
      // initialize on first appearance
      .onAppear() {
        viewStore.send(.onAppear)
      }
      
      // ---------- Sheet Management ----------
      // alert dialogs
      .alert(
        self.store.scope(state: \.alertState, action: {_ in .alertDismissed}),
        dismiss: .alertDismissed
      )
      
      // Picker sheet
      .sheet(
        isPresented: viewStore.binding(
          get: { $0.pickerState != nil },
          send: Sdr6000.Action.picker(.cancelButton)),
        content: {
          IfLetStore(
            store.scope(state: \.pickerState, action: Sdr6000.Action.picker),
            then: PickerView.init(store:)
          )
        }
      )
      
      // Login sheet
      .sheet(
        isPresented: viewStore.binding(
          get: { $0.loginState != nil },
          send: Sdr6000.Action.login(.cancelButton)),
        content: {
          IfLetStore(
            store.scope(state: \.loginState, action: Sdr6000.Action.login),
            then: LoginView.init(store:)
          )
        }
      )
      
      // Client connection sheet
      .sheet(
        isPresented: viewStore.binding(
          get: { $0.clientState != nil },
          send: Sdr6000.Action.client(.cancelButton)),
        content: {
          IfLetStore(
            store.scope(state: \.clientState, action: Sdr6000.Action.client),
            then: ClientView.init(store:)
          )
        }
      )
      
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
        // observe openings of secondary windows
        if let window = notification.object as? NSWindow {
          if window.identifier?.rawValue  == "com_apple_SwiftUI_Settings_window" {
            window.level = .floating
          }
        }
      }
    }
  }
}

struct SdrView_Previews: PreviewProvider {
  static var previews: some View {
    SdrView( store: Store(initialState: Sdr6000.State(), reducer: Sdr6000()))
  }
}
