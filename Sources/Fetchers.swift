// GTA VI Watch — Copyright (C) 2026 Torjant
// SPDX-License-Identifier: AGPL-3.0-or-later
// This program is free software under the GNU AGPL v3; see LICENSE.

import Foundation

// MARK: - Réseau

enum Fetchers {
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    static func data(from url: URL) async throws -> Data {
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    // MARK: Bourse TTWO (Yahoo Finance)

    static func fetchQuote() async throws -> StockQuote {
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/TTWO?interval=5m&range=1d")!
        let raw = try await data(from: url)
        let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: raw)
        guard let result = decoded.chart.result?.first else { throw URLError(.cannotParseResponse) }
        let meta = result.meta

        var q = StockQuote()
        q.price = meta.regularMarketPrice
        q.previousClose = meta.previousClose ?? meta.chartPreviousClose ?? meta.regularMarketPrice
        q.dayHigh = meta.regularMarketDayHigh ?? 0
        q.dayLow = meta.regularMarketDayLow ?? 0
        q.volume = meta.regularMarketVolume ?? 0
        q.fiftyTwoWeekHigh = meta.fiftyTwoWeekHigh ?? 0
        q.fiftyTwoWeekLow = meta.fiftyTwoWeekLow ?? 0
        q.marketTime = Date(timeIntervalSince1970: TimeInterval(meta.regularMarketTime ?? 0))
        q.name = meta.longName ?? q.name
        q.points = (result.indicators.quote.first?.close ?? []).compactMap { $0 }
        return q
    }

    // MARK: Flux d'actualités

    /// Communiqués officiels Take-Two (Investor Relations)
    static func fetchTakeTwoIR() async throws -> [NewsItem] {
        let url = URL(string: "https://ir.take2games.com/rss/news-releases.xml")!
        let items = RSSParser.parse(try await data(from: url))
        return items.map { $0.asNews(category: .official, fallbackSource: "Take-Two (officiel)") }
    }

    /// Paramètres régionaux Google News selon la langue de l'app
    static func gnLocale(_ lang: String) -> String {
        lang == "en" ? "hl=en-US&gl=US&ceid=US:en" : "hl=fr&gl=FR&ceid=FR:fr"
    }

    /// Taux de change EUR/USD (dollars pour 1 euro) via Yahoo Finance
    static func fetchEURUSD() async throws -> Double {
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/EURUSD=X?interval=1d&range=1d")!
        let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: try await data(from: url))
        guard let rate = decoded.chart.result?.first?.meta.regularMarketPrice, rate > 0 else {
            throw URLError(.cannotParseResponse)
        }
        return rate
    }

    /// Actus publiées sur rockstargames.com (via Google News, pas de RSS direct chez Rockstar)
    static func fetchRockstar(lang: String) async throws -> [NewsItem] {
        let url = URL(string: "https://news.google.com/rss/search?q=site:rockstargames.com&\(gnLocale(lang))")!
        let items = RSSParser.parse(try await data(from: url))
        return items.map { $0.asNews(category: .official, fallbackSource: "Rockstar Games") }
    }

    /// Communiqués Take-Two publiés sur BusinessWire (via Google News).
    /// Complète le flux IR, dont le CDN sert parfois une copie périmée.
    static func fetchBusinessWire(lang: String) async throws -> [NewsItem] {
        let url = URL(string: "https://news.google.com/rss/search?q=%22Take-Two%22%20site:businesswire.com&\(gnLocale(lang))")!
        let items = RSSParser.parse(try await data(from: url))
        let fallback = lang == "en" ? "Take-Two (press release)" : "Take-Two (communiqué)"
        return items
            .map { $0.asNews(category: .official, fallbackSource: fallback) }
            .filter {
                let t = $0.title.lowercased()
                return t.contains("take-two") || t.contains("rockstar") || t.contains("grand theft auto") || t.contains("gta")
            }
    }

    /// Presse gaming & finance (Google News)
    static func fetchPress(lang: String) async throws -> [NewsItem] {
        let query = "%22GTA%206%22%20OR%20%22GTA%20VI%22%20OR%20%22Take-Two%22%20OR%20%22Rockstar%20Games%22"
        let url = URL(string: "https://news.google.com/rss/search?q=\(query)&\(gnLocale(lang))")!
        let items = RSSParser.parse(try await data(from: url))
        return items.map { $0.asNews(category: .press, fallbackSource: lang == "en" ? "Press" : "Presse") }
    }
}

