//
//  ContentView.swift
//  PaylisherExample
//
//  Created by Ben White on 10.01.23.
//

import AuthenticationServices
import Paylisher
import SwiftUI
import UIKit
import Combine

class SignInViewModel: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {

    private var authSession: ASWebAuthenticationSession?

    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first!
    }

    func triggerAuthentication() {
        guard let authURL = URL(string: "https://example.com/auth") else { return }
        let scheme = "exampleauth"

        authSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { [weak self] callbackURL, error in defer { self?.authSession = nil }
            if let callbackURL = callbackURL {
                print("URL", callbackURL.absoluteString)
            }
            if let error = error {
                print("Error", error.localizedDescription)
            }

            self?.authSession = nil
        }

        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = true

        authSession?.start()
    }
}

class FeatureFlagsModel: ObservableObject {
    @Published var boolValue: Bool?
    @Published var stringValue: String?
    @Published var payloadValue: [String: String]?
    @Published var isReloading: Bool = false

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(reloaded), name: PaylisherSDK.didReceiveFeatureFlags, object: nil)
    }

    @objc func reloaded() {
        boolValue = PaylisherSDK.shared.isFeatureEnabled("4535-funnel-bar-viz")
        stringValue = PaylisherSDK.shared.getFeatureFlag("multivariant") as? String
        payloadValue = PaylisherSDK.shared.getFeatureFlagPayload("multivariant") as? [String: String]
    }

    func reload() {
        isReloading = true

        PaylisherSDK.shared.reloadFeatureFlags {
            self.isReloading = false
        }
    }
}

struct YeniSayfaView: View {
    var body: some View {
        VStack {
            Text("Bu yeni bir sayfa!")
                .font(.largeTitle)
                .padding()

            NavigationLink(destination: ContentView()) {
                Text("Ana Sayfaya Dön")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .navigationTitle("Yeni Sayfa")
    }
}

struct ContentView: View {
    @State var counter: Int = 0
    @State private var name: String = "Max"
    @State private var showingSheet = false
    @State private var showingRedactedSheet = false
    @StateObject var api = Api()
    @StateObject var signInViewModel = SignInViewModel()
    @StateObject var featureFlagsModel = FeatureFlagsModel()
    
    // MARK: - Deep Link Navigation
    @State private var deepLinkDestination: String?
    @State private var cancellables = Set<AnyCancellable>()
    
    // Deep link bilgilerini göstermek için
    @State private var lastDeepLinkInfo: String = "Henüz deep link alınmadı"

    // Journey tracking bilgileri
    @State private var currentJourneyId: String = "Yok"
    @State private var journeySource: String = "-"
    @State private var journeyAgeHours: String = "-"

    func incCounter() {
        counter += 1
    }

    func triggerIdentify() {
        PaylisherSDK.shared.identify(name, userProperties: [
            "name": name,
        ])
        
        PaylisherSDK.shared.screen("İkinci Ekran")
    }

    func triggerAuthentication() {
        PaylisherSDK.shared.screen("Test Ekranı")
        signInViewModel.triggerAuthentication()
    }

    func triggerFlagReload() {
        featureFlagsModel.reload()
    }

    func testIdentify() {
        PaylisherSDK.shared.identify("test_user_53",
                                    userProperties: [ "Name": "Test User", "Surname:": "Kaya", "Gender": "Male"],
                                    userPropertiesSetOnce: ["date_of_first_log_in": "2025-23-01"])
        print("✅ Identify called: test_user_53")
    }

    func testReset() {
        PaylisherSDK.shared.reset()
        print("🔄 Reset called - distinct ID cleared, session reset, journey cleared")
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Journey Tracking Section (NEW)
                Section("🎯 Journey Tracking") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Journey ID:")
                                .font(.caption)
                                .bold()
                            Spacer()
                            Text(currentJourneyId)
                                .font(.caption)
                                .foregroundColor(currentJourneyId == "Yok" ? .secondary : .green)
                        }

                        HStack {
                            Text("Source:")
                                .font(.caption)
                                .bold()
                            Spacer()
                            Text(journeySource)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Age (hours):")
                                .font(.caption)
                                .bold()
                            Spacer()
                            Text(journeyAgeHours)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        Text("Test Campaign Links:")
                            .font(.caption)
                            .bold()

                        Button("🎁 Black Friday (jid=bf2025)") {
                            testDeepLink("myapp://yeniSayfa?jid=bf2025&campaign_id=black-friday&utm_source=instagram")
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)

                        Button("🎄 Winter Sale (jid=winter2025)") {
                            testDeepLink("myapp://crashTest?jid=winter2025&campaign_id=winter-sale&utm_source=email")
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)

                        Button("🌱 Organic Link (no jid)") {
                            testDeepLink("myapp://yeniSayfa")
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)

                        Divider()

                        Button("🔄 Refresh Journey Info") {
                            updateJourneyInfo()
                        }
                        .buttonStyle(.bordered)

                        Button("🗑️ Clear Journey (Simulate Logout)") {
                            PaylisherSDK.shared.reset()
                            updateJourneyInfo()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }

                // MARK: - Deep Link Status Section
                Section("Deep Link Durumu") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lastDeepLinkInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if PaylisherSDK.shared.hasPendingDeepLink {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.orange)
                                Text("Bekleyen: \(PaylisherSDK.shared.pendingDeepLinkDestination ?? "?")")
                                    .foregroundColor(.orange)
                            }

                            HStack {
                                Button("Tamamla") {
                                    PaylisherSDK.shared.completePendingDeepLink()
                                }
                                .buttonStyle(.bordered)
                                .tint(.green)

                                Button("İptal") {
                                    PaylisherSDK.shared.cancelPendingDeepLink()
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                        }
                    }

                    // Test Deep Link Butonları
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Test Deep Links:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Button("yeniSayfa") {
                                testDeepLink("myapp://yeniSayfa")
                            }
                            .buttonStyle(.bordered)

                            Button("crashTest") {
                                testDeepLink("myapp://crashTest")
                            }
                            .buttonStyle(.bordered)

                            Button("wallet (auth)") {
                                testDeepLink("myapp://wallet?auth=required")
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                        }
                    }
                }
                
