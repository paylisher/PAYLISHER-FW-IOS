//
//  ContentView.swift
//  PaylisherExample
//
//  Created by Ben White on 10.01.23.
//

import AuthenticationServices
import Paylisher
import SwiftUI
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

    var body: some View {
        NavigationStack {
            List {
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
            lastDeepLinkInfo = """
            🔗 Son Deep Link:
            URL: \(url.absoluteString)
            Destination: \(deepLink.destination)
            Scheme: \(deepLink.scheme)
            Campaign: \(deepLink.campaignId ?? "-")
            Params: \(deepLink.parameters)
            """
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
