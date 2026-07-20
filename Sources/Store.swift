// GTA VI Watch — Copyright (C) 2026 Torjant
// SPDX-License-Identifier: AGPL-3.0-or-later
// This program is free software under the GNU AGPL v3; see LICENSE.

import Foundation
import SwiftUI
import AppKit
import ServiceManagement

@MainActor
final class AppStore: ObservableObject {
    @Published var quote = StockQuote()
    @Published var officialNews: [NewsItem] = []
    @Published var pressNews: [NewsItem] = []
    @Published var xNews: [NewsItem] = []
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

    // Période du graphique ("1d", "5d", "1mo", "6mo", "1y")
    @Published var chartRange: String {
        didSet {
            guard chartRange != oldValue else { return }
            UserDefaults.standard.set(chartRange, forKey: "chartRange")
            Task { await refreshStock(force: true) }
        }
    }

    // Position personnelle : stockée uniquement en local sur ce Mac, jamais envoyée nulle part
    @Published var positionShares: Double {
        didSet { UserDefaults.standard.set(positionShares, forKey: "positionShares") }
    }
    @Published var positionBuyPrice: Double {   // prix d'achat moyen, en $ (monnaie de cotation)
        didSet { UserDefaults.standard.set(positionBuyPrice, forKey: "positionBuyPrice") }
    }
    var hasPosition: Bool { positionShares > 0 && positionBuyPrice > 0 }

    // Seuils d'alerte de prix personnalisés (en $, 0 = désactivé)
    @Published var alertHighPrice: Double {
        didSet { UserDefaults.standard.set(alertHighPrice, forKey: "alertHighPrice") }
    }
    @Published var alertLowPrice: Double {
        didSet { UserDefaults.standard.set(alertLowPrice, forKey: "alertLowPrice") }
    }

    // Mise à jour de l'app
    @Published var updateStatus: UpdateStatus = .none

    // Comptes X suivis (séparés par des virgules), modifiables dans les réglages
    @Published var xHandles: String {
        didSet {
            guard xHandles != oldValue else { return }
            UserDefaults.standard.set(xHandles, forKey: "xHandles")
            Task { await refreshNews() }
        }
    }
    @AppStorage("alertX") var alertX = false

    // Trailers officiels (les 2 connus + détection auto depuis le flux Rockstar)
    @Published var trailers: [Trailer] = Trailer.known

    // Articles lus (marqués au clic)
    @Published private(set) var readIDs: Set<String>
    func isRead(_ id: String) -> Bool { readIDs.contains(id) }
    func markRead(_ id: String) {
        guard readIDs.insert(id).inserted else { return }
        if readIDs.count > 1000 { readIDs = Set(readIDs.suffix(500)) }
        UserDefaults.standard.set(Array(readIDs), forKey: "readIDs")
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
        chartRange = d.string(forKey: "chartRange") ?? "1d"
        positionShares = d.double(forKey: "positionShares")
        positionBuyPrice = d.double(forKey: "positionBuyPrice")
        alertHighPrice = d.double(forKey: "alertHighPrice")
        alertLowPrice = d.double(forKey: "alertLowPrice")
        readIDs = Set(d.stringArray(forKey: "readIDs") ?? [])
        // Insiders GTA VI par défaut (vérifiés) : Ben, Tex2 (ex-Tez2), Tom Henderson, Chris Klippel
        let defaultHandles = "videotech, TexFunz2, _Tom_Henderson_, Chris_Klippel"
        let savedHandles = d.string(forKey: "xHandles")
        xHandles = (savedHandles == nil || savedHandles == "videotech") ? defaultHandles : savedHandles!
    }

    func start() {
        Notifier.requestPermission()
        Task { await refreshAll() }
        Task { await checkForUpdate() }
        scheduleTimers()
    }

    // MARK: Mise à jour de l'app

    private var lastUpdateCheck: Date = .distantPast

    func checkForUpdate() async {
        guard Date().timeIntervalSince(lastUpdateCheck) > 6 * 3600 else { return }
        lastUpdateCheck = Date()
        if case .none = updateStatus,
           let info = try? await Fetchers.checkUpdate(current: AppInfo.version) {
            updateStatus = .available(info)
        }
    }

