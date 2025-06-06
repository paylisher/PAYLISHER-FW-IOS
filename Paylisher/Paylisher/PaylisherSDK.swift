//
//  PaylisherSDK.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 10.04.2025.
//

import Foundation

#if os(iOS) || os(tvOS)
    import UIKit
   // import FirebaseCore
//    import FirebaseAnalytics
//    import FirebaseCrashlytics
#elseif os(macOS)
    import AppKit

#endif



///
let retryDelay = 5.0
let maxRetryDelay = 30.0

// renamed to PaylisherSDK due to https://github.com/apple/swift/issues/56573
@objc public class PaylisherSDK: NSObject {
    public var config: PaylisherConfig

    private init(_ config: PaylisherConfig) {
        self.config = config
    }

    private var enabled = false
    private let setupLock = NSLock()
    private let optOutLock = NSLock()
    private let groupsLock = NSLock()
    private let personPropsLock = NSLock()

    private var queue: PaylisherQueue?
    private var replayQueue: PaylisherQueue?
    private var api: PaylisherApi?
    private var storage: PaylisherStorage?
    #if !os(watchOS)
        private var reachability: Reachability?
    #endif
    private var flagCallReported = Set<String>()
    private var featureFlags: PaylisherFeatureFlags?
    private var context: PaylisherContext?
    private static var apiKeys = Set<String>()
    private var capturedAppInstalled = false
    private var appFromBackground = false
    private var isInBackground = false
    #if os(iOS)
        private var replayIntegration: PaylisherReplayIntegration?
    #endif

    // nonisolated(unsafe) is introduced in Swift 5.10
    #if swift(>=5.10)
        @objc public nonisolated(unsafe) static let shared: PaylisherSDK = {
            let instance = PaylisherSDK(PaylisherConfig(apiKey: ""))
            return instance
        }()
    #else
        @objc public static let shared: PaylisherSDK = {
            let instance = PaylisherSDK(PaylisherConfig(apiKey: ""))
            return instance
        }()
    #endif

    deinit {
        #if !os(watchOS)
            self.reachability?.stopNotifier()
        #endif
    }

    @objc public func debug(_ enabled: Bool = true) {
        if !isEnabled() {
            return
        }

        toggleHedgeLog(enabled)
    }

    @objc public func setup_test(_ config: PaylisherConfig) {
        
    }
    
    @objc public func setup(_ config: PaylisherConfig) {
        setupLock.withLock {
            toggleHedgeLog(config.debug)
            if enabled {
                hedgeLog("Setup called despite already being setup!")
                return
            }

            if PaylisherSDK.apiKeys.contains(config.apiKey) {
                hedgeLog("API Key: \(config.apiKey) already has a Paylisher instance.")
            } else {
                PaylisherSDK.apiKeys.insert(config.apiKey)
            }

            enabled = true
            self.config = config
            let theStorage = PaylisherStorage(config)
            storage = theStorage
            let theApi = PaylisherApi(config)
            api = theApi
            featureFlags = PaylisherFeatureFlags(config, theStorage, theApi)
            config.storageManager = config.storageManager ?? PaylisherStorageManager(config)
            #if os(iOS)
                replayIntegration = PaylisherReplayIntegration(config)
            #endif
            #if !os(watchOS)
                do {
                    reachability = try Reachability()
                } catch {
                    // ignored
                }
                context = PaylisherContext(reachability)
            #else
                context = PaylisherContext()
            #endif

            optOutLock.withLock {
                let optOut = theStorage.getBool(forKey: .optOut)
                config.optOut = optOut ?? config.optOut
            }

            #if !os(watchOS)
                queue = PaylisherQueue(config, theStorage, theApi, .batch, reachability)
                replayQueue = PaylisherQueue(config, theStorage, theApi, .snapshot, reachability)
            #else
                queue = PaylisherQueue(config, theStorage, theApi, .batch)
                replayQueue = PaylisherQueue(config, theStorage, theApi, .snapshot)
            #endif

            queue?.start(disableReachabilityForTesting: config.disableReachabilityForTesting,
                         disableQueueTimerForTesting: config.disableQueueTimerForTesting)

            replayQueue?.start(disableReachabilityForTesting: config.disableReachabilityForTesting,
                               disableQueueTimerForTesting: config.disableQueueTimerForTesting)

            registerNotifications()
            captureScreenViews()

            PaylisherSessionManager.shared.startSession()

            #if os(iOS)
                if config.sessionReplay {
                    replayIntegration?.start()
                }
            #endif

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: PaylisherSDK.didStartNotification, object: nil)
            }

