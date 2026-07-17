import Foundation

/// Chaînes de l'interface en français et anglais.
/// Pas de fichiers .strings : une seule source de vérité, lisible et diffable.
struct L10n {
    let en: Bool
    init(_ lang: String) { en = (lang == "en") }

    var localeID: String { en ? "en_US" : "fr_FR" }
    var locale: Locale { Locale(identifier: localeID) }

    // Header
    var subtitle: String { "Take-Two Interactive · NASDAQ: TTWO" }
    var updated: String { en ? "Updated" : "Actualisé" }

    // Bourse
    var previousClose: String { en ? "Previous close" : "Clôture précédente" }
    var dayRange: String { en ? "Day low / high" : "Bas / Haut du jour" }
    var volume: String { "Volume" }
    var fiftyTwoWeeks: String { en ? "52 weeks" : "52 semaines" }
    var today: String { en ? "today" : "aujourd'hui" }
    var nextEarnings: String { en ? "Next earnings" : "Prochains résultats" }
    var chartClosed: String { en ? "Chart available during market hours" : "Graphique disponible pendant les heures de marché" }
    var marketError: String { en ? "Market data unavailable" : "Bourse indisponible" }

    // Compte à rebours
    var release: String { en ? "GTA VI release" : "Sortie de GTA VI" }
    func daysLeft(_ d: Int) -> String { en ? "\(d) days" : "J-\(d)" }
    var released: String { en ? "GTA VI is out! 🎉" : "GTA VI est sorti ! 🎉" }

    // Colonnes d'actus
    var officialCol: String { en ? "Official communication" : "Communication officielle" }
    var officialSub: String { "Rockstar · Take-Two IR" }
    var pressCol: String { en ? "Press & Marketing" : "Presse & Marketing" }
    var pressSub: String { "Gaming · Finance" }
    var loading: String { en ? "Loading…" : "Chargement…" }

    // Réglages
    var settings: String { en ? "Settings" : "Réglages" }
    var general: String { en ? "General" : "Général" }
    var language: String { en ? "Language" : "Langue" }
    var currency: String { en ? "Currency" : "Devise" }
    var launchAtLogin: String { en ? "Launch at login" : "Lancer au démarrage du Mac" }
    var releaseDateSetting: String { en ? "GTA VI release date" : "Date de sortie GTA VI" }
    var alerts: String { en ? "Alerts" : "Alertes" }
    var alertOfficialLbl: String { en ? "🚨 Official announcements (Rockstar / Take-Two)" : "🚨 Annonces officielles (Rockstar / Take-Two)" }
    var alertPressLbl: String { en ? "📰 New press articles" : "📰 Nouveaux articles de presse" }
    var alertStockLbl: String { en ? "💹 Stock movement" : "💹 Mouvement de bourse" }
    func threshold(_ v: Double) -> String {
        en ? "Alert threshold: \(String(format: "%.1f", v)) %" : "Seuil d'alerte : \(String(format: "%.1f", v)) %"
    }
    var refreshFreq: String { en ? "Refresh frequency" : "Fréquence d'actualisation" }
    var stockLbl: String { en ? "Stock:" : "Bourse :" }
    var newsLbl: String { en ? "News:" : "Actualités :" }
    var batteryNote: String { en ? "Longer intervals use less battery." : "Des intervalles plus longs consomment moins de batterie." }
    var close: String { en ? "Close" : "Fermer" }

    // Barre de menus
    var openDashboard: String { en ? "Open dashboard" : "Ouvrir le dashboard" }
    var refresh: String { en ? "Refresh" : "Actualiser" }
    var quit: String { en ? "Quit" : "Quitter" }

    // Notifications
    var notifOfficial: String { en ? "🚨 Official announcement" : "🚨 Annonce officielle" }
    func notifStockTitle(_ pct: String) -> String { en ? "TTWO \(pct) today" : "TTWO \(pct) aujourd'hui" }
    func notifStockBody(_ price: String, _ threshold: String) -> String {
        en ? "Take-Two: \(price) (alert threshold: \(threshold) %)" : "Take-Two : \(price) (seuil d'alerte : \(threshold) %)"
    }

    // Badges d'articles
    func tagName(_ tag: NewsTag) -> String {
        switch tag {
        case .trailer:   return "Trailer"
        case .finance:   return "Finance"
        case .marketing: return "Marketing"
        case .sortie:    return en ? "Release" : "Sortie"
        case .gta6:      return "GTA VI"
        }
    }
}

// MARK: - Formatage localisé

enum Fmt {
    private static var formatters: [String: NumberFormatter] = [:]

    private static func decimalFormatter(_ localeID: String) -> NumberFormatter {
        if let f = formatters[localeID] { return f }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.locale = Locale(identifier: localeID)
        formatters[localeID] = f
        return f
    }

    static func decimal(_ v: Double, _ localeID: String) -> String {
        decimalFormatter(localeID).string(from: NSNumber(value: v)) ?? "–"
    }

    static func pct(_ v: Double, _ localeID: String) -> String {
        (v >= 0 ? "+" : "") + decimal(v, localeID) + " %"
    }

    static func volume(_ v: Int) -> String {
        if v >= 1_000_000 { return String(format: "%.2f M", Double(v) / 1_000_000) }
        if v >= 1_000 { return String(format: "%.0f k", Double(v) / 1_000) }
        return "\(v)"
    }

    static func relative(_ d: Date, _ localeID: String) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: localeID)
        f.unitsStyle = .short
        return f.localizedString(for: d, relativeTo: Date())
    }

    static func longDate(_ d: Date, _ localeID: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: localeID)
        f.dateStyle = .full
        return f.string(from: d)
    }
}
