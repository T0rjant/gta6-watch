// GTA VI Watch — Copyright (C) 2026 Torjant
// SPDX-License-Identifier: AGPL-3.0-or-later
// This program is free software under the GNU AGPL v3; see LICENSE.

import SwiftUI
import AppKit

// MARK: - Ouverture de liens sécurisée

/// N'ouvre que des liens web http(s) : un item de flux RSS malveillant ne peut pas
/// déclencher d'autre schéma d'URL (file:, applescript:, etc.).
enum SafeOpen {
    static func open(_ link: String) {
        guard let url = URL(string: link),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host != nil else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Animation de survol discrète

/// Léger zoom + micro-éclaircissement au passage de la souris (0,15 s, sobre).
/// N'anime que l'élément survolé : coût GPU négligeable.
struct HoverLift: ViewModifier {
    var scale: CGFloat = 1.04
    @State private var hover = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hover ? scale : 1)
            .brightness(hover ? 0.07 : 0)
            .animation(.easeOut(duration: 0.15), value: hover)
            .onHover { hover = $0 }
    }
}

extension View {
    func hoverLift(_ scale: CGFloat = 1.04) -> some View { modifier(HoverLift(scale: scale)) }
}

// MARK: - Signature

/// Signature de l'auteur, affichée dans le dashboard, le popover et les réglages.
struct Credit: View {
    var compact = false

    var body: some View {
        HStack(spacing: 5) {
            if !compact {
                Text("GTA VI Watch \(AppInfo.version) —")
                    .foregroundColor(Vice.textDim)
            }
            Text("by Torjant")
                .fontWeight(.heavy)
                .foregroundStyle(Vice.sunset)
        }
        .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .rounded))
        .frame(maxWidth: .infinity)
    }
}

enum AppInfo {
    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
}

// MARK: - Palette GTA VI

enum Vice {
    static let bg = Color(red: 0.05, green: 0.03, blue: 0.10)
    static let card = Color(red: 0.10, green: 0.07, blue: 0.17)
    static let cardLight = Color(red: 0.14, green: 0.10, blue: 0.22)
    static let pink = Color(red: 1.0, green: 0.18, blue: 0.51)
    static let orange = Color(red: 1.0, green: 0.56, blue: 0.21)
    static let purple = Color(red: 0.48, green: 0.18, blue: 0.97)
    static let green = Color(red: 0.22, green: 0.87, blue: 0.55)
    static let red = Color(red: 1.0, green: 0.30, blue: 0.38)
    static let textDim = Color.white.opacity(0.55)

    static let sunset = LinearGradient(colors: [pink, orange], startPoint: .leading, endPoint: .trailing)
    static let sunsetV = LinearGradient(colors: [purple, pink, orange], startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Dashboard principal

struct DashboardView: View {
    @ObservedObject var store: AppStore
    @State private var showSettings = false

    var body: some View {
        let tr = store.tr
        VStack(spacing: 0) {
            header(tr)
            ScrollView {
                VStack(spacing: 14) {
                    UpdateBanner(store: store)
                    CountdownBanner(store: store)
                    StockCard(store: store)
                    TrailersSection(store: store)
                    HStack(alignment: .top, spacing: 14) {
                        NewsColumn(store: store, title: tr.officialCol, icon: "megaphone.fill",
                                   subtitle: tr.officialSub, items: store.officialNews, accent: Vice.pink)
                        NewsColumn(store: store, title: tr.pressCol, icon: "newspaper.fill",
                                   subtitle: tr.pressSub, items: store.pressNews, accent: Vice.orange)
                        NewsColumn(store: store, title: tr.xCol, icon: "bubble.left.and.bubble.right.fill",
                                   subtitle: tr.xSub, items: store.xNews, accent: Vice.purple)
                    }
                    Credit()
                        .padding(.top, 2)
                }
                .padding(14)
            }
        }
        .frame(minWidth: 1120, minHeight: 640)
        .background(Vice.bg)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) { SettingsView(store: store) }
    }

    private func header(_ tr: L10n) -> some View {
        HStack(spacing: 12) {
            Text("GTA VI WATCH")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Vice.sunset)
            Text(tr.subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Vice.textDim)
            Spacer()
            if let d = store.lastRefresh {
                // TimelineView force le recalcul du texte toutes les 30 s,
                // même quand aucune donnée ne bouge (marché fermé, week-end…)
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    let fresh = Date().timeIntervalSince(d) < 30
                    Text("\(tr.updated) \(fresh ? tr.justNow : Fmt.relative(d, tr.localeID))")
                        .font(.system(size: 11))
                        .foregroundColor(Vice.textDim)
                }
            }
            Button {
                Task { await store.refreshAll() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(store.isRefreshing ? 360 : 0))
                    .animation(store.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: store.isRefreshing)
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .hoverLift(1.18)
            Button { showSettings = true } label: { Image(systemName: "gearshape.fill") }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .hoverLift(1.18)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Vice.card)
    }
}

