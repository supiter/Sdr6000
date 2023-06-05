//
//  SdrView.swift
//  Sdr6000
//
//  Created by Douglas Adams on 6/3/23.
//

import ComposableArchitecture
import SwiftUI

import ClientDialog
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
  
  @AppStorage("openControlWindow") var openControlWindow = false
  @AppStorage("openLogWindow") var openLogWindow = false
  @AppStorage("leftSideIsOpen") var leftSideIsOpen = false
  @AppStorage("rightSideIsOpen") var rightSideIsOpen = false

  @State private var leftWidth: CGFloat = 200
  @State private var rightWidth: CGFloat = 100
  
  @Dependency(\.apiModel) var apiModel
  @Dependency(\.objectModel) var objectModel
  @Dependency(\.streamModel) var streamModel
  
  var body: some View {
    WithViewStore(self.store, observe: {$0} ) { viewStore in
      
      PanafallsView(store: Store(initialState: PanafallsFeature.State(), reducer: PanafallsFeature()),
                    objectModel: objectModel)
      .toolbar{
        ToolbarItem(placement: .navigation) {
          Button {
            leftSideIsOpen.toggle()
          } label: {
            Image(systemName: "sidebar.squares.left")
              .font(.system(size: 20))
          }
          .keyboardShortcut("l", modifiers: [.control, .command])
        }
        
        ToolbarItem { Spacer() }
        
        ToolbarItemGroup {
          Button(viewStore.isConnected ? "Disconnect" : "Connect") {
            viewStore.send(.ConnectDisconnect)
          }
          .disabled(viewStore.startStopDisabled)
          .keyboardShortcut(viewStore.isConnected ? .cancelAction : .defaultAction)
        }
        
        ToolbarItem { Spacer() }
        
        ToolbarItemGroup {
          Button("Pan") { viewStore.send(.panadapterButton) }
          Toggle("Tnfs", isOn: viewStore.binding( get: {_ in apiModel.radio?.tnfsEnabled ?? true }, send: .tnfButton))
            .disabled(apiModel.radio == nil)
          
          Toggle("Markers", isOn: viewStore.binding( get: \.rxAudio, send: .markerButton))
            .disabled(true)
          Toggle("RxAudio", isOn: viewStore.binding( get: \.rxAudio, send: .rxAudioButton))
          Toggle("TxAudio", isOn: viewStore.binding( get: \.txAudio, send: .txAudioButton))
        }
        
        ToolbarItem { Spacer() }
        
        ToolbarItem {
          Button {
            rightSideIsOpen.toggle()
          } label: {
            Image(systemName: "sidebar.squares.right")
              .font(.system(size: 20))
          }
        }
      }
      
      // ---------- Initialization ----------
      // initialize on first appearance
      .onAppear() {
        if openLogWindow { openWindow(id: WindowType.log.rawValue) }
        if openControlWindow { openWindow(id: WindowType.control.rawValue) }
        viewStore.send(.onAppear)
      }

      // ---------- Sheet Management ----------
      // alert dialogs
      .alert(
        self.store.scope(state: \.alertState),
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
    }
  }
}








//        ToolbarItemGroup(placement: .principal) {
//          Image(systemName: "speaker.wave.2.circle")
//            .font(.system(size: 24, weight: .regular))
//          Slider(value: .constant(50), in: 0...100, step: 1)
//            .frame(width: 100)
//          Image(systemName: "speaker.wave.2.circle")
//            .font(.system(size: 24, weight: .regular))
//          Slider(value: .constant(75), in: 0...100, step: 1)
//            .frame(width: 100)
//          Spacer()
//          Button("Log View") {  }
//
//          Button {
//            viewStore.send(.sidebarRightClicked)
//          } label: {
//            Image(systemName: "sidebar.right")
//              .font(.system(size: 18, weight: .regular))
//          }
//          .keyboardShortcut("r", modifiers: [.control, .command])
//          .disabled(!viewStore.isConnected)
//        }
//      }
//    }
//  }

struct SdrView_Previews: PreviewProvider {
  static var previews: some View {
    SdrView( store: Store(initialState: Sdr6000.State(), reducer: Sdr6000()))
  }
}
