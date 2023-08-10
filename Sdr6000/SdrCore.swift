//
//  Sdr6000Core.swift
//  Sdr6000
//
//  Created by Douglas Adams on 6/3/23.
//

import ComposableArchitecture
import SwiftUI

import ClientDialog
import FlexApi
import Listener
import LoginDialog
//import LogView
//import MessagesView
import OpusPlayer
import Panafalls
import RadioPicker
import Shared
import XCGWrapper


public enum ConnectionStatus {
  case disconnected
  case inProcess
  case connected
}

// ----------------------------------------------------------------------------
// MARK: - Global Functions

/// Read a user default entry and transform it into a struct
/// - Parameters:
///    - key:         the name of the default
/// - Returns:        a struct or nil
public func getDefaultValue<T: Decodable>(_ key: String) -> T? {
  
  if let data = DefaultValues.flexStore?.object(forKey: key) as? Data {
    let decoder = JSONDecoder()
    if let value = try? decoder.decode(T.self, from: data) {
      return value
    } else {
      return nil
    }
  }
  return nil
}

/// Write a user default entry for a struct
/// - Parameters:
///    - key:        the name of the default
///    - value:      a struct  to be encoded and written to user defaults
public func setDefaultValue<T: Encodable>(_ key: String, _ value: T?) {
  
  if value == nil {
    DefaultValues.flexStore?.removeObject(forKey: key)
  } else {
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(value) {
      DefaultValues.flexStore?.set(encoded, forKey: key)
    } else {
      DefaultValues.flexStore?.removeObject(forKey: key)
    }
  }
}

public struct Sdr6000: Reducer {
  // ----------------------------------------------------------------------------
  // MARK: - Dependency decalarations
  
  @AppStorage("alertOnError", store: DefaultValues.flexStore) var alertOnError = false
  @AppStorage("clearOnSend", store: DefaultValues.flexStore) var clearOnSend = false
  @AppStorage("clearOnStart", store: DefaultValues.flexStore) var clearOnStart = false
  @AppStorage("clearOnStop", store: DefaultValues.flexStore) var clearOnStop = false
  @AppStorage("directEnabled", store: DefaultValues.flexStore) var directEnabled = false
  @AppStorage("fontSize", store: DefaultValues.flexStore) var fontSize: Double = 12
  @AppStorage("isGui", store: DefaultValues.flexStore) var isGui = true
  @AppStorage("localEnabled", store: DefaultValues.flexStore) var localEnabled = false
  @AppStorage("loginRequired", store: DefaultValues.flexStore) var loginRequired = false
  @AppStorage("markers", store: DefaultValues.flexStore) var markers = false
  @AppStorage("rxAudioEnabled", store: DefaultValues.flexStore) var rxAudioEnabled = false
  @AppStorage("smartlinkEnabled", store: DefaultValues.flexStore) var smartlinkEnabled = false
  @AppStorage("smartlinkUser", store: DefaultValues.flexStore) var smartlinkUser = ""
  @AppStorage("txAudioEnabled", store: DefaultValues.flexStore) var txAudioEnabled = false
  @AppStorage("useDefault", store: DefaultValues.flexStore) var useDefault = false
  
//  @Dependency(\.appDefaults) var appDefaults
  @Dependency(\.apiModel) var apiModel
  @Dependency(\.objectModel) var objectModel
  @Dependency(\.listener) var listener
  //  @Dependency(\.opusPlayer) var opusPlayer
  @Dependency(\.streamModel) var streamModel
  
  // ----------------------------------------------------------------------------
  // MARK: - Module Initialization
  
  public init() {}
  
  // ----------------------------------------------------------------------------
  // MARK: - State
  
  public struct State: Equatable {
    // State held in User Defaults
    var guiDefault: DefaultValue? { didSet { setDefaultValue("guiDefault", guiDefault) } }
    var nonGuiDefault: DefaultValue? { didSet { setDefaultValue("nonGuiDefault", nonGuiDefault) } }
    
    // other state
    var commandToSend = ""
    var isClosing = false
    var gotoLast = false
    var initialized = false
    
    var connectionStatus: ConnectionStatus = .disconnected
    