// MARK: - Mise à jour en un clic

struct UpdateBanner: View {
    @ObservedObject var store: AppStore

    var body: some View {
        let tr = store.tr
        if store.updateStatus != .none {
            HStack(spacing: 10) {
                Text("🚀").font(.system(size: 20))
                switch store.updateStatus {
                case .available(let info):
                    Text(tr.updateTitle("v" + info.version))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        Task { await store.installUpdate() }
                    } label: {
                        Text(tr.updateBtn)
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Capsule().fill(Vice.sunset))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .hoverLift(1.05)
                case .downloading:
                    Text(tr.updateDownloading)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    ProgressView().controlSize(.small)
                case .launched:
                    Text(tr.updateLaunched)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                case .none:
                    EmptyView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Vice.card)
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Vice.sunset.opacity(0.6), lineWidth: 1.5))
            )
        }
    }
}

// MARK: - Compte à rebours GTA VI

struct CountdownBanner: View {
    @ObservedObject var store: AppStore

    var body: some View {
        let tr = store.tr
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                   to: Calendar.current.startOfDay(for: store.releaseDate)).day ?? 0
        HStack(spacing: 10) {
            Text("🌴")
                .font(.system(size: 22))
            if days > 0 {
                Text(tr.daysLeft(days))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Vice.sunset)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tr.release)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Text(Fmt.longDate(store.releaseDate, tr.localeID))
                        .font(.system(size: 10))
                        .foregroundColor(Vice.textDim)
                }
            } else {
                Text(tr.released)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Vice.sunset)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Vice.card)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Vice.sunsetV.opacity(0.35), lineWidth: 1))
        )
    }
}

// MARK: - Carte bourse

struct StockCard: View {
    @ObservedObject var store: AppStore

