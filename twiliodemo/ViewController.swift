//
//  ViewController.swift
//  twiliodemo
//
//  Created by eHeuristic on 03/02/20.
//  Copyright © 2020 eHeuristic. All rights reserved.
//

import UIKit
import TwilioVoice
import PushKit
import AVFoundation
import CallKit

var accessTokenEndpoint = "Your accesstoken"  // your access token accesstoken
let identity = "alice"
let twimlParamTo = "to"

class ViewController: UIViewController, TVONotificationDelegate, TVOCallDelegate, CXProviderDelegate, UITextFieldDelegate {
    
    
    @IBOutlet weak var placeCallButton: UIButton!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var outgoingValue: UITextField!
    @IBOutlet weak var callControlView: UIView!
    @IBOutlet weak var muteSwitch: UISwitch!
    @IBOutlet weak var speakerSwitch: UISwitch!
    
    
    var deviceTokenString: String?
    //var voipRegistry: PKPushRegistry
    var incomingPushCompletionCallback: (()->Swift.Void?)? = nil
    
    var incomingAlertController: UIAlertController?
    
    var callInvite: TVOCallInvite?
    var call: TVOCall?
    var callKitCompletionCallback: ((Bool)->Swift.Void?)? = nil
    var audioDevice: TVODefaultAudioDevice = TVODefaultAudioDevice()
    
    let callKitProvider: CXProvider
    let callKitCallController: CXCallController
    var userInitiatedDisconnect: Bool = false
    
    required init?(coder aDecoder: NSCoder) {
        
        let configuration = CXProviderConfiguration(localizedName: "CallKit Quickstart")
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        callKitProvider = CXProvider(configuration: configuration)
        callKitCallController = CXCallController()
        
        super.init(coder: aDecoder)
        
        callKitProvider.setDelegate(self, queue: nil)
        // voipRegistry.desiredPushTypes = Set([PKPushType.voIP])
    }
    