    var opusPlayer: OpusPlayer?
    var pickables = IdentifiedArrayOf<Pickable>()
    var station: String? = nil
    
    // subview state
    var alertState: AlertState<Sdr6000.Action>?
    var clientState: ClientFeature.State?
    var loginState: LoginFeature.State? = nil
    var pickerState: PickerFeature.State? = nil
    
    var previousCommand = ""
    var commandsIndex = 0
    var commandsArray = [""]
    
    // ----------------------------------------------------------------------------
    // MARK: - State Initialization
    
    public init(
      guiDefault: DefaultValue? = getDefaultValue("guiDefault"),
      nonGuiDefault: DefaultValue? = getDefaultValue("nonGuiDefault")
    )
    {
      self.guiDefault = guiDefault
      self.nonGuiDefault = nonGuiDefault
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Actions
  public enum Action: Equatable {
    // initialization
    case onAppear
    
    // UI controls
    case ConnectDisconnect
    case loginRequired
    case directButton
    case localButton
    case smartlinkButton
    case rxButton
    case txButton
    
    // Subview related
    case alertDismissed
    case client(ClientFeature.Action)
    case login(LoginFeature.Action)
    case picker(PickerFeature.Action)
    
    // Effects related
    case connect(Pickable, UInt32?)
    case connectionStatus(ConnectionStatus)
    case loginStatus(Bool, String)
    
    // Sheet related
    case showClientSheet(Pickable, [String], [UInt32])
    case showErrorAlert(ApiError)
    case showLogAlert(LogEntry)
    case showLoginSheet
    case showPickerSheet
    
    // Subscription related
    case packetEvent(PacketEvent)
    case clientEvent(ClientEvent)
    case testResult(TestResult)
  }
  
  public var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
        // ----------------------------------------------------------------------------
        // MARK: - Actions: ApiView Initialization
        
      case .onAppear:
        // if the first time, start various effects
        if state.initialized == false {
          state.initialized = true
          // instantiate the Logger,
          _ = XCGWrapper(logLevel: .debug, group: DefaultValues.flexSuite)
          
          if !smartlinkEnabled && !localEnabled && !directEnabled {
            state.alertState = AlertState(title: TextState("Select a Connection Mode\n\n(Direct, Local or Smartlink)"))
          }
          // start subscriptions
          return .merge(
            subscribeToPackets(listener.packetStream),
            subscribeToClients(listener.clientStream),
            subscribeToLogAlerts(),
            subscribeToTestResults(listener.testStream),
            initializeMode(state, listener, localEnabled, smartlinkEnabled, smartlinkUser, loginRequired)
          )
        }
        return .none
        
        // ----------------------------------------------------------------------------
        // MARK: - Actions: ApiView UI controls
        
      case .ConnectDisconnect:
        if state.connectionStatus != .disconnected {
          state.connectionStatus = .inProcess
          // ----- STOP -----
//          if clearOnStop { messagesModel.clearAll() }
          return .run { send in
            await apiModel.disconnect()
            await send(.connectionStatus(.disconnected))
          }
          
        } else if state.connectionStatus == .disconnected {
          // ----- START -----
          state.connectionStatus = .inProcess
//          if clearOnStart { messagesModel.clearAll() }
          
          // use the default?
          if useDefault {
            // YES, use the Default
            return .run { [state] send in
              if let packet = listener.findPacket(for: state.guiDefault, state.nonGuiDefault, isGui) {
                // valid default
                let pickable = Pickable(packet: packet, station: isGui ? "" : state.nonGuiDefault?.station ?? "")
                await send( checkConnectionStatus(isGui, pickable) )
              } else {
                // invalid default
                await send(.showPickerSheet)
              }
            }
          }
          // default not in use, open the Picker
          return .run {send in await send(.showPickerSheet) }
        }
        return .none
        
      case .loginRequired:
        loginRequired.toggle()
//        return initializeMode(state, listener, localEnabled, smartlinkEnabled, smartlinkEmail, loginRequired)
        return .none
        
      case .directButton:
        directEnabled.toggle()
        return .none
        
      case .localButton:
        localEnabled.toggle()
        listener.localMode(localEnabled)
        return .none
        
      case .smartlinkButton:
        smartlinkEnabled.toggle()
        return .run { send in
          if await listener.smartlinkMode(smartlinkEnabled) {
            if loginRequired && smartlinkEnabled {
              // Smartlink login is required
              await send(.showLoginSheet)
            }
          } else {
            // Wan listener was required and failed to start
            await send(.showLoginSheet)
          }
        }
        

//        return .run { send in
//          // set the connection mode, start the Lan and/or Wan listener
//          if await listener.setConnectionMode(localEnabled, smartlinkEnabled, smartlinkEmail) {
//        }

      case .rxButton:
        rxAudioEnabled.toggle()
        if state.connectionStatus == .connected {
          if rxAudioEnabled {
            return startRxAudio(&state, apiModel, streamModel)
          } else {
            return stopRxAudio(&state, objectModel, streamModel)
          }
        }
        return .none
        
      case .txButton:
        txAudioEnabled.toggle()
        if state.connectionStatus == .connected {
          if txAudioEnabled {
            return startTxAudio(&state, apiModel, streamModel)
          } else {
            return stopTxAudio(&state, objectModel, streamModel)
          }
        }
        return .none
        
        // ----------------------------------------------------------------------------
        // MARK: - Actions: invoked by other actions
        
      case let .connect(selection, disconnectHandle):
        state.clientState = nil
        return .run { send in
//          messagesModel.start()
          // attempt to connect to the selected Radio / Station
          do {
            // try to connect
            try await apiModel.connect(selection: selection,
                                       isGui: isGui,
                                       disconnectHandle: disconnectHandle,                                       
                                       programName: "Sdr6000")
            await send(.connectionStatus(.connected))
          } catch {
            // connection attempt failed
            await send(.showErrorAlert( error as! ApiError ))
            await send(.connectionStatus(.disconnected))
          }
        }
        
      case let .connectionStatus(connectionStatus):
        state.connectionStatus = connectionStatus
        if state.connectionStatus == .connected && rxAudioEnabled {
          return startRxAudio(&state, apiModel, streamModel)
        } else if state.connectionStatus == .disconnected && rxAudioEnabled {
          return stopRxAudio(&state, objectModel, streamModel)
        }
        return .none
        
      case let .loginStatus(success, user):
        // a smartlink login was completed
        if success {
          // save the User
          smartlinkUser = user
          loginRequired = false
        } else {
          // tell the user it failed
          state.alertState = AlertState(title: TextState("Smartlink login failed for \(user)"))
        }
        return .none
        
        // ----------------------------------------------------------------------------
        // MARK: - Actions: to display a sheet
        
      case let .showClientSheet(selection, stations, handles):
        state.clientState = ClientFeature.State(selection: selection, stations: stations, handles: handles)
        return .none
        
      case let .showErrorAlert(error):
        state.alertState = AlertState(title: TextState("An Error occurred"), message: TextState(error.rawValue))
        return .none
        
      case .showLoginSheet:
        state.loginState = LoginFeature.State(heading: "Smartlink Login Required", user: smartlinkUser)
        return .none
        
      case .showPickerSheet:
        var pickables: IdentifiedArrayOf<Pickable>
        if isGui {
          pickables = listener.getPickableRadios()
        } else {
          pickables = listener.getPickableStations()
        }
        state.pickerState = PickerFeature.State(pickables: pickables, defaultValue: isGui ? state.guiDefault : state.nonGuiDefault, isGui: isGui)
        return .none
        
        // ----------------------------------------------------------------------------
        // MARK: - Actions: invoked by subscriptions
        
      case let .clientEvent(event):
        // a GuiClient change occurred
        switch event.action {
        case .added:
          return .none
          
        case .removed:
          return .run {[isGui = isGui, station = state.station] _ in
            // if nonGui, is it our connected Station?
            if isGui == false && event.client.station == station {
              // YES, unbind
              await objectModel.setActiveStation( nil )
              apiModel.bindToGuiClient(nil)
            }
          }
          
        case .completed:
          return .run { [isGui = isGui, station = state.station] _ in
            // if nonGui, is there a clientId for our connected Station?
            if isGui == false && event.client.station == station {
              // YES, bind to it
              await objectModel.setActiveStation( event.client.station )
              apiModel.bindToGuiClient(event.client.clientId)
            }
          }
        }
        
      case let .showLogAlert(logEntry):
        if alertOnError {
          // a Warning or Error has been logged, exit any sheet states
          state.clientState = nil
          state.loginState = nil
          state.pickerState = nil
          // alert the user
          state.alertState = .init(title: TextState("\(logEntry.level == .warning ? "A Warning" : "An Error") was logged:"),
                                   message: TextState(logEntry.msg))
        }
        return .none
        
      case .packetEvent(_):
        if state.pickerState != nil {
          var pickables: IdentifiedArrayOf<Pickable>
          if isGui {
            pickables = listener.getPickableRadios()
          } else {
            pickables = listener.getPickableStations()
          }
          state.pickerState = PickerFeature.State(pickables: pickables, defaultValue: isGui ? state.guiDefault : state.nonGuiDefault, isGui: isGui)
        }
        return .none
        
      case let .testResult(result):
        // a test result has been received
        state.pickerState?.testResult = result.success
        return .none
        
        // ----------------------------------------------------------------------------
        // MARK: - Login Actions (LoginFeature -> ApiView)
        
      case .login(.cancelButton):
        state.loginState = nil
        loginRequired = false
        return .none
        
      case let .login(.loginButton(user, pwd)):
        state.loginState = nil
        // try a Smartlink login
        return .run { send in
          let success = await listener.startWan(user, pwd)
          if success {
            //            let secureStore = SecureStore(service: "Api6000Tester-C")
            //            _ = secureStore.set(account: "user", data: user)
            //            _ = secureStore.set(account: "pwd", data: pwd)
          }
          await send(.loginStatus(success, user))
        }
        
      case .login(_):
        // IGNORE ALL OTHER login actions
        return .none
        
        // ----------------------------------------------------------------------------
        // MARK: - Picker Actions (PickerFeature -> ApiView)
        
      case .picker(.cancelButton):
        state.pickerState = nil
        state.connectionStatus = .disconnected
        return .none
        
      case let .picker(.connectButton(selection)):
        // close the Picker sheet
        state.pickerState = nil
        // save the station (if any)
        state.station = selection.station
        // check for other connections
        return .run { send in
          await send(checkConnectionStatus(isGui, selection))
        }
        
      case let .picker(.defaultButton(selection)):
        // SET / RESET the default
        if isGui {
          // GUI
          let newValue = DefaultValue(selection)
          if state.guiDefault == newValue {
            state.guiDefault = nil
          } else {
            state.guiDefault = newValue
          }
        } else {
          // NONGUI
          let newValue = DefaultValue(selection)
          if state.nonGuiDefault == newValue {
            state.nonGuiDefault = nil
          } else {
            state.nonGuiDefault = newValue
          }
        }
        state.pickerState!.defaultValue = isGui ? state.guiDefault : state.nonGuiDefault
        return .none
        
      case let .picker(.testButton(selection)):
        state.pickerState?.testResult = false
        // send a Test request
        return .run {_ in listener.sendWanTest(selection.packet.serial) }
        
      case .picker(_):
        // IGNORE ALL OTHER picker actions
        return .none
        
        // ----------------------------------------------------------------------------
        // MARK: - Client Actions (ClientFeature -> ApiView)
        
      case .client(.cancelButton):
        state.clientState = nil
        state.connectionStatus = .disconnected
        return .none
        
      case let .client(.connect(selection, disconnectHandle)):
        state.clientState = nil
        return .run { send in
          await send(.connect(selection, disconnectHandle))
        }
        
        // ----------------------------------------------------------------------------
        // MARK: - Alert Actions
        
      case .alertDismissed:
        state.alertState = nil
        return .none
      }
    }
    
