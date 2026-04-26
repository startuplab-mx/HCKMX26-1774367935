import Foundation

/// Escenarios de demo: secuencias de `FluxUsageEvent` que gatillan cada detector
/// del backend. Útil para presentar el pipeline sin Family Controls.
///
/// Cada escenario dispara un detector específico:
///   - `.nocturnal`       → `atypical_hours`
///   - `.platformSwap`    → `platform_transition`
///   - `.vpnInstall`      → `reactive_install`
///   - `.socialDropoff`   → `digital_isolation`
///   - `.threatCombo`     → múltiples (demo "stress test")
enum MockScenario: String, CaseIterable, Identifiable {
    case nocturnal
    case platformSwap
    case vpnInstall
    case socialDropoff
    case threatCombo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nocturnal:    return "Uso nocturno (2–5am)"
        case .platformSwap: return "Roblox ↔ Discord"
        case .vpnInstall:   return "Instala VPN"
        case .socialDropoff: return "Caída social 7d"
        case .threatCombo:  return "Combo de amenaza"
        }
    }

    var subtitle: String {
        switch self {
        case .nocturnal:    return "4 sesiones de Discord entre 02:30 y 04:30"
        case .platformSwap: return "5 saltos juego↔chat en 40 min"
        case .vpnInstall:   return "ProtonVPN instalado hace 6h"
        case .socialDropoff: return "Instagram bajó 70% vs. 2 semanas previas"
        case .threatCombo:  return "Nocturno + transition + VPN"
        }
    }

    /// Genera los eventos correspondientes al escenario con timestamps realistas.
    func events(now: Date = Date()) -> [FluxUsageEvent] {
        switch self {
        case .nocturnal:       return nocturnalEvents(now: now)
        case .platformSwap:    return platformSwapEvents(now: now)
        case .vpnInstall:      return vpnInstallEvents(now: now)
        case .socialDropoff:   return socialDropoffEvents(now: now)
        case .threatCombo:
            return nocturnalEvents(now: now)
                 + platformSwapEvents(now: now)
                 + vpnInstallEvents(now: now)
        }
    }

    // MARK: - builders

    private func nocturnalEvents(now: Date) -> [FluxUsageEvent] {
        let cal = Calendar(identifier: .gregorian)
        // Anclamos a las 02:30 de "hoy" si aún estamos en madrugada, o de ayer si no.
        let base = cal.date(bySettingHour: 2, minute: 30, second: 0, of: now)
            .map { $0 > now ? cal.date(byAdding: .day, value: -1, to: $0)! : $0 }
            ?? now.addingTimeInterval(-3600 * 12)

        return (0..<4).flatMap { i -> [FluxUsageEvent] in
            let start = base.addingTimeInterval(TimeInterval(i) * 30 * 60)
            let end = start.addingTimeInterval(25 * 60)
            return [
                FluxUsageEvent(kind: .sessionStart, appBundle: "com.hammerandchisel.discord",
                               appName: "Discord", category: .chat, ts: start, durationS: 0),
                FluxUsageEvent(kind: .sessionEnd, appBundle: "com.hammerandchisel.discord",
                               appName: "Discord", category: .chat, ts: end, durationS: 1500),
            ]
        }
    }

    private func platformSwapEvents(now: Date) -> [FluxUsageEvent] {
        let bundles: [(String, String, FluxUsageEvent.Category)] = [
            ("com.roblox.client", "Roblox", .gaming),
            ("com.hammerandchisel.discord", "Discord", .chat),
            ("com.roblox.client", "Roblox", .gaming),
            ("com.hammerandchisel.discord", "Discord", .chat),
            ("com.roblox.client", "Roblox", .gaming),
        ]
        let start = now.addingTimeInterval(-55 * 60)
        return bundles.enumerated().map { i, app in
            FluxUsageEvent(
                kind: .sessionStart,
                appBundle: app.0, appName: app.1, category: app.2,
                ts: start.addingTimeInterval(TimeInterval(i) * 10 * 60),
                durationS: 0
            )
        }
    }

    private func vpnInstallEvents(now: Date) -> [FluxUsageEvent] {
        [FluxUsageEvent(
            kind: .appInstall,
            appBundle: "ch.protonvpn.ios",
            appName: "ProtonVPN",
            category: .vpn,
            ts: now.addingTimeInterval(-6 * 3600),
            durationS: 0
        )]
    }

    private func socialDropoffEvents(now: Date) -> [FluxUsageEvent] {
        var events: [FluxUsageEvent] = []
        // 7 días previos: 45 min/día de Instagram
        for d in 4...10 {
            let day = now.addingTimeInterval(TimeInterval(-d) * 86400)
            events.append(FluxUsageEvent(
                kind: .sessionEnd, appBundle: "com.burbn.instagram",
                appName: "Instagram", category: .social,
                ts: day, durationS: 45 * 60
            ))
        }
        // Últimos 3 días: 10 min/día
        for d in 0...2 {
            let day = now.addingTimeInterval(TimeInterval(-d) * 86400)
            events.append(FluxUsageEvent(
                kind: .sessionEnd, appBundle: "com.burbn.instagram",
                appName: "Instagram", category: .social,
                ts: day, durationS: 10 * 60
            ))
        }
        return events
    }
}
