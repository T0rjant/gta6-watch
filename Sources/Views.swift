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
                    CountdownBanner(store: store)
                    StockCard(store: store)
                    HStack(alignment: .top, spacing: 14) {
                        NewsColumn(store: store, title: tr.officialCol, icon: "megaphone.fill",
                                   subtitle: tr.officialSub, items: store.officialNews, accent: Vice.pink)
                        NewsColumn(store: store, title: tr.pressCol, icon: "newspaper.fill",
                                   subtitle: tr.pressSub, items: store.pressNews, accent: Vice.orange)
                    }
                    Credit()
                        .padding(.top, 2)
                }
                .padding(14)
            }
        }
        .frame(minWidth: 900, minHeight: 640)
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
                Text("\(tr.updated) \(Fmt.relative(d, tr.localeID))")
                    .font(.system(size: 11))
                    .foregroundColor(Vice.textDim)
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
            Button { showSettings = true } label: { Image(systemName: "gearshape.fill") }
                .buttonStyle(.plain)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Vice.card)
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

            Sparkline(points: q.points, isUp: q.isUp, emptyText: tr.chartClosed)
                .frame(height: 110)

            HStack(spacing: 0) {
                stat(tr.previousClose, store.money(q.previousClose))
                stat(tr.dayRange, "\(store.money(q.dayLow))  ·  \(store.money(q.dayHigh))")
                stat(tr.volume, Fmt.volume(q.volume))
                stat(tr.fiftyTwoWeeks, "\(store.money(q.fiftyTwoWeekLow))  ·  \(store.money(q.fiftyTwoWeekHigh))")
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
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
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
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(tr.alerts) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(tr.alertOfficialLbl, isOn: store.$alertOfficial)
                    Toggle(tr.alertPressLbl, isOn: store.$alertPress)
                    Toggle(tr.alertStockLbl, isOn: store.$alertStock)
                    HStack {
                        Text(tr.threshold(store.stockThreshold))
                        Slider(value: store.$stockThreshold, in: 1...10, step: 0.5).frame(width: 180)
                    }
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
            ForEach((store.officialNews + store.pressNews).sorted { $0.date > $1.date }.prefix(4)) { item in
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