    /// Mise à jour en un clic : télécharge le .pkg puis ouvre l'installateur macOS.
    func installUpdate() async {
        guard case .available(let info) = updateStatus else { return }
        updateStatus = .downloading
        do {
            let pkg = try await Fetchers.downloadUpdate(info)
            NSWorkspace.shared.open(pkg)
            updateStatus = .launched
        } catch {
            updateStatus = .available(info)   // on pourra réessayer
        }
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

    /// Sessions du NASDAQ (heure de New York, lun–ven) :
    /// avant-Bourse 4h–9h30, séance 9h30–16h, après-Bourse 16h–20h, fermé sinon.
    enum MarketSession { case pre, open, post, closed }

    var marketSession: MarketSession {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        guard (2...6).contains(weekday) else { return .closed }
        let minutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        switch minutes {
        case (4 * 60)..<(9 * 60 + 30): return .pre
        case (9 * 60 + 30)...(16 * 60): return .open
        case (16 * 60 + 1)...(20 * 60): return .post
        default: return .closed
        }
    }

    var marketIsOpen: Bool { marketSession == .open }

    /// Prochaine ouverture du NASDAQ (9h30 à New York), affichée en heure locale de l'utilisateur.
    var nextMarketOpen: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        var day = Date()
        for _ in 0..<8 {
            let weekday = cal.component(.weekday, from: day)
            if (2...6).contains(weekday),
               let open = cal.date(bySettingHour: 9, minute: 30, second: 0, of: day),
               open > Date() {
                return open
            }
            day = cal.date(byAdding: .day, value: 1, to: day) ?? day
        }
        return Date()
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
        // Rythme normal dès qu'il y a de la cotation (séance, avant/après-Bourse) ;
        // mode économie (1 requête/heure) uniquement la nuit profonde et le week-end
        if !force, marketSession == .closed, quote.price > 0,
           Date().timeIntervalSince(lastStockFetch) < 3600 { return }
        lastStockFetch = Date()
        if currency == "EUR" { await refreshRate() }
        do {
            let q = try await Fetchers.fetchQuote(range: chartRange)
            quote = q
            errorMessage = nil
            checkStockAlert(q)
        } catch {
            errorMessage = "\(tr.marketError) (\(error.localizedDescription))"
        }
    }

    private func checkStockAlert(_ q: StockQuote) {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let today = df.string(from: Date())

        // Alerte de variation quotidienne (en %)
        if alertStock, abs(q.changePct) >= stockThreshold {
            let key = today + (q.isUp ? "+" : "-")
            if lastStockAlertDay != key {   // une alerte par jour et par direction
                lastStockAlertDay = key
                let arrow = q.isUp ? "📈" : "📉"
                Notifier.notify(
                    title: "\(arrow) " + tr.notifStockTitle(Fmt.pct(q.changePct, tr.localeID)),
                    body: tr.notifStockBody(money(q.price), String(format: "%.0f", stockThreshold))
                )
            }
        }

        // Seuils de prix personnalisés (une alerte par jour et par seuil)
        let d = UserDefaults.standard
        if alertHighPrice > 0, q.price >= alertHighPrice, d.string(forKey: "thresholdHighDay") != today {
            d.set(today, forKey: "thresholdHighDay")
            Notifier.notify(title: "🎯 " + tr.notifThreshold(money(alertHighPrice)),
                            body: "TTWO : \(money(q.price))")
        }
        if alertLowPrice > 0, q.price <= alertLowPrice, d.string(forKey: "thresholdLowDay") != today {
            d.set(today, forKey: "thresholdLowDay")
            Notifier.notify(title: "⚠️ " + tr.notifThresholdLow(money(alertLowPrice)),
                            body: "TTWO : \(money(q.price))")
        }
    }

    // MARK: Actualités

    func refreshNews() async {
        let lang = self.lang
        async let ir = try? Fetchers.fetchTakeTwoIR()
        async let bw = try? Fetchers.fetchBusinessWire(lang: lang)
        async let rockstar = try? Fetchers.fetchRockstar(lang: lang)
        async let videos = try? Fetchers.fetchRockstarVideos()
        async let press = try? Fetchers.fetchPress(lang: lang)
        let handles = xHandles.split(separator: ",").map(String.init)
        async let xPosts = try? Fetchers.fetchXPosts(handles: handles)
        let (irItems, bwItems, rsItems, videoItems, pressItems, xItems) = await (ir ?? [], bw ?? [], rockstar ?? [], videos ?? [], press ?? [], xPosts ?? [])

        // Déduplication grossière entre IR et BusinessWire (mêmes annonces)
        let irTitles = Set(irItems.map { $0.title.lowercased().prefix(40) })
        let bwFiltered = bwItems.filter { !irTitles.contains($0.title.lowercased().prefix(40)) }
        let official = (irItems + bwFiltered + rsItems + videoItems).sorted { $0.date > $1.date }
        let pressSorted = pressItems.sorted { $0.date > $1.date }

        if !official.isEmpty { officialNews = official }
        if !pressSorted.isEmpty { pressNews = pressSorted }
        let xSorted = xItems.sorted { $0.date > $1.date }
        if !xSorted.isEmpty { xNews = xSorted }

        // Détection automatique de nouveaux trailers GTA VI — uniquement depuis
        // le flux officiel Rockstar (impossible de se faire piéger par une fausse chaîne)
        for video in videoItems {
            let t = video.title.lowercased()
            if (t.contains("grand theft auto vi") || t.contains("gta vi") || t.contains("gta 6")),
               t.contains("trailer"),
               !video.id.isEmpty,
               !trailers.contains(where: { $0.id == video.id }) {
                trailers.insert(Trailer(id: video.id, title: video.title), at: 0)
            }
        }
        earningsDate = RSSParser.extractEarningsDate(from: irItems.map(\.title)) ?? earningsDate
        lastRefresh = Date()

        notifyNewItems(official: official, press: pressSorted, x: xSorted)
    }

    private func notifyNewItems(official: [NewsItem], press: [NewsItem], x: [NewsItem]) {
        let all = official + press + x
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
            if alertX {
                for item in x.filter({ !seenIDs.contains($0.id) }).prefix(2) {
                    Notifier.notify(title: "🐦 \(item.sourceName)", body: item.title, link: item.link)
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