// MARK: - Parseur RSS minimal (sans dépendance)

struct RSSRawItem {
    var title = ""
    var link = ""
    var guid = ""
    var pubDate = ""
    var description = ""
    var source = ""

    func asNews(category: NewsCategory, fallbackSource: String) -> NewsItem {
        // Google News suffixe les titres avec " - NomDuMedia"
        var cleanTitle = title
        var src = source.isEmpty ? fallbackSource : source
        if source.isEmpty == false, let range = cleanTitle.range(of: " - \(source)", options: [.backwards]) {
            cleanTitle.removeSubrange(range)
        } else if category == .press || fallbackSource == "Rockstar Games" {
            if let idx = cleanTitle.range(of: " - ", options: .backwards) {
                src = String(cleanTitle[idx.upperBound...])
                cleanTitle = String(cleanTitle[..<idx.lowerBound])
            }
        }
        var plainSummary = description
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Google News répète le titre en guise de description : dans ce cas, pas de vrai résumé
        if plainSummary.hasPrefix(String(cleanTitle.prefix(30))) || plainSummary.count < 40 {
            plainSummary = ""
        }
        return NewsItem(
            id: guid.isEmpty ? link : guid,
            title: cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            link: link,
            date: RSSParser.parseDate(pubDate) ?? Date(),
            sourceName: src,
            category: category,
            summary: String(plainSummary.prefix(400))
        )
    }
}

final class RSSParser: NSObject, XMLParserDelegate {
    private var items: [RSSRawItem] = []
    private var current: RSSRawItem?
    private var currentElement = ""
    private var buffer = ""

    static func parse(_ data: Data) -> [RSSRawItem] {
        let p = RSSParser()
        let parser = XMLParser(data: data)
        parser.delegate = p
        parser.parse()
        return p.items
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        currentElement = name
        buffer = ""
        if name == "item" { current = RSSRawItem() }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { buffer += string }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        buffer += String(data: CDATABlock, encoding: .utf8) ?? ""
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        guard current != nil else { return }
        let value = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "title": current?.title = value
        case "link": current?.link = value
        case "guid": current?.guid = value
        case "pubDate": current?.pubDate = value
        case "description": current?.description = value
        case "source": current?.source = value
        case "item":
            if let item = current { items.append(item) }
            current = nil
        default: break
        }
    }

    static let dateFormats: [DateFormatter] = {
        ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz", "yyyy-MM-dd'T'HH:mm:ssZ"].map {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = $0
            return f
        }
    }()

    static func parseDate(_ s: String) -> Date? {
        for f in dateFormats { if let d = f.date(from: s) { return d } }
        return nil
    }

    /// Extrait la prochaine date de résultats depuis un titre IR du type
    /// "… to Report First Quarter … Results on Friday, August 7, 2026"
    static func extractEarningsDate(from titles: [String]) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM d, yyyy"
        let regex = try! NSRegularExpression(pattern: "on [A-Za-z]+, ([A-Za-z]+ \\d{1,2}, \\d{4})")
        for title in titles {
            let range = NSRange(title.startIndex..., in: title)
            if let m = regex.firstMatch(in: title, range: range),
               let r = Range(m.range(at: 1), in: title),
               let date = f.date(from: String(title[r])), date > Date() {
                return date
            }
        }
        return nil
    }
}