    // ClientFeature logic
    .ifLet(\.clientState, action: /Action.client) {
      ClientFeature()
    }
    // LoginFeature logic
    .ifLet(\.loginState, action: /Action.login) {
      LoginFeature()
    }
    // PickerFeature logic
    .ifLet(\.pickerState, action: /Action.picker) {
      PickerFeature()
    }
  }
}

// ----------------------------------------------------------------------------
// MARK: - Private Effect methods

private func checkConnectionStatus(_ isGui: Bool, _ selection: Pickable) async -> Sdr6000.Action {
  // Gui connection with othe stations?
  if isGui && selection.packet.guiClients.count > 0 {
    // YES, may need a disconnect
    var stations = [String]()
    var handles = [UInt32]()
    for client in selection.packet.guiClients {
      stations.append(client.station)
      handles.append(client.handle)
    }
    // show the client chooser, let the user choose
    return .showClientSheet(selection, stations, handles)
  }
  else {
    // not Gui connection or Gui without other stations, attempt to connect
    return .connect(selection, nil)
  }
}

func initializeMode(_ state: Sdr6000.State, _ listener: Listener, _ localEnabled: Bool, _ smartlinkEnabled: Bool, _ smartlinkEmail: String, _ loginRequired: Bool) ->  Effect<Sdr6000.Action> {
  // start / stop listeners as appropriate for the Mode
  return .run { send in
    // set the connection mode, start the Lan and/or Wan listener
    if await listener.setConnectionMode(localEnabled, smartlinkEnabled, smartlinkEmail) {
      if loginRequired && smartlinkEnabled {
        // Smartlink login is required
        await send(.showLoginSheet)
      }
    } else {
      // Wan listener was required and failed to start
      await send(.showLoginSheet)
    }
  }
}