    deinit {
        // CallKit has an odd API contract where the developer must call invalidate or the CXProvider is leaked.
        callKitProvider.invalidate()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /* toggleUIState(isEnabled: true, showCallControl: false)
         outgoingValue.delegate = self */
        TwilioVoice.audioDevice = audioDevice
        self.APIForToken()
    }
    
    
    ///call API for accesstoken it's our server side configreation to get token from twilio
    func APIForToken()
    {
        let headers = ["postman-token": "ec61a584-bb58-5124-649a-6820fcbb5a85"]
        let request = NSMutableURLRequest(url: NSURL(string: "your url")! as URL,
                                          cachePolicy: .useProtocolCachePolicy,
                                          timeoutInterval: 10.0)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        let session = URLSession.shared
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            if (error != nil) {
            } else {
                if data != nil {
                    if let returnData = String(data: data!, encoding: .utf8) {
                        print(returnData)
                        accessTokenEndpoint = returnData
                    }
                    else {
                        let alert = UIAlertController(title: "Error", message: "Token Not Found", preferredStyle: UIAlertController.Style.alert)
                        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
                        alert.addAction(UIAlertAction(title: "Retry", style: UIAlertAction.Style.default, handler: { (retry) in
                            self.APIForToken()
                        }))
                    }
                }
            }
        })
        dataTask.resume()
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    /* func fetchAccessToken() -> String? {
     let endpointWithIdentity = String(format: "%@?identity=%@", accessTokenEndpoint, identity)
     guard let accessTokenURL = URL(string: baseURLString + endpointWithIdentity) else {
     return nil
     }
     
     return try? String.init(contentsOf: accessTokenURL, encoding: .utf8)
     }*/
    
    /* func toggleUIState(isEnabled: Bool, showCallControl: Bool) {
     placeCallButton.isEnabled = isEnabled
     if (showCallControl) {
     callControlView.isHidden = false
     muteSwitch.isOn = false
     speakerSwitch.isOn = true
     
     } else {
     callControlView.isHidden = true
     }
     } */
    
    
    
    @IBAction func placeCall(_ sender: UIButton) {
        
        if (self.call != nil && self.call?.state == .connected) {
            self.userInitiatedDisconnect = true
            performEndCallAction(uuid: self.call!.uuid)
            // self.toggleUIState(isEnabled: false, showCallControl: false)
        } else {
            let uuid = UUID()
            let handle = "Voice Bot"
            
            self.checkRecordPermission { (permissionGranted) in
                if (!permissionGranted) {
                    let alertController: UIAlertController = UIAlertController(title: "Voice Quick Start",
                                                                               message: "Microphone permission not granted",
                                                                               preferredStyle: .alert)
                    
                    let continueWithMic: UIAlertAction = UIAlertAction(title: "Continue without microphone",
                                                                       style: .default,
                                                                       handler: { (action) in
                                                                        self.performStartCallAction(uuid: uuid, handle: handle)
                    })
                    alertController.addAction(continueWithMic)
                    
                    let goToSettings: UIAlertAction = UIAlertAction(title: "Settings",
                                                                    style: .default,
                                                                    handler: { (action) in
                                                                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                                                  options: [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly: false],
                                                                                                  completionHandler: nil)
                    })
                    alertController.addAction(goToSettings)
                    
                    let cancel: UIAlertAction = UIAlertAction(title: "Cancel",
                                                              style: .cancel,
                                                              handler: { (action) in
                                                                // self.toggleUIState(isEnabled: true, showCallControl: false)
                                                                //self.stopSpin()
                    })
                    alertController.addAction(cancel)
                    
                    self.present(alertController, animated: true, completion: nil)
                } else {
                    self.performStartCallAction(uuid: uuid, handle: handle)
                }
            }
        }
    }
    
    func checkRecordPermission(completion: @escaping (_ permissionGranted: Bool) -> Void) {
        let permissionStatus: AVAudioSession.RecordPermission = AVAudioSession.sharedInstance().recordPermission
        
        switch permissionStatus {
        case AVAudioSession.RecordPermission.granted:
            // Record permission already granted.
            completion(true)
            break
        case AVAudioSession.RecordPermission.denied:
            // Record permission denied.
            completion(false)
            break
        case AVAudioSession.RecordPermission.undetermined:
            // Requesting record permission.
            // Optional: pop up app dialog to let the users know if they want to request.
            AVAudioSession.sharedInstance().requestRecordPermission({ (granted) in
                completion(granted)
            })
            break
        default:
            completion(false)
            break
        }
    }
    
    @IBAction func muteSwitchToggled(_ sender: UISwitch) {
        if let call = call {
            call.isMuted = sender.isOn
        } else {
            print("No active call to be muted")
        }
        
    }
    
    @IBAction func speakerSwitchToggled(_ sender: UISwitch) {
        toggleAudioRoute(toSpeaker: sender.isOn)
    }
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        outgoingValue.resignFirstResponder()
        return true
    }
    
    
    // MARK: PKPushRegistryDelegate
    /*  func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
     print("pushRegistry:didUpdatePushCredentials:forType:")
     
     if (type != .voIP) {
     return
     }
     
     guard let accessToken = fetchAccessToken() else {
     return
     }
     
     let deviceToken = (credentials.token as NSData).description
     
     TwilioVoice.register(withAccessToken: accessToken, deviceToken: deviceToken) { (error) in
     if let error = error {
     print("An error occurred while registering: \(error.localizedDescription)")
     }
     else {
     print("Successfully registered for VoIP push notifications.")
     }
     }
     self.deviceTokenString = deviceToken
     
     }
     
     func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
     print("pushRegistry:didInvalidatePushTokenForType:")
     
     if (type != .voIP) {
     return
     }
     
     guard let deviceToken = deviceTokenString, let accessToken = fetchAccessToken() else {
     return
     }
     
     TwilioVoice.unregister(withAccessToken: accessToken, deviceToken: deviceToken) { (error) in
     if let error = error {
     print("An error occurred while unregistering: \(error.localizedDescription)")
     }
     else {
     print("Successfully unregistered from VoIP push notifications.")
     }
     }
     
     self.deviceTokenString = nil
     }
     
     /**
     * Try using the `pushRegistry:didReceiveIncomingPushWithPayload:forType:withCompletionHandler:` method if
     * your application is targeting iOS 11. According to the docs, this delegate method is deprecated by Apple.
     */
     func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
     print("pushRegistry:didReceiveIncomingPushWithPayload:forType:")
     
     if (type == PKPushType.voIP) {
     TwilioVoice.handleNotification(payload.dictionaryPayload, delegate: self)
     }
     }
     
     /**
     * This delegate method is available on iOS 11 and above. Call the completion handler once the
     * notification payload is passed to the `TwilioVoice.handleNotification()` method.
     */
     func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
     print("pushRegistry:didReceiveIncomingPushWithPayload:forType:completion:")
     // Save for later when the notification is properly handled.
     self.incomingPushCompletionCallback = completion
     
     if (type == PKPushType.voIP) {
     TwilioVoice.handleNotification(payload.dictionaryPayload, delegate: self)
     }
     }
     
     func incomingPushHandled() {
     if let completion = self.incomingPushCompletionCallback {
     completion()
     self.incomingPushCompletionCallback = nil
     }
     }*/
    
    // MARK: TVONotificaitonDelegate
    func callInviteReceived(_ callInvite: TVOCallInvite) {
        print("callInviteReceived:")
        
        if (self.callInvite != nil) {
            print("A CallInvite is already in progress. Ignoring the incoming CallInvite from \(callInvite.from)")
            return;
        } else if (self.call != nil) {
            print("Already an active call.");
            return;
        }
        
        self.callInvite = callInvite
        
        // reportIncomingCall(from: "Voice Bot", uuid: callInvite.uuid)
    }
    
    func cancelledCallInviteReceived(_ cancelledCallInvite: TVOCancelledCallInvite) {
        print("cancelledCallInviteCanceled:")
        
        if (self.callInvite == nil ||
            self.callInvite!.callSid != cancelledCallInvite.callSid) {
            print("No matching pending CallInvite. Ignoring the Cancelled CallInvite")
            return
        }
        
        performEndCallAction(uuid: self.callInvite!.uuid)
        
        self.callInvite = nil
    }
    
    // MARK: TVOCallDelegate
    func callDidConnect(_ call: TVOCall) {
        print("callDidConnect:")
        
        self.call = call
        self.callKitCompletionCallback!(true)
        self.callKitCompletionCallback = nil
        
        self.placeCallButton.setTitle("Hang Up", for: .normal)
        
        //  toggleUIState(isEnabled: true, showCallControl: true)
        // stopSpin()
        toggleAudioRoute(toSpeaker: false)
    }
    
    func call(_ call: TVOCall, didFailToConnectWithError error: Error) {
        print("Call failed to connect: \(error.localizedDescription)")
        
        if let completion = self.callKitCompletionCallback {
            completion(false)
        }
        
        performEndCallAction(uuid: call.uuid)
        callDisconnected()
    }
    
    func call(_ call: TVOCall, didDisconnectWithError error: Error?) {
        if let error = error {
            print("Call failed: \(error.localizedDescription)")
        } else {
            
            print("Call disconnected")
            
        }
        
        if !self.userInitiatedDisconnect {
            var reason = CXCallEndedReason.remoteEnded
            
            if error != nil {
                reason = .failed
            }
            
            self.callKitProvider.reportCall(with: call.uuid, endedAt: Date(), reason: reason)
        }
        
        callDisconnected()
    }
    
    func callDisconnected() {
        self.call = nil
        self.callKitCompletionCallback = nil
        self.userInitiatedDisconnect = false
        
        // stopSpin()
        // toggleUIState(isEnabled: true, showCallControl: false)
        self.placeCallButton.setTitle("Call", for: .normal)
    }
    
    
    // MARK: AVAudioSession
    func toggleAudioRoute(toSpeaker: Bool) {
        audioDevice.block = {
            kDefaultAVAudioSessionConfigurationBlock()
            do {
                if (toSpeaker) {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                } else {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                }
            } catch {
                print(error.localizedDescription)
            }
        }
        audioDevice.block()
    }
    
    
    // MARK: Icon spinning
    /*  func startSpin() {
     if (isSpinning != true) {
     isSpinning = true
     spin(options: UIView.AnimationOptions.curveEaseIn)
     }
     }
     
     func stopSpin() {
     isSpinning = false
     }
     
     func spin(options: UIView.AnimationOptions) {
     UIView.animate(withDuration: 0.5,
     delay: 0.0,
     options: options,
     animations: { [weak iconView] in
     if let iconView = iconView {
     iconView.transform = iconView.transform.rotated(by: CGFloat(Double.pi/2))
     }
     }) { [weak self] (finished: Bool) in
     guard let strongSelf = self else {
     return
     }
     
     if (finished) {
     if (strongSelf.isSpinning) {
     strongSelf.spin(options: UIView.AnimationOptions.curveLinear)
     } else if (options != UIView.AnimationOptions.curveEaseOut) {
     strongSelf.spin(options: UIView.AnimationOptions.curveEaseOut)
     }
     }
     }
     }*/
    
    // MARK: CXProviderDelegate
    func providerDidReset(_ provider: CXProvider) {
        print("providerDidReset:")
        audioDevice.isEnabled = true
    }
    
    func providerDidBegin(_ provider: CXProvider) {
        print("providerDidBegin")
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("provider:didActivateAudioSession:")
        audioDevice.isEnabled = true
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("provider:didDeactivateAudioSession:")
    }
    
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        print("provider:timedOutPerformingAction:")
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        print("provider:performStartCallAction:")
        
        //  toggleUIState(isEnabled: false, showCallControl: false)
        // startSpin()
        
        audioDevice.isEnabled = false
        audioDevice.block();
        
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        
        self.performVoiceCall(uuid: action.callUUID, client: "") { (success) in
            if (success) {
                print("true")
                provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
                action.fulfill()
            } else {
                action.fail()
            }
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("provider:performAnswerCallAction:")
        
        assert(action.callUUID == self.callInvite?.uuid)
        
        audioDevice.isEnabled = false
        audioDevice.block();
        
        self.performAnswerVoiceCall(uuid: action.callUUID) { (success) in
            if (success) {
                action.fulfill()
            } else {
                action.fail()
            }
        }
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("provider:performEndCallAction:")
        
        if (self.callInvite != nil) {
            self.callInvite!.reject()
            self.callInvite = nil
        } else if (self.call != nil) {
            self.call?.disconnect()
        }
        
        audioDevice.isEnabled = true
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        print("provider:performSetHeldAction:")
        if (self.call?.state == .connected) {
            self.call?.isOnHold = action.isOnHold
            action.fulfill()
        } else {
            action.fail()
        }
    }
    
    // MARK: Call Kit Actions
    func performStartCallAction(uuid: UUID, handle: String) {
        let callHandle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: uuid, handle: callHandle)
        let transaction = CXTransaction(action: startCallAction)
        
        callKitCallController.request(transaction)  { error in
            if let error = error {
                print("StartCallAction transaction request failed: \(error.localizedDescription)")
                return
            }
            print("StartCallAction transaction request successful")
            let callUpdate = CXCallUpdate()
            callUpdate.remoteHandle = callHandle
            callUpdate.supportsDTMF = true
            callUpdate.supportsHolding = true
            callUpdate.supportsGrouping = false
            callUpdate.supportsUngrouping = false
            callUpdate.hasVideo = false
            self.callKitProvider.reportCall(with: uuid, updated: callUpdate)
        }
    }
    
    func performEndCallAction(uuid: UUID) {
        
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        callKitCallController.request(transaction) { error in
            if let error = error {
                print("EndCallAction transaction request failed: \(error.localizedDescription).")
            } else {
                
                print("EndCallAction transaction request successful")
            }
        }
    }
    
    func performVoiceCall(uuid: UUID, client: String?, completionHandler: @escaping (Bool) -> Swift.Void) {
        
        let accessToken = accessTokenEndpoint
        
        let connectOptions: TVOConnectOptions = TVOConnectOptions(accessToken: accessToken) { (builder) in
            builder.params = [twimlParamTo : "", "from" : ""] // here to param is to and from number
            builder.uuid = uuid
        }
        
        call = TwilioVoice.connect(with: connectOptions, delegate: self)
        self.callKitCompletionCallback = completionHandler
    }
    
    func performAnswerVoiceCall(uuid: UUID, completionHandler: @escaping (Bool) -> Swift.Void) {
        let acceptOptions: TVOAcceptOptions = TVOAcceptOptions(callInvite: self.callInvite!) { (builder) in
            builder.uuid = self.callInvite?.uuid
        }
        call = self.callInvite?.accept(with: acceptOptions, delegate: self)
        self.callInvite = nil
        self.callKitCompletionCallback = completionHandler
    }
}










extension String {
    public func addingPercentEncodingForQueryParameter() -> String? {
        return addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed)
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: generalDelimitersToEncode + subDelimitersToEncode)
        
        return allowed
    }()
}

extension Dictionary {
    
    func stringFromHttpParameters() -> String {
        let parameterArray = self.map { (key, value) -> String in
            let percentEscapedKey = (key as! String).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            let percentEscapedValue = (value as AnyObject).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            return "\(percentEscapedKey)=\(percentEscapedValue)"
        }
        
        return parameterArray.joined(separator: "&")
    }
}