                Section("General") {
                    NavigationLink {
                        ContentView()
                    } label: {
                        Text("Infinite navigation")
                    }
                    .paylisherMask()

                    Button("Test Error") {
                        testErrorLogging()
                    }
                    
                    Button("Show Sheet") {
                        showingSheet.toggle()
                        PaylisherSDK.shared.screen("Splash")
                    }
                    .sheet(isPresented: $showingSheet) {
                        ContentView()
                            .paylisherScreenView("ContentViewSheet")
                    }
                    Button("Show redacted view") {
                        showingRedactedSheet.toggle()
                        PaylisherSDK.shared.screen("İlk Ekran")
                    }
                    .sheet(isPresented: $showingRedactedSheet) {
                        RepresentedExampleUIView()
                    }

                    Text("Sensitive text!!").paylisherMask()
                    Button(action: incCounter) {
                        Text(String(counter))
                    }
                    .paylisherMask()

                    TextField("Enter your name", text: $name)
                        .paylisherMask()
                    Text("Hello, \(name)!")
                    Button(action: triggerAuthentication) {
                        Text("Trigger fake authentication!")
                    }
                    Button(action: triggerIdentify) {
                        Text("Trigger identify!")
                    }.paylisherViewSeen("Trigger identify")
                }

                Section("Identify & Reset Test") {
                    Button("🔐 Test Identify (test_user_53)") {
                        testIdentify()
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)

                    Button("🔄 Test Reset (Logout)") {
                        testReset()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                Section("Navigasyon") {
                    NavigationLink(destination: CrashTestView(), tag: "CrashTestView", selection: $deepLinkDestination) {
                        Text("Crash Test Sayfası")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    
                    NavigationLink(destination: YeniSayfaView(), tag: "YeniSayfaView", selection: $deepLinkDestination) {
                        Text("Yeni Sayfaya Git")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }

                Section("Feature flags") {
                    HStack {
                        Text("Boolean:")
                        Spacer()
                        Text("\(featureFlagsModel.boolValue?.description ?? "unknown")")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("String:")
                        Spacer()
                        Text("\(featureFlagsModel.stringValue ?? "unknown")")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Payload:")
                        Spacer()
                        Text("\(featureFlagsModel.payloadValue?.description ?? "unknown")")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Button(action: triggerFlagReload) {
                            Text("Reload flags")
                        }
                        Spacer()
                        if featureFlagsModel.isReloading {
                            ProgressView()
                        }
                    }
                }

                // MARK: - InApp Message Demo
                Section("InApp Message Demo") {
                    HStack(spacing: 8) {
                        Button("Modal") {
                            PaylisherCustomInAppNotificationManager.shared.customInAppFunction(
                                userInfo: inAppMockModal(), windowScene: activeWindowScene())
                        }
                        .buttonStyle(.bordered).tint(.blue)

                        Button("Banner") {
                            PaylisherCustomInAppNotificationManager.shared.customInAppFunction(
                                userInfo: inAppMockBanner(), windowScene: activeWindowScene())
                        }
                        .buttonStyle(.bordered).tint(.orange)

                        Button("Native") {
                            PaylisherNativeInAppNotificationManager.shared.nativeInAppNotification(
                                userInfo: inAppMockNative(), windowScene: activeWindowScene())
                        }
                        .buttonStyle(.bordered).tint(.green)
                    }
                    HStack(spacing: 8) {
                        Button("Fullscreen") {
                            PaylisherCustomInAppNotificationManager.shared.customInAppFunction(
                                userInfo: inAppMockFullscreen(), windowScene: activeWindowScene())
                        }
                        .buttonStyle(.bordered).tint(.purple)

                        Button("Carousel") {
                            PaylisherCustomInAppNotificationManager.shared.customInAppFunction(
                                userInfo: inAppMockCarousel(), windowScene: activeWindowScene())
                        }
                        .buttonStyle(.bordered).tint(.red)
                    }
                }

                Section("Paylisher beers") {
                    if !api.beers.isEmpty {
                        ForEach(api.beers) { beer in
                            HStack(alignment: .center) {
                                Text(beer.name)
                                Spacer()
                                Text("First brewed")
                                Text(beer.first_brewed).foregroundColor(Color.gray)
                            }
                        }
                    } else {
                        HStack {
                            Text("Loading beers...")
                            Spacer()
                            ProgressView()
                        }
                    }
                }
            }
            .navigationTitle("Paylisher")
        }
        .onAppear {
            api.listBeers(completion: { beers in
                api.beers = beers
            })

            // Deep link navigation publisher'ı dinle
            setupDeepLinkListener()

            // Journey bilgilerini yükle
            updateJourneyInfo()
        }
        // ============================================
        // MARK: - Deep Link Handling (SDK ile)
        // ============================================
        .onOpenURL { url in
            print("📱 ContentView: onOpenURL - \(url)")
            
            // SDK'ya deep link'i işlet
            // SDK otomatik olarak:
            // 1. URL'i parse eder
            // 2. "Deep Link Opened" eventi gönderir
            // 3. Auth kontrolü yapar
            // 4. Handler'ı çağırır (AppDelegate)
            PaylisherSDK.shared.handleDeepLink(url)
            
            // UI'da göster
            updateDeepLinkInfo(url)
        }
    }
    
    // MARK: - Deep Link Helpers
    
    /// AppDelegate'den gelen navigation eventlerini dinle
    private func setupDeepLinkListener() {
        AppDelegate.deepLinkNavigationPublisher
            .receive(on: DispatchQueue.main)
            .sink { destination in
                print("📱 ContentView: Navigation to \(destination)")
                self.deepLinkDestination = destination
            }
            .store(in: &cancellables)
    }
    
    /// Deep link bilgisini UI'da güncelle
    private func updateDeepLinkInfo(_ url: URL) {
        if let deepLink = PaylisherSDK.shared.lastDeepLink {
            var info = """
            🔗 Son Deep Link:
            URL: \(url.absoluteString)
            Destination: \(deepLink.destination)
            Scheme: \(deepLink.scheme)
            Campaign: \(deepLink.campaignId ?? "-")
            """

            if let jid = deepLink.jid {
                info += "\n🎯 Journey ID: \(jid)"
            } else {
                info += "\n🌱 Organic (no jid)"
            }

            info += "\nParams: \(deepLink.parameters)"
            lastDeepLinkInfo = info
        }

        // Journey bilgilerini de güncelle
        updateJourneyInfo()
    }

    /// Journey tracking bilgilerini güncelle
    private func updateJourneyInfo() {
        // SDK'nın PaylisherJourneyContext'inden bilgileri al
        // Not: PaylisherJourneyContext internal olduğu için UserDefaults'tan okuyoruz
        if let jid = UserDefaults.standard.string(forKey: "paylisher_journey_id") {
            currentJourneyId = jid

            if let source = UserDefaults.standard.string(forKey: "paylisher_journey_source") {
                journeySource = source
            }

            let timestamp = UserDefaults.standard.double(forKey: "paylisher_journey_id_timestamp")
            if timestamp > 0 {
                let ageSeconds = Date().timeIntervalSince1970 - timestamp
                let ageHours = Int(ageSeconds / 3600)
                journeyAgeHours = "\(ageHours)"
            }
        } else {
            currentJourneyId = "Yok"
            journeySource = "-"
            journeyAgeHours = "-"
        }
    }
    
    /// Test için deep link simüle et
    private func testDeepLink(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        print("🧪 Test Deep Link: \(urlString)")
        PaylisherSDK.shared.handleDeepLink(url)
        updateDeepLinkInfo(url)
    }
    
    // MARK: - Error Logging (Existing)
    
    enum CustomError: Error {
        case invalidOperation
        case valueOutOfRange
    }

    func performOperation(shouldThrow: Bool) throws {
        if shouldThrow {
            throw CustomError.invalidOperation
        }
        print("Operation performed successfully.")
    }
    
    func testErrorLogging() {
        do {
            try performOperation(shouldThrow: true)
        } catch {
            let properties: [String: Any] = [
                "message": error.localizedDescription,
                "cause": (error as NSError).userInfo["NSUnderlyingError"] ?? "None",
                "stackTrace": Thread.callStackSymbols.joined(separator: "\n")
            ]
            print("testErrorLogging catch")
            PaylisherSDK.shared.capture("Error", properties: properties)
        }
    }

    // MARK: - InApp Message Demo Helpers

    private func activeWindowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
    }

