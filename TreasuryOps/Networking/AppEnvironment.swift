import Foundation

/// Where the app finds the TreasuryOps API.
///
/// Both configurations point at the real deployed backend on the LXC at
/// 192.168.0.226 (docker-compose service `treasury-ops-proxy-1`) — plain
/// HTTP, no local `docker compose up` stack required for iOS development.
/// Debug reaches it over the home LAN directly; Release reaches it over
/// Tailscale (tailnet identity "apps" / 100.73.7.13, MagicDNS
/// `apps.taild40172.ts.net` — confirmed via `tailscale status` on that
/// host; "docker.taild40172.ts.net" is a DIFFERENT machine on the same
/// tailnet and does not run this app).
///
/// Plain HTTP is fine over Tailscale: the WireGuard tunnel already encrypts
/// the transport, so a real TLS cert (`tailscale serve`) isn't needed for
/// confidentiality — it would only be needed to satisfy iOS's App Transport
/// Security. Instead, `Info.plist` carries a scoped ATS exception: `NSAllowsLocalNetworking`
/// covers the private-range Debug IP automatically, and an explicit
/// `NSExceptionDomains` entry covers the Release MagicDNS hostname (see
/// project root `Info.plist`).
enum AppEnvironment {
    static var apiBaseURL: URL {
        #if DEBUG
        return URL(string: "http://192.168.0.226:3006/api")!
        #else
        return URL(string: "http://apps.taild40172.ts.net:3006/api")!
        #endif
    }

    /// The scheme+host(+port) of `apiBaseURL`, with no path — sent as the
    /// `Origin` header on every request. Better Auth checks `Origin` against
    /// its `TRUSTED_ORIGINS` allowlist on state-changing `/auth/*` routes
    /// (sign-in, sign-up, sign-out) and rejects mismatches with 403, even for
    /// non-browser clients. The Debug value (`http://192.168.0.226:3006`)
    /// already matches the deployed backend's `TRUSTED_ORIGINS`; the Release
    /// value (`http://apps.taild40172.ts.net:3006`) still needs to be added
    /// there before sign-in works over Tailscale.
    static var apiOrigin: String {
        var components = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false)!
        components.path = ""
        return components.url!.absoluteString
    }
}
