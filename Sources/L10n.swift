// GTA VI Watch — Copyright (C) 2026 Torjant
// SPDX-License-Identifier: AGPL-3.0-or-later
// This program is free software under the GNU AGPL v3; see LICENSE.

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
    var justNow: String { en ? "just now" : "à l'instant" }

    // Bourse
    var previousClose: String { en ? "Previous close" : "Clôture précédente" }
    var dayRange: String { en ? "Day low / high" : "Bas / Haut du jour" }
    var volume: String { "Volume" }
    var fiftyTwoWeeks: String { en ? "52 weeks" : "52 semaines" }
    var today: String { en ? "today" : "aujourd'hui" }
    var nextEarnings: String { en ? "Next earnings" : "Prochains résultats" }
    var chartClosed: String { en ? "Chart available during market hours" : "Graphique disponible pendant les heures de marché" }
    var marketError: String { en ? "Market data unavailable" : "Bourse indisponible" }
    var marketClosed: String { en ? "Market closed" : "Marché fermé" }
    var marketOpen: String { en ? "Market open" : "Marché ouvert" }
    var preSession: String { en ? "Pre-market" : "Avant-Bourse" }
    var postSession: String { en ? "After hours" : "Après-Bourse" }
    var nasdaqOpens: String { en ? "NASDAQ opens" : "le NASDAQ ouvre à" }
    func opensAt(_ s: String) -> String { en ? "opens \(s)" : "ouvre \(s)" }
    func rangeLabel(_ r: String) -> String {
        switch r {
        case "1d": return en ? "1D" : "1J"
        case "5d": return en ? "5D" : "5J"
        case "1mo": return "1M"
        case "6mo": return "6M"
        default: return en ? "1Y" : "1A"
        }
    }

    // Hors séance
    var preMarket: String { en ? "Pre-market" : "Avant l'ouverture" }
    var afterHours: String { en ? "After hours" : "Après la clôture" }

    // Mise à jour
    func updateTitle(_ v: String) -> String { en ? "Update \(v) available!" : "Mise à jour \(v) disponible !" }
    var updateBtn: String { en ? "Update now" : "Mettre à jour" }
    var updateDownloading: String { en ? "Downloading…" : "Téléchargement…" }
    var updateLaunched: String {
        en ? "Installer opened — follow the steps, then relaunch the app ✨"
           : "Installateur ouvert — suis les étapes, puis relance l'app ✨"
    }

    // Alertes de seuil de prix
    var alertHighLbl: String { en ? "🎯 Alert above (in $)" : "🎯 Alerte au-dessus de (en $)" }
    var alertLowLbl: String { en ? "⚠️ Alert below (in $)" : "⚠️ Alerte en dessous de (en $)" }
    var thresholdOff: String { en ? "0 = off" : "0 = désactivé" }
    func notifThreshold(_ p: String) -> String { en ? "TTWO crossed \(p)!" : "TTWO a franchi \(p) !" }
    func notifThresholdLow(_ p: String) -> String { en ? "TTWO dropped below \(p)" : "TTWO est passé sous \(p)" }

    // Position personnelle
    var myPosition: String { en ? "My position" : "Ma position" }
    func sharesCount(_ n: Double) -> String {
        let v = n == n.rounded() ? String(Int(n)) : String(format: "%.2f", n)
        return en ? "\(v) shares" : "\(v) actions"
    }
    var invested: String { en ? "invested" : "investi" }

    // Compte à rebours
    var release: String { en ? "GTA VI release" : "Sortie de GTA VI" }
    func daysLeft(_ d: Int) -> String { en ? "\(d) days" : "J-\(d)" }
    var released: String { en ? "GTA VI is out! 🎉" : "GTA VI est sorti ! 🎉" }

    // Trailers
    var trailersTitle: String { en ? "Official GTA VI trailers" : "Trailers officiels GTA VI" }
    var trailersSub: String { en ? "Rockstar Games · YouTube" : "Rockstar Games · YouTube" }

    // Colonnes d'actus
    var officialCol: String { en ? "Official communication" : "Communication officielle" }
    var officialSub: String { "Rockstar · Take-Two IR" }
    var pressCol: String { en ? "Press & Marketing" : "Presse & Marketing" }
    var pressSub: String { "Gaming · Finance" }
    var xCol: String { en ? "X Insiders" : "Insiders X" }
    var xSub: String { en ? "Leaks · rumors" : "Leaks · rumeurs" }
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
    var alertXLbl: String { en ? "🐦 X insider posts" : "🐦 Posts des insiders X" }
    var xHandlesLbl: String { en ? "X accounts (comma-separated)" : "Comptes X (séparés par des virgules)" }
    func threshold(_ v: Double) -> String {
        en ? "Alert threshold: \(String(format: "%.1f", v)) %" : "Seuil d'alerte : \(String(format: "%.1f", v)) %"
    }
    var portfolio: String { en ? "My position (private)" : "Ma position (privé)" }
    var sharesLbl: String { en ? "Number of shares" : "Nombre d'actions" }
    var buyPriceLbl: String { en ? "Average buy price (in $)" : "Prix d'achat moyen (en $)" }
    var portfolioNote: String {
        en ? "Stored only on this Mac — never sent anywhere. Set shares to 0 to hide."
           : "Stocké uniquement sur ce Mac — jamais envoyé nulle part. Mets 0 action pour masquer."
    }
    var refreshFreq: String { en ? "Refresh frequency" : "Fréquence d'actualisation" }
    var stockLbl: String { en ? "Stock:" : "Bourse :" }
    var newsLbl: String { en ? "News:" : "Actualités :" }
    var batteryNote: String { en ? "Longer intervals use less battery." : "Des intervalles plus longs consomment moins de batterie." }
    var close: String { en ? "Close" : "Fermer" }

    // Panneau de détail d'un article
    var readArticle: String { en ? "Read article ↗" : "Lire l'article ↗" }
    var published: String { en ? "Published" : "Publié" }

    var licenseNotice: String {
        en ? "Free software, no warranty — released under the"
           : "Logiciel libre, sans garantie — publié sous"
    }

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

    /// « lun. 15:30 » — jour + heure locale, pour la prochaine ouverture du marché
    static func weekdayTime(_ d: Date, _ localeID: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: localeID)
        f.dateFormat = localeID == "en_US" ? "EEE h:mm a" : "EEE HH:mm"
        return f.string(from: d)
    }

    static func dateTime(_ d: Date, _ localeID: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: localeID)
        f.dateStyle = .long
        f.timeStyle = .short
        return f.string(from: d)
    }

    static func longDate(_ d: Date, _ localeID: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: localeID)
        f.dateStyle = .full
        return f.string(from: d)
    }
}