    private func inAppMockModal() -> [AnyHashable: Any] {
        let layouts = """
        [{"style":{"radius":"20","bgColor":"#FFFFFF","verticalPosition":"center"},"close":{"active":"true","type":"icon","position":"outside-right","icon":{"color":"#333333","style":"outlined"}},"extra":{"overlay":{"action":"close","color":"#000000"},"transition":"bottom-to-top"},"blocks":{"align":"top","order":[{"type":"image","order":"1","url":"https://picsum.photos/seed/modal/400/200","radius":"0","margin":"0"},{"type":"spacer","order":"2","verticalSpacing":"12"},{"type":"text","order":"3","content":{"en":"🎉 Special Offer!"},"color":"#1A1A1A","fontSize":"20","fontWeight":"bold","textAlignment":"center","horizontalMargin":"16"},{"type":"text","order":"4","content":{"en":"Get 30% off your next purchase. Limited time — don't miss out!"},"color":"#555555","fontSize":"14","textAlignment":"center","horizontalMargin":"16"},{"type":"spacer","order":"5","verticalSpacing":"12"},{"type":"buttonGroup","order":"6","buttonGroupType":"double-horizontal","buttons":[{"label":{"en":"Get Offer"},"action":"https://paylisher.com","textColor":"#FFFFFF","backgroundColor":"#007AFF","borderColor":"#007AFF","borderRadius":"10","horizontalSize":"large","verticalSize":"small","margin":"8"},{"label":{"en":"Dismiss"},"action":"dismiss","textColor":"#333333","backgroundColor":"#F0F0F0","borderColor":"#CCCCCC","borderRadius":"10","horizontalSize":"large","verticalSize":"small","margin":"8"}]},{"type":"spacer","order":"7","verticalSpacing":"8"}]}}]
        """
        return ["defaultLang": "en", "layoutType": "modal", "layouts": layouts]
    }

