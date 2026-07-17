import Foundation
import SwiftUI
import ServiceManagement

@MainActor
final class AppStore: ObservableObject {
    @Published var quote = StockQuote()
    @Published var officialNews: [NewsItem] = []
    @Published var pressNews: [NewsItem] = []
    @Published var earningsDate: Date?
    @Published var lastRefresh: Date?
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var eurUsdRate: Double

    // Langue ("fr"/"en") : bascule l'interface ET les sources d'actualités
    @Published var lang: String {
        didSet {
            guard lang != oldValue else { return }
            UserDefaults.standard.set(lang, forKey: "lang")
            officialNews = []
            pressNews = []
            Task { await refreshNews() }
        }
    }

    // Devise d'affichage ("USD"/"EUR")
    @Published var currency: String {
        didSet {
            UserDefaults.standard.set(currency, forKey: "currency")
            if currency == "EUR" { Task { await refreshRate() } }
        }
    }

    // Date de sortie GTA VI (modifiable dans les réglages si Rockstar re-décale)
    @Published var releaseDate: Date {
        didSet { UserDefaults.standard.set(releaseDate.timeIntervalSince1970, forKey: "releaseDate") }
    }

    // Lancement automatique à l'ouverture de session
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled {
        didSet {
            guard launchAtLogin != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    // Réglages simples (persistés automatiquement)
    @AppStorage("alertOfficial") var alertOfficial = true
    @AppStorage("alertStock") var alertStock = true
    @AppStorage("alertPress") var alertPress = true
    @AppStorage("stockThreshold") var stockThreshold = 3.0          // en %
    @AppStorage("stockIntervalMin") var stockIntervalMin = 5        // minutes
    @AppStorage("newsIntervalMin") var newsIntervalMin = 30         // minutes

    var tr: L10n { L10n(lang) }

    private var stockTimer: Timer?
    private var newsTimer: Timer?
    private var seenIDs: Set<String>
    private var firstNewsFetchDone: Bool
    private var lastRateFetch: Date = .distantPast
    private var lastStockFetch: Date = .distantPast
    private var lastStockAlertDay: String {
        get { UserDefaults.standard.string(forKey: "lastStockAlertDay") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "lastStockAlertDay") }
    }

    init() {
        let d = UserDefaults.standard
        seenIDs = Set(d.stringArray(forKey: "seenIDs") ?? [])
        firstNewsFetchDone = d.bool(forKey: "firstNewsFetchDone")
        let systemIsFrench = Locale.preferredLanguages.first?.hasPrefix("fr") ?? false
        lang = d.string(forKey: "lang") ?? (systemIsFrench ? "fr" : "en")
        currency = d.string(forKey: "currency") ?? "USD"
        eurUsdRate = d.double(forKey: "eurUsdRate")
        let savedRelease = d.double(forKey: "releaseDate")
        // Date officielle annoncée par Rockstar : 19 novembre 2026
        releaseDate = savedRelease > 0
            ? Date(timeIntervalSince1970: savedRelease)
            : DateComponents(calendar: .init(identifier: .gregorian), year: 2026, month: 11, day: 19).date ?? Date()
    }

    func start() {
        Notifier.requestPermission()
        Task { await refreshAll() }
        scheduleTimers()
    }

    func scheduleTimers() {
        stockTimer?.invalidate()
        newsTimer?.invalidate()
        stockTimer = Timer.scheduledTimer(withTimeInterval: Double(max(1, stockIntervalMin)) * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshStock() }
        }
        newsTimer = Timer.scheduledTimer(withTimeInterval: Double(max(5, newsIntervalMin)) * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshNews() }
        }
        // Tolérance large : macOS regroupe les réveils avec ceux du système (économie batterie)
        stockTimer?.tolerance = 30
        newsTimer?.tolerance = 120
    }

    /// Heures d'ouverture du NASDAQ (9h30–16h00 à New York, avec une petite marge), lun–ven.
    private var marketIsOpen: Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        guard (2...6).contains(weekday) else { return false }
        let minutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        return minutes >= 9 * 60 + 15 && minutes <= 16 * 60 + 15
    }

    func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await refreshStock(force: true)
        await refreshNews()
        lastRefresh = Date()
    }

    // MARK: Devise

    /// Formate un montant coté en dollars dans la devise choisie.
    func money(_ usd: Double) -> String {
        if currency == "EUR", eurUsdRate > 0 {
            return Fmt.decimal(usd / eurUsdRate, tr.localeID) + " €"
        }
        return Fmt.decimal(usd, tr.localeID) + " $"
    }

    func refreshRate() async {
        guard Date().timeIntervalSince(lastRateFetch) > 3600 else { return }
        if let rate = try? await Fetchers.fetchEURUSD() {
            lastRateFetch = Date()
            eurUsdRate = rate
            UserDefaults.standard.set(rate, forKey: "eurUsdRate")
        }
    }

    // MARK: Bourse

    func refreshStock(force: Bool = false) async {
        // Marché fermé (nuit, week-end) : une requête par heure suffit
        if !force, !marketIsOpen, quote.price > 0,
           Date().timeIntervalSince(lastStockFetch) < 3600 { return }
        lastStockFetch = Date()
        if currency == "EUR" { await refreshRate() }
        do {
            let q = try await Fetchers.fetchQuote()
            quote = q
            errorMessage = nil
            checkStockAlert(q)
        } catch {
            errorMessage = "\(tr.marketError) (\(error.localizedDescription))"
        }
    }

    private func checkStockAlert(_ q: StockQuote) {
        guard alertStock, abs(q.changePct) >= stockThreshold else { return }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let key = df.string(from: Date()) + (q.isUp ? "+" : "-")
        guard lastStockAlertDay != key else { return }   // une alerte par jour et par direction
        lastStockAlertDay = key
        let arrow = q.isUp ? "📈" : "📉"
        Notifier.notify(
            title: "\(arrow) " + tr.notifStockTitle(Fmt.pct(q.changePct, tr.localeID)),
            body: tr.notifStockBody(money(q.price), String(format: "%.0f", stockThreshold))
        )
    }

    // MARK: Actualités

    func refreshNews() async {
        let lang = self.lang
        async let ir = try? Fetchers.fetchTakeTwoIR()
        async let bw = try? Fetchers.fetchBusinessWire(lang: lang)
        async let rockstar = try? Fetchers.fetchRockstar(lang: lang)
        async let press = try? Fetchers.fetchPress(lang: lang)
        let (irItems, bwItems, rsItems, pressItems) = await (ir ?? [], bw ?? [], rockstar ?? [], press ?? [])

        // Déduplication grossière entre IR et BusinessWire (mêmes annonces)
        let irTitles = Set(irItems.map { $0.title.lowercased().prefix(40) })
        let bwFiltered = bwItems.filter { !irTitles.contains($0.title.lowercased().prefix(40)) }
        let official = (irItems + bwFiltered + rsItems).sorted { $0.date > $1.date }
        let pressSorted = pressItems.sorted { $0.date > $1.date }

        if !official.isEmpty { officialNews = official }
        if !pressSorted.isEmpty { pressNews = pressSorted }
        earningsDate = RSSParser.extractEarningsDate(from: irItems.map(\.title)) ?? earningsDate
        lastRefresh = Date()

        notifyNewItems(official: official, press: pressSorted)
    }

    private func notifyNewItems(official: [NewsItem], press: [NewsItem]) {
        let all = official + press
        guard !all.isEmpty else { return }

        if firstNewsFetchDone {
            if alertOfficial {
                for item in official.filter({ !seenIDs.contains($0.id) }).prefix(3) {
                    Notifier.notify(title: "\(tr.notifOfficial) — \(item.sourceName)", body: item.title, link: item.link)
                }
            }
            if alertPress {
                for item in press.filter({ !seenIDs.contains($0.id) }).prefix(3) {
                    Notifier.notify(title: "📰 \(item.sourceName)", body: item.title, link: item.link)
                }
            }
        }

        seenIDs.formUnion(all.map(\.id))
        if seenIDs.count > 800 { seenIDs = Set(all.map(\.id)) }
        UserDefaults.standard.set(Array(seenIDs), forKey: "seenIDs")
        if !firstNewsFetchDone {
            firstNewsFetchDone = true
            UserDefaults.standard.set(true, forKey: "firstNewsFetchDone")
        }
    }
}
