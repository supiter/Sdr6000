//
//  Sdr6000App.swift
//  Sdr6000
//
//  Created by Douglas Adams on 6/3/23.
//

import ComposableArchitecture
import SwiftUI

import FlexApi
//import LogView
//import MessagesView
import SettingsPanel
import SidePanel
import Shared

public enum WindowType: String {
  case controls = "Controls"
//  case messages = "Messages"
  case settings = "Settings"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    // disable tab view
    NSWindow.allowsAutomaticWindowTabbing = false
  }
    
  func applicationWillTerminate(_ notification: Notification) {
    log("Sdr6000: application terminated", .debug, #function, #file, #line)
  }
  
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}

@main
struct Sdr6000App: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self)
  var appDelegate

  @Dependency(\.apiModel) var apiModel
//  @Dependency(\.messagesModel) var messagesModel
  @Dependency(\.objectModel) var objectModel
  @Dependency(\.streamModel) var streamModel

  var body: some Scene {
    
    // Main window
    WindowGroup("Sdr6000  (v" + Version().string + ")") {
      SdrView(store: Store(initialState: Sdr6000.State()) { Sdr6000() })
    }
    .windowToolbarStyle(.unified)

    // Controls window
    Window(WindowType.controls.rawValue, id: WindowType.controls.rawValue) {
      SideControlView(store: Store(initialState: SideControlFeature.State()) { SideControlFeature() }, apiModel: apiModel, objectModel: objectModel)
      .frame(minHeight: 210)
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(WindowResizability.contentSize)
    .defaultPosition(.topTrailing)
    .keyboardShortcut("c", modifiers: [.option, .command])
            
    // Settings window
    Settings {
      SettingsView(store: Store(initialState: SettingsPanel.State()) { SettingsPanel() }, objectModel: objectModel, apiModel: apiModel)
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(WindowResizability.contentSize)
    .defaultPosition(.bottomLeading)
    
//    // Messages window
//    Window(WindowType.messages.rawValue, id: WindowType.messages.rawValue) {
//      MessagesView(store: Store(initialState: MessagesFeature.State(), reducer: MessagesFeature()), messagesModel: messagesModel )
//      .frame(minWidth: 975)
//    }
//    .windowStyle(.hiddenTitleBar)
//    .defaultPosition(.bottomTrailing)
//    .keyboardShortcut("m", modifiers: [.option, .command])

    .commands {
      //remove the "New" menu item
      CommandGroup(replacing: CommandGroupPlacement.newItem) {}
    }
  }
}