    var body: some View {
        let q = store.quote
        let tr = store.tr
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(q.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Vice.textDim)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(store.money(q.price))
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text(Fmt.pct(q.changePct, tr.localeID))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background((q.isUp ? Vice.green : Vice.red).opacity(0.18))
                            .foregroundColor(q.isUp ? Vice.green : Vice.red)
                            .clipShape(Capsule())
                        Text("\(q.isUp ? "+" : "")\(store.money(q.change)) \(tr.today)")
                            .font(.system(size: 12))
                            .foregroundColor(Vice.textDim)
                    }
                    // Cotation hors séance (avant l'ouverture / après la clôture)
                    if let ext = q.extPrice {
                        HStack(spacing: 5) {
                            Text(q.extIsPre ? "🌅" : "🌙").font(.system(size: 10))
                            Text("\(q.extIsPre ? tr.preMarket : tr.afterHours) : \(store.money(ext))")
                            Text(Fmt.pct(q.extChangePct, tr.localeID))
                                .foregroundColor(q.extChangePct >= 0 ? Vice.green : Vice.red)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Vice.textDim)
                    }
                }
                Spacer()
                if let earnings = store.earningsDate {
                    VStack(alignment: .trailing, spacing: 3) {
                        Label(tr.nextEarnings, systemImage: "calendar.badge.clock")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Vice.orange)
                        Text(Fmt.longDate(earnings, tr.localeID))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(10)
                    .background(Vice.cardLight)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Sélecteur de période
            HStack(spacing: 6) {
                ForEach(["1d", "5d", "1mo", "6mo", "1y"], id: \.self) { r in
                    Button { store.chartRange = r } label: {
                        Text(tr.rangeLabel(r))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(store.chartRange == r ? AnyShapeStyle(Vice.sunset) : AnyShapeStyle(Vice.cardLight)))
                            .foregroundColor(store.chartRange == r ? .white : Vice.textDim)
                    }
                    .buttonStyle(.plain)
                    .hoverLift(1.08)
                }
                Spacer()
                switch store.marketSession {
                case .open:
                    HStack(spacing: 5) {
                        Circle().fill(Vice.green).frame(width: 6, height: 6)
                        Text(tr.marketOpen)
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Vice.textDim)
                case .pre:
                    Text("🌅 \(tr.preSession) · \(tr.opensAt(Fmt.weekdayTime(store.nextMarketOpen, tr.localeID)))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Vice.orange)
                case .post:
                    Text("🌆 \(tr.postSession)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Vice.orange)
                case .closed:
                    EmptyView()
                }
            }

            // Le graphique de la période choisie prend la couleur de sa tendance
            let rangeUp = (q.points.last ?? 0) >= (q.points.first ?? 0)
            Sparkline(points: q.points, isUp: rangeUp, emptyText: tr.chartClosed)
                .frame(height: 110)
                .overlay(alignment: .topTrailing) {
                    if store.marketSession == .closed {
                        HStack(spacing: 6) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Vice.orange)
                            Text("\(tr.marketClosed) · \(tr.opensAt(Fmt.weekdayTime(store.nextMarketOpen, tr.localeID)))")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Vice.bg.opacity(0.85))
                                .overlay(Capsule().strokeBorder(Vice.orange.opacity(0.35), lineWidth: 1))
                        )
                        .padding(6)
                    }
                }

            HStack(spacing: 0) {
                stat(tr.previousClose, store.money(q.previousClose))
                stat(tr.dayRange, "\(store.money(q.dayLow))  ·  \(store.money(q.dayHigh))")
                stat(tr.volume, Fmt.volume(q.volume))
                stat(tr.fiftyTwoWeeks, "\(store.money(q.fiftyTwoWeekLow))  ·  \(store.money(q.fiftyTwoWeekHigh))")
            }

            // Ma position (uniquement si renseignée dans les réglages)
            if store.hasPosition, q.price > 0 {
                let value = q.price * store.positionShares
                let gain = (q.price - store.positionBuyPrice) * store.positionShares
                let pct = (q.price / store.positionBuyPrice - 1) * 100
                let gainColor = gain >= 0 ? Vice.green : Vice.red
                HStack(spacing: 10) {
                    Text("💼").font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr.myPosition)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Text("\(tr.sharesCount(store.positionShares)) · \(tr.invested) \(store.money(store.positionBuyPrice * store.positionShares))")
                            .font(.system(size: 10))
                            .foregroundColor(Vice.textDim)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(store.money(value))
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("\(gain >= 0 ? "+" : "")\(store.money(gain))  ·  \(Fmt.pct(pct, tr.localeID))")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(gainColor)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Vice.cardLight)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(gainColor.opacity(0.3), lineWidth: 1))
                )
            }

            if let err = store.errorMessage {
                Text(err).font(.system(size: 11)).foregroundColor(Vice.red)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Vice.card)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Vice.sunsetV.opacity(0.35), lineWidth: 1))
        )
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(Vice.textDim)
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Graphique intraday (dessiné à la main, zéro dépendance)

struct Sparkline: View {
    let points: [Double]
    let isUp: Bool
    var emptyText = ""

