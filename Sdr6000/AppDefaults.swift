//
//  AppDefaults.swift
//  Sdr6000
//
//  Created by Douglas Adams on 8/8/23.
//

import ComposableArchitecture
import Foundation
import SwiftUI

// ----------------------------------------------------------------------------
// MARK: - Dependency decalarations

extension AppDefaults: DependencyKey {
  public static let liveValue = AppDefaults()
}

extension DependencyValues {
  public var appDefaults: AppDefaults {
    get {self[AppDefaults.self]}
    set {self[AppDefaults.self] = newValue}
  }
}

public final class AppDefaults: ObservableObject {
  static let flexStore = UserDefaults(suiteName: "group.net.k3tzr.flex")
  
  @AppStorage("alertOnError", store: flexStore) var alertOnError = false
  @AppStorage("clearOnSend", store: flexStore) var clearOnSend = false
  @AppStorage("clearOnStart", store: flexStore) var clearOnStart = false
  @AppStorage("clearOnStop", store: flexStore) var clearOnStop = false
  @AppStorage("directEnabled", store: flexStore) var directEnabled = false
  @AppStorage("fontSize", store: flexStore) var fontSize: Double = 12
  @AppStorage("isGui", store: flexStore) var isGui = true
  @AppStorage("localEnabled", store: flexStore) var localEnabled = false
  @AppStorage("loginRequired", store: flexStore) var loginRequired = false
  @AppStorage("markers", store: flexStore) var markers = false
  @AppStorage("rxAudioEnabled", store: flexStore) var rxAudioEnabled = false
  @AppStorage("smartlinkEnabled", store: flexStore) var smartlinkEnabled = false
  @AppStorage("smartlinkUser", store: flexStore) var smartlinkUser = ""
  @AppStorage("txAudioEnabled", store: flexStore) var txAudioEnabled = false
  @AppStorage("useDefault", store: flexStore) var useDefault = false
}