            if config.preloadFeatureFlags {
                reloadFeatureFlags()
            }
            
            // Configure Firebase
            // FirebaseApp.configure();
            // Set the global uncaught exception handler
            ErrorHandlerRegistrar.setupGlobalErrorHandler()
        }
    }
 
    
    @objc public func getDistinctId() -> String {
        if !isEnabled() {
            return ""
        }

        return config.storageManager?.getDistinctId() ?? ""
    }

    @objc public func getAnonymousId() -> String {
        if !isEnabled() {
            return ""
        }

        return config.storageManager?.getAnonymousId() ?? ""
    }

    @objc public func getSessionId() -> String? {
        if !isEnabled() {
            return nil
        }

        return PaylisherSessionManager.shared.getSessionId()
    }

    @objc public func startSession() {
        if !isEnabled() {
            return
        }

        PaylisherSessionManager.shared.startSession {
            self.resetViews()
        }
    }

    @objc public func endSession() {
        if !isEnabled() {
            return
        }

        PaylisherSessionManager.shared.endSession {
            self.resetViews()
        }
    }

    // EVENT CAPTURE

    private func dynamicContext() -> [String: Any] {
        var properties = getRegisteredProperties()

        var groups: [String: String]?
        groupsLock.withLock {
            groups = getGroups()
        }
        if groups != nil, !groups!.isEmpty {
            properties["$groups"] = groups!
        }

        guard let flags = featureFlags?.getFeatureFlags() as? [String: Any] else {
            return properties
        }

        var keys: [String] = []
        for (key, value) in flags {
            properties["$feature/\(key)"] = value

            var active = true
            let boolValue = value as? Bool
            if boolValue != nil {
                active = boolValue!
            } else {
                active = true
            }

            if active {
                keys.append(key)
            }
        }

        if !keys.isEmpty {
            properties["$active_feature_flags"] = keys
        }

        return properties
    }

    private func hasPersonProcessing() -> Bool {
        !(
            config.personProfiles == .never ||
                (
                    config.personProfiles == .identifiedOnly &&
                        config.storageManager?.isIdentified() == false &&
                        config.storageManager?.isPersonProcessing() == false
                )
        )
    }

    @discardableResult
    private func requirePersonProcessing() -> Bool {
        if config.personProfiles == .never {
            hedgeLog("personProfiles is set to `never`. This call will be ignored.")
            return false
        }
        config.storageManager?.setPersonProcessing(true)
        return true
    }

    private func buildProperties(distinctId: String,
                                 properties: [String: Any]?,
                                 userProperties: [String: Any]? = nil,
                                 userPropertiesSetOnce: [String: Any]? = nil,
                                 groups: [String: String]? = nil,
                                 appendSharedProps: Bool = true) -> [String: Any]
    {
        var props: [String: Any] = [:]

        if appendSharedProps {
            let staticCtx = context?.staticContext()
            let dynamicCtx = context?.dynamicContext()
            let localDynamicCtx = dynamicContext()

            if staticCtx != nil {
                props = props.merging(staticCtx ?? [:]) { current, _ in current }
            }
            if dynamicCtx != nil {
                props = props.merging(dynamicCtx ?? [:]) { current, _ in current }
            }
            props = props.merging(localDynamicCtx) { current, _ in current }
            if userProperties != nil {
                props["$set"] = (userProperties ?? [:])
            }
            if userPropertiesSetOnce != nil {
                props["$set_once"] = (userPropertiesSetOnce ?? [:])
            }
            if groups != nil {
                // $groups are also set via the dynamicContext
                let currentGroups = props["$groups"] as? [String: String] ?? [:]
                let mergedGroups = currentGroups.merging(groups ?? [:]) { current, _ in current }
                props["$groups"] = mergedGroups
            }

            if let isIdentified = config.storageManager?.isIdentified() {
                props["$is_identified"] = isIdentified
            }

            props["$process_person_profile"] = hasPersonProcessing()
        }

        let sdkInfo = context?.sdkInfo()
        if sdkInfo != nil {
            props = props.merging(sdkInfo ?? [:]) { current, _ in current }
        }

        if let sessionId = PaylisherSessionManager.shared.getSessionId() {
            props["$session_id"] = sessionId
            // only Session replay requires $window_id, so we set as the same as $session_id.
            // the backend might fallback to $session_id if $window_id is not present next.
            #if os(iOS)
                if !appendSharedProps, config.sessionReplay {
                    props["$window_id"] = sessionId
                }
            #endif
        }

        // only Session Replay needs distinct_id also in the props
        // remove after https://github.com/Paylisher/paylisher/pull/18954 gets merged
        let propDistinctId = props["distinct_id"] as? String
        if !appendSharedProps, propDistinctId == nil || propDistinctId?.isEmpty == true {
            props["distinct_id"] = distinctId
        }

        props = props.merging(properties ?? [:]) { current, _ in current }

        return props
    }

    @objc public func flush() {
        if !isEnabled() {
            return
        }

        queue?.flush()
        replayQueue?.flush()
    }

    @objc public func reset() {
        if !isEnabled() {
            return
        }

        // storage also removes all feature flags
        storage?.reset()
        config.storageManager?.reset()
        flagCallReported.removeAll()
        PaylisherSessionManager.shared.endSession {
            self.resetViews()
        }
        PaylisherSessionManager.shared.startSession()

        // reload flags as anon user
        reloadFeatureFlags()
    }

    private func resetViews() {
        #if os(iOS)
            if config.sessionReplay, featureFlags?.isSessionReplayFlagActive() ?? false {
                replayIntegration?.resetViews()
            }
        #endif
    }

    private func getGroups() -> [String: String] {
        guard let groups = storage?.getDictionary(forKey: .groups) as? [String: String] else {
            return [:]
        }
        return groups
    }

    private func getRegisteredProperties() -> [String: Any] {
        guard let props = storage?.getDictionary(forKey: .registerProperties) as? [String: Any] else {
            return [:]
        }
        return props
    }

    // register is a reserved word in ObjC
    @objc(registerProperties:)
    public func register(_ properties: [String: Any]) {
        if !isEnabled() {
            return
        }

        let sanitizedProps = sanitizeDicionary(properties)
        if sanitizedProps == nil {
            return
        }

        personPropsLock.withLock {
            let props = getRegisteredProperties()
            let mergedProps = props.merging(sanitizedProps!) { _, new in new }
            storage?.setDictionary(forKey: .registerProperties, contents: mergedProps)
        }
    }

    @objc(unregisterProperties:)
    public func unregister(_ key: String) {
        if !isEnabled() {
            return
        }

        personPropsLock.withLock {
            var props = getRegisteredProperties()
            props.removeValue(forKey: key)
            storage?.setDictionary(forKey: .registerProperties, contents: props)
        }
    }

    @objc public func identify(_ distinctId: String) {
        identify(distinctId, userProperties: nil, userPropertiesSetOnce: nil)
    }

    @objc(identifyWithDistinctId:userProperties:)
    public func identify(_ distinctId: String,
                         userProperties: [String: Any]? = nil)
    {
        identify(distinctId, userProperties: userProperties, userPropertiesSetOnce: nil)
    }

    @objc(identifyWithDistinctId:userProperties:userPropertiesSetOnce:)
    public func identify(_ distinctId: String,
                         userProperties: [String: Any]? = nil,
                         userPropertiesSetOnce: [String: Any]? = nil)
    {
        if !isEnabled() {
            return
        }

        if distinctId.isEmpty {
            hedgeLog("identify call not allowed, distinctId is invalid: \(distinctId)")
            return
        }

        if isOptOutState() {
            return
        }

        if !requirePersonProcessing() {
            return
        }

        guard let queue, let storageManager = config.storageManager else {
            return
        }
        let oldDistinctId = getDistinctId()

        let isIdentified = storageManager.isIdentified()

        if distinctId != oldDistinctId, !isIdentified {
            // We keep the AnonymousId to be used by decide calls and identify to link the previousId
            storageManager.setAnonymousId(oldDistinctId)
            storageManager.setDistinctId(distinctId)

            storageManager.setIdentified(true)

            let properties = buildProperties(distinctId: distinctId, properties: [
                "distinct_id": distinctId,
                "$anon_distinct_id": oldDistinctId,
            ], userProperties: sanitizeDicionary(userProperties), userPropertiesSetOnce: sanitizeDicionary(userPropertiesSetOnce))
            let sanitizedProperties = sanitizeProperties(properties)

            queue.add(PaylisherEvent(
                event: "$identify",
                distinctId: distinctId,
                properties: sanitizedProperties
            ))

            reloadFeatureFlags()
        } else {
            hedgeLog("already identified with id: \(oldDistinctId)")
        }
    }

    @objc public func capture(_ event: String) {
        capture(event, distinctId: nil, properties: nil, userProperties: nil, userPropertiesSetOnce: nil, groups: nil)
    }

    @objc(captureWithEvent:properties:)
    public func capture(_ event: String,
                        properties: [String: Any]? = nil)
    {
        capture(event, distinctId: nil, properties: properties, userProperties: nil, userPropertiesSetOnce: nil, groups: nil)
    }

    @objc(captureWithEvent:properties:userProperties:)
    public func capture(_ event: String,
                        properties: [String: Any]? = nil,
                        userProperties: [String: Any]? = nil)
    {
        capture(event, distinctId: nil, properties: properties, userProperties: userProperties, userPropertiesSetOnce: nil, groups: nil)
    }

    @objc(captureWithEvent:properties:userProperties:userPropertiesSetOnce:)
    public func capture(_ event: String,
                        properties: [String: Any]? = nil,
                        userProperties: [String: Any]? = nil,
                        userPropertiesSetOnce: [String: Any]? = nil)
    {
        capture(event, distinctId: nil, properties: properties, userProperties: userProperties, userPropertiesSetOnce: userPropertiesSetOnce, groups: nil)
    }

    private func isOptOutState() -> Bool {
        if config.optOut {
            hedgeLog("Paylisher is in OptOut state.")
            return true
        }
        return false
    }

    @objc(captureWithEvent:properties:userProperties:userPropertiesSetOnce:groups:)
    public func capture(_ event: String,
                        properties: [String: Any]? = nil,
                        userProperties: [String: Any]? = nil,
                        userPropertiesSetOnce: [String: Any]? = nil,
                        groups: [String: String]? = nil)
    {
        capture(event, distinctId: nil, properties: properties, userProperties: userProperties, userPropertiesSetOnce: userPropertiesSetOnce, groups: groups)
    }

    @objc(captureWithEvent:distinctId:properties:userProperties:userPropertiesSetOnce:groups:)
    public func capture(_ event: String,
                        distinctId: String? = nil,
                        properties: [String: Any]? = nil,
                        userProperties: [String: Any]? = nil,
                        userPropertiesSetOnce: [String: Any]? = nil,
                        groups: [String: String]? = nil)
    {
        if !isEnabled() {
            return
        }

        if isOptOutState() {
            return
        }

        guard let queue else {
            return
        }

        var snapshotEvent = false
        if event == "$snapshot" {
            snapshotEvent = true
        }

        // If events fire in the background after the threshold, they should no longer have a sessionId
        if isInBackground {
            PaylisherSessionManager.shared.resetSessionIfExpired {
                self.resetViews()
            }
        }

        let eventDistinctId = distinctId ?? getDistinctId()

        // if the user isn't identified but passed userProperties, userPropertiesSetOnce or groups,
        // we should still enable person processing since this is intentional
        if userProperties?.isEmpty == false || userPropertiesSetOnce?.isEmpty == false || groups?.isEmpty == false {
            requirePersonProcessing()
        }

        let properties = buildProperties(distinctId: eventDistinctId,
                                         properties: sanitizeDicionary(properties),
                                         userProperties: sanitizeDicionary(userProperties),
                                         userPropertiesSetOnce: sanitizeDicionary(userPropertiesSetOnce),
                                         groups: groups,
                                         appendSharedProps: !snapshotEvent)
        let sanitizedProperties = sanitizeProperties(properties)

        let paylisherEvent = PaylisherEvent(
            event: event,
            distinctId: eventDistinctId,
            properties: sanitizedProperties
        )

        // Session Replay has its own queue
        if snapshotEvent {
            guard let replayQueue else {
                return
            }
            replayQueue.add(paylisherEvent)
            return
        }

        queue.add(paylisherEvent)
    }

    @objc public func screen(_ screenTitle: String) {
        screen(screenTitle, properties: nil)
    }

    @objc(screenWithTitle:properties:)
    public func screen(_ screenTitle: String, properties: [String: Any]? = nil) {
        if !isEnabled() {
            return
        }

        if isOptOutState() {
            return
        }

        guard let queue else {
            return
        }

        let props = [
            "$screen_name": screenTitle,
        ].merging(sanitizeDicionary(properties) ?? [:]) { prop, _ in prop }

        let distinctId = getDistinctId()

        let properties = buildProperties(distinctId: distinctId, properties: props)
        let sanitizedProperties = sanitizeProperties(properties)

        queue.add(PaylisherEvent(
            event: "$screen",
            distinctId: distinctId,
            properties: sanitizedProperties
        ))
    }

    private func sanitizeProperties(_ properties: [String: Any]) -> [String: Any] {
        if let sanitizer = config.propertiesSanitizer {
            return sanitizer.sanitize(properties)
        }
        return properties
    }

    @objc public func alias(_ alias: String) {
        if !isEnabled() {
            return
        }

        if isOptOutState() {
            return
        }

        if !requirePersonProcessing() {
            return
        }

        guard let queue else {
            return
        }

        let props = ["alias": alias]

        let distinctId = getDistinctId()

        let properties = buildProperties(distinctId: distinctId, properties: props)
        let sanitizedProperties = sanitizeProperties(properties)

        queue.add(PaylisherEvent(
            event: "$create_alias",
            distinctId: distinctId,
            properties: sanitizedProperties
        ))
    }

    private func groups(_ newGroups: [String: String]) -> [String: String] {
        guard let storage else {
            return [:]
        }

        var groups: [String: String]?
        var mergedGroups: [String: String]?
        groupsLock.withLock {
            groups = getGroups()
            mergedGroups = groups?.merging(newGroups) { _, new in new }

            storage.setDictionary(forKey: .groups, contents: mergedGroups ?? [:])
        }

        var shouldReloadFlags = false

        for (key, value) in newGroups where groups?[key] != value {
            shouldReloadFlags = true
            break
        }

        if shouldReloadFlags {
            reloadFeatureFlags()
        }

        return mergedGroups ?? [:]
    }

    private func groupIdentify(type: String, key: String, groupProperties: [String: Any]? = nil) {
        if !isEnabled() {
            return
        }

        if isOptOutState() {
            return
        }

        guard let queue else {
            return
        }

        var props: [String: Any] = ["$group_type": type,
                                    "$group_key": key]

        let groupProps = sanitizeDicionary(groupProperties)

        if groupProps != nil {
            props["$group_set"] = groupProps
        }

        // Same as .group but without associating the current user with the group
        let distinctId = getDistinctId()

        let properties = buildProperties(distinctId: distinctId, properties: props)
        let sanitizedProperties = sanitizeProperties(properties)

        queue.add(PaylisherEvent(
            event: "$groupidentify",
            distinctId: distinctId,
            properties: sanitizedProperties
        ))
    }

    @objc(groupWithType:key:)
    public func group(type: String, key: String) {
        group(type: type, key: key, groupProperties: nil)
    }

    @objc(groupWithType:key:groupProperties:)
    public func group(type: String, key: String, groupProperties: [String: Any]? = nil) {
        if !isEnabled() {
            return
        }

        if isOptOutState() {
            return
        }

        if !requirePersonProcessing() {
            return
        }

        _ = groups([type: key])

        groupIdentify(type: type, key: key, groupProperties: sanitizeDicionary(groupProperties))
    }

    // FEATURE FLAGS
    @objc public func reloadFeatureFlags() {
        reloadFeatureFlags {
            // No use case
        }
    }

    @objc(reloadFeatureFlagsWithCallback:)
    public func reloadFeatureFlags(_ callback: @escaping () -> Void) {
        if !isEnabled() {
            return
        }

        guard let featureFlags, let storageManager = config.storageManager else {
            return
        }

        var groups: [String: String]?
        groupsLock.withLock {
            groups = getGroups()
        }
        featureFlags.loadFeatureFlags(
            distinctId: storageManager.getDistinctId(),
            anonymousId: storageManager.getAnonymousId(),
            groups: groups ?? [:],
            callback: callback
        )
    }

    @objc public func getFeatureFlag(_ key: String) -> Any? {
        if !isEnabled() {
            return nil
        }

        guard let featureFlags else {
            return nil
        }

        let value = featureFlags.getFeatureFlag(key)

        if config.sendFeatureFlagEvent {
            reportFeatureFlagCalled(flagKey: key, flagValue: value)
        }

        return value
    }

    @objc public func isFeatureEnabled(_ key: String) -> Bool {
        if !isEnabled() {
            return false
        }

        guard let featureFlags else {
            return false
        }

        let value = featureFlags.isFeatureEnabled(key)

        if config.sendFeatureFlagEvent {
            reportFeatureFlagCalled(flagKey: key, flagValue: value)
        }

        return value
    }

    @objc public func getFeatureFlagPayload(_ key: String) -> Any? {
        if !isEnabled() {
            return nil
        }

        guard let featureFlags else {
            return nil
        }

        return featureFlags.getFeatureFlagPayload(key)
    }

    private func reportFeatureFlagCalled(flagKey: String, flagValue: Any?) {
        if !flagCallReported.contains(flagKey) {
            let properties: [String: Any] = [
                "$feature_flag": flagKey,
                "$feature_flag_response": flagValue ?? "",
            ]

            flagCallReported.insert(flagKey)

            capture("$feature_flag_called", properties: properties)
        }
    }

   /* private func isEnabled() -> Bool {
        if !enabled {
            hedgeLog("Paylisher method was called without `setup` being complete. Call wil be ignored.")
        }
        return enabled
    }*/
    
    public func test(){
        isEnabled()
    }
    
    private func isEnabled() -> Bool {
        //print("isEnabled is working.")
       
            if let validEnabled = enabled as? Bool {
                if !validEnabled {
                    hedgeLog("Paylisher method was called without 'setup' being complete. Call will be ignored.")
                }
                return validEnabled
            } else {
                hedgeLog("Invalid type for enabled: \(type(of: enabled)). Defaulting to false.")
                return false
            }
        }

    @objc public func optIn() {
        if !isEnabled() {
            return
        }

        optOutLock.withLock {
            config.optOut = false
            storage?.setBool(forKey: .optOut, contents: false)
        }
    }

    @objc public func optOut() {
        if !isEnabled() {
            return
        }

        optOutLock.withLock {
            config.optOut = true
            storage?.setBool(forKey: .optOut, contents: true)
        }
    }

    @objc public func isOptOut() -> Bool {
        if !isEnabled() {
            return true
        }

        return config.optOut
    }

    @objc public func close() {
        if !isEnabled() {
            return
        }

        setupLock.withLock {
            enabled = false
            PaylisherSDK.apiKeys.remove(config.apiKey)

            if config.captureScreenViews {
                #if os(iOS) || os(tvOS)
                    UIViewController.unswizzleScreenView()
                #endif
            }

            queue?.stop()
            replayQueue?.stop()
            #if os(iOS)
                replayIntegration?.stop()
                replayIntegration = nil
            #endif
            queue = nil
            replayQueue = nil
            config.storageManager?.reset()
            config.storageManager = nil
            config = PaylisherConfig(apiKey: "")
            api = nil
            featureFlags = nil
            storage = nil
            #if !os(watchOS)
                self.reachability?.stopNotifier()
                reachability = nil
            #endif
            flagCallReported.removeAll()
            context = nil
            PaylisherSessionManager.shared.endSession {
                self.resetViews()
            }
            unregisterNotifications()
            capturedAppInstalled = false
            appFromBackground = false
            isInBackground = false
            toggleHedgeLog(false)
        }
    }

    @objc public static func with(_ config: PaylisherConfig) -> PaylisherSDK {
        let paylisher = PaylisherSDK(config)
        paylisher.setup(config)
        return paylisher
    }

    private func unregisterNotifications() {
        let defaultCenter = NotificationCenter.default

        #if os(iOS) || os(tvOS)
            defaultCenter.removeObserver(self, name: UIApplication.didFinishLaunchingNotification, object: nil)
            defaultCenter.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
            defaultCenter.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        #elseif os(macOS)
            defaultCenter.removeObserver(self, name: NSApplication.didFinishLaunchingNotification, object: nil)
            defaultCenter.removeObserver(self, name: NSApplication.didResignActiveNotification, object: nil)
            defaultCenter.removeObserver(self, name: NSApplication.didBecomeActiveNotification, object: nil)
        #endif
    }

    private func registerNotifications() {
        let defaultCenter = NotificationCenter.default

        #if os(iOS) || os(tvOS)
            defaultCenter.addObserver(self,
                                      selector: #selector(handleAppDidFinishLaunching),
                                      name: UIApplication.didFinishLaunchingNotification,
                                      object: nil)
            defaultCenter.addObserver(self,
                                      selector: #selector(handleAppDidEnterBackground),
                                      name: UIApplication.didEnterBackgroundNotification,
                                      object: nil)
            defaultCenter.addObserver(self,
                                      selector: #selector(handleAppDidBecomeActive),
                                      name: UIApplication.didBecomeActiveNotification,
                                      object: nil)
        #elseif os(macOS)
            defaultCenter.addObserver(self,
                                      selector: #selector(handleAppDidFinishLaunching),
                                      name: NSApplication.didFinishLaunchingNotification,
                                      object: nil)
            // macOS does not have didEnterBackgroundNotification, so we use didResignActiveNotification
            defaultCenter.addObserver(self,
                                      selector: #selector(handleAppDidEnterBackground),
                                      name: NSApplication.didResignActiveNotification,
                                      object: nil)
            defaultCenter.addObserver(self,
                                      selector: #selector(handleAppDidBecomeActive),
                                      name: NSApplication.didBecomeActiveNotification,
                                      object: nil)
        #endif
    }

    private func captureScreenViews() {
        if config.captureScreenViews {
            #if os(iOS) || os(tvOS)
                UIViewController.swizzleScreenView()
            #endif
        }
    }

    @objc func handleAppDidFinishLaunching() {
        captureAppInstallLifecycle()
    }

    private func captureAppInstallLifecycle() {
        if !config.captureApplicationLifecycleEvents {
            return
        }

        let bundle = Bundle.main

        let versionName = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
        let versionCode = bundle.infoDictionary?["CFBundleVersion"] as? String

        // capture app installed/updated
        if !capturedAppInstalled {
            let userDefaults = UserDefaults.standard

            let previousVersion = userDefaults.string(forKey: "PHGVersionKey")
            let previousVersionCode = userDefaults.string(forKey: "PHGBuildKeyV2")

            var props: [String: Any] = [:]
            var event: String
            if previousVersionCode == nil {
                // installed
                event = "Application Installed"
            } else {
                event = "Application Updated"

                // Do not send version updates if its the same
                if previousVersionCode == versionCode {
                    return
                }

                if previousVersion != nil {
                    props["previous_version"] = previousVersion
                }
                props["previous_build"] = previousVersionCode
            }

            var syncDefaults = false
            if versionName != nil {
                props["version"] = versionName
                userDefaults.setValue(versionName, forKey: "PHGVersionKey")
                syncDefaults = true
            }

            if versionCode != nil {
                props["build"] = versionCode
                userDefaults.setValue(versionCode, forKey: "PHGBuildKeyV2")
                syncDefaults = true
            }

            if syncDefaults {
                userDefaults.synchronize()
            }

            capture(event, properties: props)

            capturedAppInstalled = true
        }
    }

    @objc func handleAppDidBecomeActive() {
        PaylisherSessionManager.shared.rotateSessionIdIfRequired {
            self.resetViews()
        }

        isInBackground = false
        captureAppOpened()
    }

    private func captureAppOpened() {
        if !config.captureApplicationLifecycleEvents {
            return
        }

        var props: [String: Any] = [:]
        props["from_background"] = appFromBackground

        if !appFromBackground {
            let bundle = Bundle.main

            let versionName = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
            let versionCode = bundle.infoDictionary?["CFBundleVersion"] as? String

            if versionName != nil {
                props["version"] = versionName
            }
            if versionCode != nil {
                props["build"] = versionCode
            }

            appFromBackground = true
        }

        capture("Application Opened", properties: props)
    }

    @objc func handleAppDidEnterBackground() {
        captureAppBackgrounded()

        PaylisherSessionManager.shared.updateSessionLastTime()

        isInBackground = true
    }

    private func captureAppBackgrounded() {
        if !config.captureApplicationLifecycleEvents {
            return
        }
        capture("Application Backgrounded")
    }

    func isSessionActive() -> Bool {
        if !isEnabled() {
            return false
        }

        return PaylisherSessionManager.shared.isSessionActive()
    }

    #if os(iOS)
        @objc public func isSessionReplayActive() -> Bool {
            if !isEnabled() {
                return false
            }

            return config.sessionReplay && isSessionActive() && (featureFlags?.isSessionReplayFlagActive() ?? false)
        }
    #endif
}

// swiftlint:enable file_length cyclomatic_complexity

