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

    /// Intervalle de points adapté à chaque période (assez fin pour être joli, assez gros pour rester léger)
    static func interval(for range: String) -> String {
        switch range {
        case "1d": return "5m"
        case "5d": return "30m"
        default: return "1d"     // 1mo, 6mo, 1y
        }
    }

    static func fetchQuote(range: String = "1d") async throws -> StockQuote {
        // includePrePost sur la vue « 1 jour » : le graphique couvre aussi l'avant/après-séance
        let prePost = range == "1d" ? "&includePrePost=true" : ""
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/TTWO?interval=\(interval(for: range))&range=\(range)\(prePost)")!
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

        // Sommes-nous en avant-séance ou après-clôture ? Si oui, le dernier point coté fait foi.
        let now = Int(Date().timeIntervalSince1970)
        if let tp = meta.currentTradingPeriod {
            let inPre = (tp.pre?.start ?? 0) <= now && now < (tp.pre?.end ?? 0)
            let inPost = (tp.post?.start ?? 0) <= now && now < (tp.post?.end ?? 0)
            if (inPre || inPost), let last = q.points.last, abs(last - q.price) > 0.001 {
                q.extPrice = last
                q.extIsPre = inPre
            }
        }
        return q
    }

    // MARK: Vidéos officielles Rockstar (flux Atom public de leur chaîne YouTube, sans clé API)

    static func fetchRockstarVideos() async throws -> [NewsItem] {
        let url = URL(string: "https://www.youtube.com/feeds/videos.xml?user=RockstarGames")!
        let items = RSSParser.parse(try await data(from: url))
        return items.prefix(5).map { $0.asNews(category: .official, fallbackSource: "Rockstar (YouTube)") }
    }

    // MARK: Posts X des insiders (via le miroir public nitter.net, sans clé API)

    /// Récupère les derniers posts des comptes X suivis. Un compte indisponible est ignoré.
    static func fetchXPosts(handles: [String]) async throws -> [NewsItem] {
        var out: [NewsItem] = []
        for handle in handles {
            let clean = handle.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: "")
            guard !clean.isEmpty, clean.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }),
                  let url = URL(string: "https://nitter.net/\(clean)/rss") else { continue }
            guard let raw = try? await data(from: url) else { continue }
            var items = RSSParser.parse(raw)
            for i in items.indices {
                // Les liens du miroir sont réécrits vers le vrai X
                items[i].link = items[i].link
                    .replacingOccurrences(of: "nitter.net", with: "x.com")
                    .replacingOccurrences(of: "#m", with: "")
            }
            out += items.prefix(15).map { $0.asNews(category: .social, fallbackSource: "@\(clean)") }
        }
        return out
    }

    // MARK: Mise à jour de l'app (API publique GitHub, sans clé)

    private struct GitHubRelease: Decodable {
        let tag_name: String
        let assets: [Asset]
        struct Asset: Decodable {
            let name: String
            let browser_download_url: String
        }
    }

    /// Renvoie la dernière version publiée si elle est plus récente que `current` (ex. "1.6").
    static func checkUpdate(current: String) async throws -> UpdateInfo? {
        let url = URL(string: "https://api.github.com/repos/T0rjant/gta6-watch/releases/latest")!
        let release = try JSONDecoder().decode(GitHubRelease.self, from: try await data(from: url))
        let remote = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
        guard isNewer(remote, than: current),
              let pkg = release.assets.first(where: { $0.name.hasSuffix(".pkg") }),
              let pkgURL = URL(string: pkg.browser_download_url) else { return nil }
        return UpdateInfo(version: remote, pkgURL: pkgURL)
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let av = a.split(separator: ".").compactMap { Int($0) }
        let bv = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(av.count, bv.count) {
            let x = i < av.count ? av[i] : 0
            let y = i < bv.count ? bv[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// Télécharge le .pkg de mise à jour et renvoie son emplacement local.
    static func downloadUpdate(_ info: UpdateInfo) async throws -> URL {
        let raw = try await data(from: info.pkgURL)
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("GTA-VI-Watch-\(info.version).pkg")
        try raw.write(to: dest, options: .atomic)
        return dest
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

    /// Presse gaming & finance.
    /// Source principale : Bing News (vrais résumés d'articles + liens directs vers les sites).
    /// Bing ne supporte pas le OR dans son RSS → trois requêtes simples fusionnées.
    /// Secours : Google News (couverture large mais sans résumés) si Bing ne répond pas.
    static func fetchPress(lang: String) async throws -> [NewsItem] {
        let mkt = lang == "en" ? "en-US" : "fr-FR"
        let fallbackSource = lang == "en" ? "Press" : "Presse"

        async let a = try? fetchBing(query: "%22GTA+6%22", mkt: mkt, fallbackSource: fallbackSource)
        async let b = try? fetchBing(query: "Take-Two", mkt: mkt, fallbackSource: fallbackSource)
        async let c = try? fetchBing(query: "Rockstar+Games", mkt: mkt, fallbackSource: fallbackSource)
        let merged = await (a ?? []) + (b ?? []) + (c ?? [])

        // Déduplication (un même article peut sortir sur plusieurs requêtes)
        var seen = Set<String>()
        let unique = merged.filter { seen.insert(String($0.title.lowercased().prefix(40))).inserted }
        if !unique.isEmpty { return unique }

        // Secours Google News
        let query = "%22GTA%206%22%20OR%20%22GTA%20VI%22%20OR%20%22Take-Two%22%20OR%20%22Rockstar%20Games%22"
        let url = URL(string: "https://news.google.com/rss/search?q=\(query)&\(gnLocale(lang))")!
        let items = RSSParser.parse(try await data(from: url))
        return items.map { $0.asNews(category: .press, fallbackSource: fallbackSource) }
    }

    /// Une requête Bing News RSS
    static func fetchBing(query: String, mkt: String, fallbackSource: String) async throws -> [NewsItem] {
        let cc = mkt.hasSuffix("US") ? "US" : "FR"
        let setlang = mkt.hasSuffix("US") ? "en" : "fr"
        let url = URL(string: "https://www.bing.com/news/search?q=\(query)&format=rss&setmkt=\(mkt)&cc=\(cc)&setlang=\(setlang)")!
        let items = RSSParser.parse(try await data(from: url))
        return items.map { $0.asNews(category: .press, fallbackSource: fallbackSource) }
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
        // Les liens Bing News sont des redirections : on extrait l'URL réelle de l'article
        var cleanLink = link
        if cleanLink.contains("bing.com/news/apiclick"),
           let comps = URLComponents(string: cleanLink),
           let real = comps.queryItems?.first(where: { $0.name == "url" })?.value,
           real.hasPrefix("http") {
            cleanLink = real
        }
        // Google News suffixe les titres avec " - NomDuMedia" ; Bing suffixe les sources avec " on MSN"
        var cleanTitle = title
        var src = (source.isEmpty ? fallbackSource : source)
            .replacingOccurrences(of: " on MSN", with: "")
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
            id: guid.isEmpty ? cleanLink : guid,
            title: cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            link: cleanLink,
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
        // RSS classique : <item> ; Atom (YouTube) : <entry> avec le lien en attribut href
        if name == "item" || name == "entry" { current = RSSRawItem() }
        if name == "link", current != nil, current?.link.isEmpty == true,
           let href = attributes["href"] {
            current?.link = href
        }
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
        case "link": if !value.isEmpty { current?.link = value }
        case "guid", "yt:videoId": current?.guid = value
        case "News:Source": current?.source = value
        case "dc:creator": current?.source = value
        case "pubDate", "published": current?.pubDate = value
        case "description", "media:description": current?.description = value
        case "source": current?.source = value
        case "item", "entry":
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

    static let isoFormatter = ISO8601DateFormatter()

    static func parseDate(_ s: String) -> Date? {
        for f in dateFormats { if let d = f.date(from: s) { return d } }
        return isoFormatter.date(from: s)   // dates Atom YouTube (2026-07-10T17:00:00+00:00)
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