    private func inAppMockBanner() -> [AnyHashable: Any] {
        let layouts = """
        [{"style":{"radius":"12","bgColor":"#1C1C1E","verticalPosition":"top"},"close":{"active":"true","type":"icon","position":"right","icon":{"color":"#FFFFFF","style":"basic"}},"extra":{"banner":{"action":"https://paylisher.com","duration":"4"}},"blocks":{"align":"center","order":[{"type":"image","order":"1","url":"https://picsum.photos/seed/banner/120/120","radius":"8","margin":"8"},{"type":"text","order":"2","content":{"en":"🔔 New message! Tap to view your exclusive offer."},"color":"#FFFFFF","fontSize":"14","fontWeight":"bold","textAlignment":"left","horizontalMargin":"8"}]}}]
        """
        return ["defaultLang": "en", "layoutType": "banner", "layouts": layouts]
    }

    private func inAppMockNative() -> [AnyHashable: Any] {
        let native = """
        {"title":{"en":"Welcome Back! 👋"},"body":{"en":"You have a new reward waiting for you. Check it out now and claim your points before they expire."},"imageUrl":"https://picsum.photos/seed/native/400/200","actionUrl":"https://paylisher.com","actionText":"Claim Now"}
        """
        return [
            "type": "inApp",
            "defaultLang": "en",
            "gcm.message_id": UUID().uuidString,
            "native": native
        ]
    }

