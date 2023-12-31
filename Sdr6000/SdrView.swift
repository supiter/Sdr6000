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
import Panafalls
import RadioPicker
import Shared

struct SdrView: View {
  let store: StoreOf<Sdr6000>
  
  @Dependency(\.objectModel) var objectModel

  @AppStorage("directEnabled", store: DefaultValues.flexStore) var directEnabled = false
  @AppStorage("localEnabled", store: DefaultValues.flexStore) var localEnabled = false
  @AppStorage("rxAudioEnabled", store: DefaultValues.flexStore) var rxAudioEnabled = false
  @AppStorage("smartlinkEnabled", store: DefaultValues.flexStore) var smartlinkEnabled = false
  @AppStorage("txAudioEnabled", store: DefaultValues.flexStore) var txAudioEnabled = false

  var body: some View {
    WithViewStore(self.store, observe: {$0} ) { viewStore in
      
      PanafallsView(store: Store(initialState: PanafallsFeature.State()) { PanafallsFeature() },
                    objectModel: objectModel)
      .toolbar{
        
        ToolbarItem(placement: .navigation) {
          Button(viewStore.connectionStatus == .connected ? "Disconnect" : "Connect") {
            viewStore.send(.ConnectDisconnect)
          }
          .frame(width: 100)
          .disabled(viewStore.connectionStatus == .inProcess)
        }
        
        ToolbarItem(placement: .navigation) {
          ControlGroup {
            Toggle(isOn: viewStore.binding(get: {_ in directEnabled}, send: .directButton)) {
              Text("Direct") }
            Toggle(isOn: viewStore.binding(get: {_ in localEnabled}, send: .localButton)) {
              Text("Local") }
            Toggle(isOn: viewStore.binding(get: {_ in smartlinkEnabled}, send: .smartlinkButton)) {
              Text("Smartlink") }
          }
          .controlGroupStyle(.navigation)
          .padding(.horizontal, 20)
          .disabled(viewStore.connectionStatus != .disconnected)
        }
        
        ToolbarItem {
          ControlGroup {
            Toggle(isOn: viewStore.binding(get: {_ in rxAudioEnabled}, send: .rxButton)) {
              Text("RxAudio") }
            Toggle(isOn: viewStore.binding(get: {_ in txAudioEnabled}, send: .txButton)) {
              Text("TxAudio") }
          }.controlGroupStyle(.navigation)
        }
      }
        
      // ---------- Initialization ----------
      // initialize on first appearance
      .onAppear() {
        viewStore.send(.onAppear)
      }
      
      // ---------- Sheet Management ----------
      // alert dialogs
      
      // FIXME: ????
      
//      Alert.init(state: \.alertState, action: .alertDismissed)
      
      
//      .alert(
//        self.store.scope(state: \.alertState, action: {_ in .alertDismissed}),
//        dismiss: .alertDismissed
//      )
//
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
    SdrView( store: Store(initialState: Sdr6000.State()) { Sdr6000() })
  }
}
