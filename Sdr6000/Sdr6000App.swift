//
//  Sdr6000App.swift
//  Sdr6000
//
//  Created by Douglas Adams on 6/3/23.
//

import ComposableArchitecture
import SwiftUI

import FlexApi
import LogView
import SettingsPanel
import SidePanel
import Shared

enum WindowType: String {
  case log = "Log"
  case controls = "Controls"
  case settings = "Settings"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    // disable tab view
    NSWindow.allowsAutomaticWindowTabbing = false
    // disable restoring windows
    UserDefaults.standard.register(defaults: ["NSQuitAlwaysKeepsWindows" : false])
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
  @Dependency(\.objectModel) var objectModel
  @Dependency(\.streamModel) var streamModel

  var body: some Scene {
    
    // Main window
    WindowGroup("Sdr6000  (v" + Version().string + ")") {
      SdrView(store: Store(initialState: Sdr6000.State(), reducer: Sdr6000()))
    }
    .windowToolbarStyle(.unified)
    
    // Log window
    Window(WindowType.log.rawValue, id: WindowType.log.rawValue) {
      LogView(store: Store(initialState: LogFeature.State(), reducer: LogFeature()) )
      .frame(minWidth: 975)
    }
    .windowStyle(.hiddenTitleBar)
    .defaultPosition(.bottomTrailing)

    // Controls window
    Window(WindowType.controls.rawValue, id: WindowType.controls.rawValue) {
      SideControlView(store: Store(initialState: SideControlFeature.State(), reducer: SideControlFeature()), apiModel: apiModel, objectModel: objectModel)
      .frame(minHeight: 210)
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(WindowResizability.contentSize)
    .defaultPosition(.topTrailing)
            
    // Settings window
    Settings {
      SettingsView(store: Store(initialState: SettingsFeature.State(), reducer: SettingsFeature()), objectModel: objectModel, apiModel: apiModel)
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(WindowResizability.contentSize)
    .defaultPosition(.bottomLeading)
    
    .commands {
      //remove the "New" menu item
      CommandGroup(replacing: CommandGroupPlacement.newItem) {}
    }
  }
}