    private func inAppMockFullscreen() -> [AnyHashable: Any] {
        let layouts = """
        [{"style":{"radius":"0","bgColor":"#0A0A0A","bgImage":"https://picsum.photos/seed/fullscreen/800/1200","bgImageMask":"true","bgImageColor":"#000000"},"close":{"active":"true","type":"icon","position":"right","icon":{"color":"#FFFFFF","style":"outlined"}},"extra":{"transition":"right-to-left"},"blocks":{"align":"bottom","order":[{"type":"spacer","order":"1","fillAvailableSpacing":"true"},{"type":"text","order":"2","content":{"en":"SUMMER SALE"},"color":"#FFFFFF","fontSize":"32","fontWeight":"bold","textAlignment":"center","horizontalMargin":"24"},{"type":"text","order":"3","content":{"en":"Up to 50% off on selected items. Today only."},"color":"#E0E0E0","fontSize":"16","textAlignment":"center","horizontalMargin":"24"},{"type":"spacer","order":"4","verticalSpacing":"24"},{"type":"buttonGroup","order":"5","buttonGroupType":"single-vertical","buttons":[{"label":{"en":"Shop Now"},"action":"https://paylisher.com","textColor":"#000000","backgroundColor":"#FFFFFF","borderRadius":"30","horizontalSize":"large","verticalSize":"small","margin":"24"}]},{"type":"spacer","order":"6","verticalSpacing":"32"}]}}]
        """
        return ["defaultLang": "en", "layoutType": "fullscreen", "layouts": layouts]
    }