    var body: some View {
        GeometryReader { geo in
            if points.count > 1 {
                let minV = points.min()!, maxV = points.max()!
                let range = max(maxV - minV, 0.01)
                let stepX = geo.size.width / CGFloat(points.count - 1)
                let ys = points.map { geo.size.height * (1 - CGFloat(($0 - minV) / range)) * 0.92 + geo.size.height * 0.04 }
                let color = isUp ? Vice.green : Vice.red

                let line = Path { p in
                    p.move(to: CGPoint(x: 0, y: ys[0]))
                    for i in 1..<ys.count { p.addLine(to: CGPoint(x: stepX * CGFloat(i), y: ys[i])) }
                }
                line.stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                Path { p in
                    p.move(to: CGPoint(x: 0, y: geo.size.height))
                    p.addLine(to: CGPoint(x: 0, y: ys[0]))
                    for i in 1..<ys.count { p.addLine(to: CGPoint(x: stepX * CGFloat(i), y: ys[i])) }
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [color.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
            } else {
                Text(emptyText)
                    .font(.system(size: 11)).foregroundColor(Vice.textDim)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Trailers officiels GTA VI

struct TrailersSection: View {
    @ObservedObject var store: AppStore

    var body: some View {
        let tr = store.tr
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle.fill").foregroundColor(Vice.pink)
                Text(tr.trailersTitle).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.white)
                Spacer()
                Text(tr.trailersSub).font(.system(size: 10)).foregroundColor(Vice.textDim)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.trailers) { trailer in
                        Button {
                            SafeOpen.open(trailer.url)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                AsyncImage(url: trailer.thumbnail) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(Vice.cardLight)
                                        .overlay(ProgressView().controlSize(.small))
                                }
                                .frame(width: 210, height: 118)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .shadow(radius: 4)
                                )
                                Text(trailer.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .frame(width: 210, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                        .hoverLift(1.03)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Vice.card))
    }
}

// MARK: - Colonnes d'actualités

struct NewsColumn: View {
    @ObservedObject var store: AppStore
    let title: String
    let icon: String
    let subtitle: String
    let items: [NewsItem]
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundColor(accent)
                Text(title).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.white)
                Spacer()
                Text(subtitle).font(.system(size: 10)).foregroundColor(Vice.textDim)
            }
            if items.isEmpty {
                Text(store.tr.loading).font(.system(size: 12)).foregroundColor(Vice.textDim).padding(.vertical, 20)
            }
            LazyVStack(spacing: 8) {
                ForEach(items.prefix(25)) { item in
                    NewsRow(store: store, item: item, accent: accent)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Vice.card))
    }
}

struct NewsRow: View {
    @ObservedObject var store: AppStore
    let item: NewsItem
    let accent: Color
    @State private var hover = false
    @State private var expanded = false