private func startRxAudio(_ state: inout Sdr6000.State, _ apiModel: ApiModel, _ streamModel: StreamModel) ->  Effect<Sdr6000.Action> {
  // start player
  state.opusPlayer = OpusPlayer()
  return .run { [state] _ in
    // request a stream
    if let id = try await apiModel.requestRemoteRxAudioStream().streamId {
      // finish audio setup
      state.opusPlayer!.start(id: id)
      streamModel.remoteRxAudioStreams[id: id]?.delegate = state.opusPlayer
    } else {
      print("NO Id")
    }
  }
}

private func stopRxAudio(_ state: inout Sdr6000.State, _ objectModel: ObjectModel, _ streamModel: StreamModel) ->  Effect<Sdr6000.Action> {
  state.opusPlayer?.stop()
  if let id = state.opusPlayer?.id {
    // remove player and stream
    state.opusPlayer = nil
    return .run { _ in
      await streamModel.sendRemoveStream(id)
    }
  }
  return .none
}

private func startTxAudio(_ state: inout Sdr6000.State, _ apiModel: ApiModel, _ streamModel: StreamModel) ->  Effect<Sdr6000.Action> {
  // FIXME:
  print("----->>>>> startTxAudio // FIXME:")
  return .none
}

private func stopTxAudio(_ state: inout Sdr6000.State, _ objectModel: ObjectModel, _ streamModel: StreamModel) ->  Effect<Sdr6000.Action> {
  // FIXME:
  print("----->>>>> stopTxAudio // FIXME:")
  return .none
}

// ----------------------------------------------------------------------------
// MARK: - Subscription methods

private func subscribeToPackets(_ stream: AsyncStream<PacketEvent>) ->  Effect<Sdr6000.Action> {
  return .run { send in
    for await event in stream {
      // a guiClient has been added / updated or deleted
      await send(.packetEvent(event))
    }
  }
}

private func subscribeToClients(_ stream: AsyncStream<ClientEvent>) ->  Effect<Sdr6000.Action> {
  return .run { send in
    for await event in stream {
      // a guiClient has been added / updated or deleted
      await send(.clientEvent(event))
    }
  }
}

private func subscribeToLogAlerts() ->  Effect<Sdr6000.Action>  {
  return .run { send in
    for await entry in logAlerts {
      // a Warning or Error has been logged.
      await send(.showLogAlert(entry))
    }
  }
}

private func subscribeToTestResults(_ stream: AsyncStream<TestResult>) ->  Effect<Sdr6000.Action>  {
  return .run { send in
    for await result in stream {
      // a Smartlink test result was received
      await send(.testResult(result))
    }
  }
}