    private func inAppMockCarousel() -> [AnyHashable: Any] {
        let layouts = """
        [{"style":{"navigationalArrows":"true","radius":"16","bgColor":"#FFFFFF","verticalPosition":"center"},"close":{"active":"true","type":"icon","position":"outside-right","icon":{"color":"#333333","style":"basic"}},"extra":{"overlay":{"action":"close","color":"#000000"},"transition":"no-transition"},"blocks":{"align":"top","order":[{"type":"image","order":"1","url":"https://picsum.photos/seed/carousel1/400/200","radius":"0","margin":"0"},{"type":"spacer","order":"2","verticalSpacing":"12"},{"type":"text","order":"3","content":{"en":"Slide 1: New Arrivals 🆕"},"color":"#1A1A1A","fontSize":"18","fontWeight":"bold","textAlignment":"center","horizontalMargin":"16"},{"type":"text","order":"4","content":{"en":"Fresh styles just landed. Be the first to explore."},"color":"#555555","fontSize":"13","textAlignment":"center","horizontalMargin":"16"},{"type":"spacer","order":"5","verticalSpacing":"12"},{"type":"buttonGroup","order":"6","buttonGroupType":"single-vertical","buttons":[{"label":{"en":"Explore"},"action":"https://paylisher.com","textColor":"#FFFFFF","backgroundColor":"#FF6B35","borderRadius":"10","horizontalSize":"large","verticalSize":"small","margin":"16"}]},{"type":"spacer","order":"7","verticalSpacing":"8"}]}},{"style":{"navigationalArrows":"true","radius":"16","bgColor":"#FFFFFF","verticalPosition":"center"},"close":{"active":"true","type":"icon","position":"outside-right","icon":{"color":"#333333","style":"basic"}},"extra":{"overlay":{"action":"close","color":"#000000"},"transition":"no-transition"},"blocks":{"align":"top","order":[{"type":"image","order":"1","url":"https://picsum.photos/seed/carousel2/400/200","radius":"0","margin":"0"},{"type":"spacer","order":"2","verticalSpacing":"12"},{"type":"text","order":"3","content":{"en":"Slide 2: Members Only 🔒"},"color":"#1A1A1A","fontSize":"18","fontWeight":"bold","textAlignment":"center","horizontalMargin":"16"},{"type":"text","order":"4","content":{"en":"Exclusive deals for our loyalty members. Join today."},"color":"#555555","fontSize":"13","textAlignment":"center","horizontalMargin":"16"},{"type":"spacer","order":"5","verticalSpacing":"12"},{"type":"buttonGroup","order":"6","buttonGroupType":"single-vertical","buttons":[{"label":{"en":"Join Now"},"action":"https://paylisher.com","textColor":"#FFFFFF","backgroundColor":"#FF6B35","borderRadius":"10","horizontalSize":"large","verticalSize":"small","margin":"16"}]},{"type":"spacer","order":"7","verticalSpacing":"8"}]}},{"style":{"navigationalArrows":"true","radius":"16","bgColor":"#FFFFFF","verticalPosition":"center"},"close":{"active":"true","type":"icon","position":"outside-right","icon":{"color":"#333333","style":"basic"}},"extra":{"overlay":{"action":"close","color":"#000000"},"transition":"no-transition"},"blocks":{"align":"top","order":[{"type":"image","order":"1","url":"https://picsum.photos/seed/carousel3/400/200","radius":"0","margin":"0"},{"type":"spacer","order":"2","verticalSpacing":"12"},{"type":"text","order":"3","content":{"en":"Slide 3: Last Chance ⏰"},"color":"#1A1A1A","fontSize":"18","fontWeight":"bold","textAlignment":"center","horizontalMargin":"16"},{"type":"text","order":"4","content":{"en":"Sale ends tonight. Don't miss your savings."},"color":"#555555","fontSize":"13","textAlignment":"center","horizontalMargin":"16"},{"type":"spacer","order":"5","verticalSpacing":"12"},{"type":"buttonGroup","order":"6","buttonGroupType":"single-vertical","buttons":[{"label":{"en":"Shop Now"},"action":"https://paylisher.com","textColor":"#FFFFFF","backgroundColor":"#FF6B35","borderRadius":"10","horizontalSize":"large","verticalSize":"small","margin":"16"}]},{"type":"spacer","order":"7","verticalSpacing":"8"}]}}]
        """
        return ["defaultLang": "en", "layoutType": "modal-carousel", "layouts": layouts]
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