    var body: some View {
        let tr = store.tr
        VStack(alignment: .leading, spacing: 0) {
            // Ligne principale : un clic déplie/replie le panneau de détail
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { expanded.toggle() }
                if expanded { store.markRead(item.id) }
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .top, spacing: 6) {
                        if !store.isRead(item.id) {
                            Circle().fill(accent).frame(width: 6, height: 6).padding(.top, 4)
                        }
                        Text(item.title)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.white.opacity(store.isRead(item.id) ? 0.55 : 1))
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                    }
                    HStack(spacing: 6) {
                        Text(item.sourceName).font(.system(size: 10, weight: .bold)).foregroundColor(accent)
                        Text("·").foregroundColor(Vice.textDim)
                        Text(Fmt.relative(item.date, tr.localeID)).font(.system(size: 10)).foregroundColor(Vice.textDim)
                        Spacer()
                        ForEach(item.tags, id: \.self) { tag in
                            Text("\(tag.emoji) \(tr.tagName(tag))")
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Vice.cardLight)
                                .foregroundColor(.white.opacity(0.8))
                                .clipShape(Capsule())
                        }
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Vice.textDim)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Panneau de détail
            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle()
                        .fill(accent.opacity(0.35))
                        .frame(height: 1)
                    if !item.summary.isEmpty {
                        Text(item.summary)
                            .font(.system(size: 11.5))
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(2.5)
                            .multilineTextAlignment(.leading)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack {
                        Label("\(tr.published) \(Fmt.dateTime(item.date, tr.localeID))", systemImage: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(Vice.textDim)
                        Spacer()
                        Button {
                            SafeOpen.open(item.link)
                        } label: {
                            Text(tr.readArticle)
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().fill(Vice.sunset.opacity(0.9)))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .hoverLift(1.06)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(expanded || hover ? Vice.cardLight : Vice.bg.opacity(0.5)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onHover { hover = $0 }
    }
}

// MARK: - Réglages

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let tr = store.tr
        VStack(alignment: .leading, spacing: 16) {
            Text(tr.settings)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Vice.sunset)

            GroupBox(tr.general) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker(tr.language, selection: $store.lang) {
                        Text("Français").tag("fr")
                        Text("English").tag("en")
                    }.pickerStyle(.segmented)
                    Picker(tr.currency, selection: $store.currency) {
                        Text("USD $").tag("USD")
                        Text("EUR €").tag("EUR")
                    }.pickerStyle(.segmented)
                    Toggle(tr.launchAtLogin, isOn: $store.launchAtLogin)
                    DatePicker(tr.releaseDateSetting, selection: $store.releaseDate, displayedComponents: .date)
                    HStack {
                        Text(tr.xHandlesLbl)
                        Spacer()
                        TextField("videotech", text: $store.xHandles)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 180)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(tr.portfolio) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(tr.sharesLbl)
                        Spacer()
                        TextField("0", value: $store.positionShares, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                    HStack {
                        Text(tr.buyPriceLbl)
                        Spacer()
                        TextField("0", value: $store.positionBuyPrice, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                    Text(tr.portfolioNote)
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(tr.alerts) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(tr.alertOfficialLbl, isOn: store.$alertOfficial)
                    Toggle(tr.alertPressLbl, isOn: store.$alertPress)
                    Toggle(tr.alertStockLbl, isOn: store.$alertStock)
                    Toggle(tr.alertXLbl, isOn: store.$alertX)
                    HStack {
                        Text(tr.threshold(store.stockThreshold))
                        Slider(value: store.$stockThreshold, in: 1...10, step: 0.5).frame(width: 180)
                    }
                    Divider()
                    HStack {
                        Text(tr.alertHighLbl)
                        Spacer()
                        TextField("0", value: $store.alertHighPrice, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                    HStack {
                        Text(tr.alertLowLbl)
                        Spacer()
                        TextField("0", value: $store.alertLowPrice, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                    Text(tr.thresholdOff)
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(tr.refreshFreq) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker(tr.stockLbl, selection: store.$stockIntervalMin) {
                        Text("2 min").tag(2); Text("5 min").tag(5); Text("15 min").tag(15)
                    }.pickerStyle(.segmented)
                    Picker(tr.newsLbl, selection: store.$newsIntervalMin) {
                        Text("15 min").tag(15); Text("30 min").tag(30); Text("1 h").tag(60)
                    }.pickerStyle(.segmented)
                    Text(tr.batteryNote)
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
                .padding(6)
            }

            VStack(spacing: 4) {
                Text("GTA VI Watch \(AppInfo.version) — © 2026 Torjant")
                    .foregroundColor(Vice.textDim)
                HStack(spacing: 4) {
                    Text(tr.licenseNotice)
                        .foregroundColor(Vice.textDim)
                    Button("GNU AGPL v3") { SafeOpen.open("https://www.gnu.org/licenses/agpl-3.0.html") }
                        .buttonStyle(.plain)
                        .foregroundStyle(Vice.sunset)
                }
            }
            .font(.system(size: 10))
            .frame(maxWidth: .infinity)

            HStack {
                Credit()
                Spacer()
                Button(tr.close) {
                    store.scheduleTimers()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Contenu de la barre de menus

struct MenuBarContent: View {
    @ObservedObject var store: AppStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let q = store.quote
        let tr = store.tr
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("TTWO")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Vice.sunset)
                Text(store.money(q.price))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text(Fmt.pct(q.changePct, tr.localeID))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(q.isUp ? Vice.green : Vice.red)
                Spacer()
            }
            Sparkline(points: q.points, isUp: q.isUp, emptyText: tr.chartClosed).frame(height: 44)
            Divider()
            ForEach((store.officialNews + store.pressNews + store.xNews).sorted { $0.date > $1.date }.prefix(4)) { item in
                Button {
                    SafeOpen.open(item.link)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.system(size: 11.5, weight: .medium)).lineLimit(2).foregroundColor(.white)
                        Text("\(item.sourceName) · \(Fmt.relative(item.date, tr.localeID))").font(.system(size: 9.5)).foregroundColor(Vice.textDim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            Divider()
            HStack {
                Button(tr.openDashboard) {
                    openWindow(id: "dashboard")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button(tr.refresh) { Task { await store.refreshAll() } }
                Button(tr.quit) { NSApp.terminate(nil) }
            }
            .font(.system(size: 11))
            Credit(compact: true)
        }
        .padding(12)
        .frame(width: 340)
        .background(Vice.bg)
        .preferredColorScheme(.dark)
    }
}
