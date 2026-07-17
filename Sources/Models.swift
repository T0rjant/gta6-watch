// GTA VI Watch — Copyright (C) 2026 Torjant
// SPDX-License-Identifier: AGPL-3.0-or-later
// This program is free software under the GNU AGPL v3; see LICENSE.

import Foundation

// MARK: - Bourse

struct StockQuote: Equatable {
    var symbol: String = "TTWO"
    var name: String = "Take-Two Interactive"
    var price: Double = 0
    var previousClose: Double = 0
    var dayHigh: Double = 0
    var dayLow: Double = 0
    var volume: Int = 0
    var fiftyTwoWeekHigh: Double = 0
    var fiftyTwoWeekLow: Double = 0
    var marketTime: Date = .distantPast
    var points: [Double] = []          // clôtures intraday (5 min)

    var change: Double { price - previousClose }
    var changePct: Double { previousClose != 0 ? (change / previousClose) * 100 : 0 }
    var isUp: Bool { change >= 0 }
}

// MARK: - Actualités

enum NewsCategory: String, Codable {
    case official   // Take-Two IR + Rockstar
    case press      // presse gaming & finance
}

enum NewsTag: String, CaseIterable {
    case trailer   = "Trailer"
    case finance   = "Finance"
    case marketing = "Marketing"
    case sortie    = "Sortie"
    case gta6      = "GTA VI"

    var emoji: String {
        switch self {
        case .trailer:   return "🎬"
        case .finance:   return "💹"
        case .marketing: return "📣"
        case .sortie:    return "📅"
        case .gta6:      return "🌴"
        }
    }
}

struct NewsItem: Identifiable, Equatable {
    let id: String            // guid ou lien
    let title: String
    let link: String
    let date: Date
    let sourceName: String    // "Take-Two IR", "Rockstar Games", "IGN"…
    let category: NewsCategory
    let summary: String

    var tags: [NewsTag] {
        let t = (title + " " + summary).lowercased()
        var out: [NewsTag] = []
        if t.contains("gta 6") || t.contains("gta vi") || t.contains("grand theft auto vi") { out.append(.gta6) }
        if t.contains("trailer") || t.contains("bande-annonce") || t.contains("bande annonce") || t.contains("vidéo") || t.contains("video") { out.append(.trailer) }
        if t.contains("bourse") || t.contains("action") || t.contains("résultat") || t.contains("earnings") || t.contains("nasdaq") || t.contains("investisseur") || t.contains("investor") || t.contains("stock") || t.contains("fiscal") || t.contains("financial") { out.append(.finance) }
        if t.contains("marketing") || t.contains("précommande") || t.contains("pre-order") || t.contains("preorder") || t.contains("campagne") || t.contains("campaign") || t.contains("publicité") { out.append(.marketing) }
        if t.contains("date de sortie") || t.contains("release date") || t.contains("sortira") || t.contains("lancement") || t.contains("launch") { out.append(.sortie) }
        return Array(out.prefix(3))
    }
}

// MARK: - Décodage Yahoo Finance

struct YahooChartResponse: Decodable {
    struct Chart: Decodable { let result: [Result]? }
    struct Result: Decodable {
        let meta: Meta
        let timestamp: [Int]?
        let indicators: Indicators
    }
    struct Meta: Decodable {
        let regularMarketPrice: Double
        let previousClose: Double?
        let chartPreviousClose: Double?
        let regularMarketDayHigh: Double?
        let regularMarketDayLow: Double?
        let regularMarketVolume: Int?
        let fiftyTwoWeekHigh: Double?
        let fiftyTwoWeekLow: Double?
        let regularMarketTime: Int?
        let longName: String?
    }
    struct Indicators: Decodable { let quote: [Quote] }
    struct Quote: Decodable { let close: [Double?]? }
    let chart: Chart
}
