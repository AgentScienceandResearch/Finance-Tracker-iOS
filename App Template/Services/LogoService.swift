import Foundation

/// Resolves merchant names to logo.dev image URLs.
/// Uses the embedded publishable key immediately; optionally refreshes from the backend
/// so the Railway LOGO_DEV_TOKEN env var can override it (e.g. to rotate keys).
@MainActor
final class LogoService: ObservableObject {
    static let shared = LogoService()

    // Publishable key — safe to ship in the client bundle (appears in every image URL).
    // Set LOGO_DEV_TOKEN in Railway to override without a re-deploy.
    private static let embeddedPublishableKey = "pk_VfLJ3VfBQCiaIl-gF2sL7A"

    private var token: String = embeddedPublishableKey
    private var fetchTask: Task<Void, Never>?

    private init() {
        // Kick off a background refresh so Railway overrides take effect without delay.
        prefetchToken()
    }

    // MARK: - Public API

    func logoURL(for merchant: String) -> URL? {
        guard !token.isEmpty else { return nil }
        guard let domain = Self.domain(for: merchant) else { return nil }
        return URL(string: "https://img.logo.dev/\(domain)?token=\(token)&size=64&format=png")
    }

    // MARK: - Token Refresh

    private func prefetchToken() {
        guard fetchTask == nil else { return }
        fetchTask = Task {
            guard let url = URL(string: AppConfig.shared.apiURL.absoluteString + "/api/config") else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let remote = json["logoDevToken"] as? String, !remote.isEmpty {
                    token = remote
                }
            } catch {
                // Embedded key stays active — no-op on network failure.
            }
            fetchTask = nil
        }
    }

    // MARK: - Merchant → Domain Mapping

    static func domain(for merchant: String) -> String? {
        let key = merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Exact / prefix match against known brands
        for (pattern, domain) in Self.knownDomains {
            if key == pattern || key.hasPrefix(pattern) || key.contains(pattern) {
                return domain
            }
        }

        // Generic guess: single-word names might map to name.com
        let words = key.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let first = words.first, first.count >= 3,
              !["the", "and", "for", "my", "our"].contains(first) else { return nil }

        // Only guess for known TLD-plausible single words (avoid noise)
        return nil
    }

    // Sorted longest-match-first isn't needed since we use .contains; keep it readable.
    private static let knownDomains: [(String, String)] = [
        // Streaming
        ("netflix", "netflix.com"),
        ("spotify", "spotify.com"),
        ("apple tv", "apple.com"),
        ("apple music", "apple.com"),
        ("apple arcade", "apple.com"),
        ("apple one", "apple.com"),
        ("apple icloud", "apple.com"),
        ("icloud", "apple.com"),
        ("disney+", "disneyplus.com"),
        ("disney plus", "disneyplus.com"),
        ("hulu", "hulu.com"),
        ("hbo max", "max.com"),
        ("max streaming", "max.com"),
        ("peacock", "peacocktv.com"),
        ("paramount+", "paramountplus.com"),
        ("paramount plus", "paramountplus.com"),
        ("youtube premium", "youtube.com"),
        ("youtube", "youtube.com"),
        ("amazon prime", "amazon.com"),
        ("amazon", "amazon.com"),
        ("crunchyroll", "crunchyroll.com"),
        ("twitch", "twitch.tv"),
        ("discovery+", "discoveryplus.com"),
        ("espn+", "espnplus.com"),
        ("dazn", "dazn.com"),
        ("mubi", "mubi.com"),
        ("criterion", "criterionchannel.com"),
        ("plex", "plex.tv"),
        ("tubi", "tubi.tv"),

        // Music / Podcasts
        ("tidal", "tidal.com"),
        ("pandora", "pandora.com"),
        ("audible", "audible.com"),
        ("sirius", "siriusxm.com"),
        ("deezer", "deezer.com"),

        // Food Delivery
        ("doordash", "doordash.com"),
        ("uber eats", "ubereats.com"),
        ("grubhub", "grubhub.com"),
        ("instacart", "instacart.com"),
        ("factor", "factormeals.com"),
        ("hello fresh", "hellofresh.com"),
        ("hellofresh", "hellofresh.com"),
        ("home chef", "homechef.com"),
        ("green chef", "greenchef.com"),
        ("every plate", "everyplate.com"),

        // Ride Share / Transport
        ("uber", "uber.com"),
        ("lyft", "lyft.com"),

        // Retail / Shopping
        ("walmart", "walmart.com"),
        ("target", "target.com"),
        ("costco", "costco.com"),
        ("whole foods", "wholefoods.com"),
        ("trader joe", "traderjoes.com"),
        ("kroger", "kroger.com"),
        ("safeway", "safeway.com"),
        ("aldi", "aldi.com"),
        ("sam's club", "samsclub.com"),
        ("bj's", "bjs.com"),

        // Coffee / Fast Food
        ("starbucks", "starbucks.com"),
        ("dunkin", "dunkindonuts.com"),
        ("mcdonald", "mcdonalds.com"),
        ("chick-fil-a", "chick-fil-a.com"),
        ("chickfila", "chick-fil-a.com"),
        ("chipotle", "chipotle.com"),
        ("panera", "panerabread.com"),
        ("subway", "subway.com"),
        ("domino", "dominos.com"),
        ("pizza hut", "pizzahut.com"),
        ("papa john", "papajohns.com"),
        ("taco bell", "tacobell.com"),
        ("burger king", "bk.com"),
        ("wendy", "wendys.com"),
        ("panda express", "pandaexpress.com"),
        ("five guys", "fiveguys.com"),
        ("shake shack", "shakeshack.com"),
        ("sweetgreen", "sweetgreen.com"),
        ("wingstop", "wingstop.com"),

        // Travel / Hotels
        ("airbnb", "airbnb.com"),
        ("vrbo", "vrbo.com"),
        ("delta", "delta.com"),
        ("united airlines", "united.com"),
        ("american airlines", "aa.com"),
        ("southwest", "southwest.com"),
        ("jetblue", "jetblue.com"),
        ("spirit", "spirit.com"),
        ("marriott", "marriott.com"),
        ("hilton", "hilton.com"),
        ("hyatt", "hyatt.com"),
        ("ihg", "ihg.com"),
        ("holiday inn", "ihg.com"),
        ("wyndham", "wyndham.com"),
        ("expedia", "expedia.com"),
        ("booking", "booking.com"),
        ("priceline", "priceline.com"),
        ("kayak", "kayak.com"),

        // Finance / Banking
        ("chase", "chase.com"),
        ("bank of america", "bankofamerica.com"),
        ("wells fargo", "wellsfargo.com"),
        ("citibank", "citibank.com"),
        ("capital one", "capitalone.com"),
        ("venmo", "venmo.com"),
        ("paypal", "paypal.com"),
        ("cashapp", "cash.app"),
        ("cash app", "cash.app"),
        ("zelle", "zellepay.com"),
        ("coinbase", "coinbase.com"),
        ("robinhood", "robinhood.com"),
        ("fidelity", "fidelity.com"),
        ("schwab", "schwab.com"),
        ("vanguard", "vanguard.com"),

        // Health / Pharmacy
        ("cvs", "cvs.com"),
        ("walgreens", "walgreens.com"),
        ("rite aid", "riteaid.com"),
        ("one medical", "onemedical.com"),
        ("teladoc", "teladoc.com"),
        ("calm", "calm.com"),
        ("headspace", "headspace.com"),
        ("noom", "noom.com"),
        ("weight watchers", "ww.com"),
        ("ww ", "ww.com"),

        // Fitness
        ("peloton", "onepeloton.com"),
        ("planet fitness", "planetfitness.com"),
        ("la fitness", "lafitness.com"),
        ("equinox", "equinox.com"),
        ("anytime fitness", "anytimefitness.com"),
        ("crunch fitness", "crunch.com"),
        ("ymca", "ymca.net"),
        ("crossfit", "crossfit.com"),
        ("beachbody", "beachbody.com"),

        // Telecom
        ("at&t", "att.com"),
        ("verizon", "verizon.com"),
        ("t-mobile", "t-mobile.com"),
        ("tmobile", "t-mobile.com"),
        ("comcast", "comcast.com"),
        ("xfinity", "xfinity.com"),
        ("spectrum", "spectrum.com"),
        ("cox", "cox.com"),
        ("dish", "dish.com"),
        ("directv", "directv.com"),

        // Insurance
        ("geico", "geico.com"),
        ("state farm", "statefarm.com"),
        ("progressive", "progressive.com"),
        ("allstate", "allstate.com"),
        ("usaa", "usaa.com"),
        ("liberty mutual", "libertymutual.com"),
        ("farmers", "farmers.com"),
        ("nationwide", "nationwide.com"),
        ("lemonade", "lemonade.com"),

        // Software / Tech
        ("microsoft", "microsoft.com"),
        ("microsoft 365", "microsoft.com"),
        ("office 365", "microsoft.com"),
        ("adobe", "adobe.com"),
        ("dropbox", "dropbox.com"),
        ("github", "github.com"),
        ("slack", "slack.com"),
        ("zoom", "zoom.us"),
        ("openai", "openai.com"),
        ("chatgpt", "openai.com"),
        ("notion", "notion.so"),
        ("figma", "figma.com"),
        ("canva", "canva.com"),
        ("grammarly", "grammarly.com"),
        ("1password", "1password.com"),
        ("lastpass", "lastpass.com"),
        ("nordvpn", "nordvpn.com"),
        ("expressvpn", "expressvpn.com"),
        ("google workspace", "google.com"),
        ("google one", "google.com"),
        ("google", "google.com"),

        // Home
        ("ring", "ring.com"),
        ("nest", "nest.com"),
        ("vivint", "vivint.com"),
        ("adt", "adt.com"),
        ("simplisafe", "simplisafe.com"),
        ("frontpoint", "frontpointsecurity.com"),

        // Pet
        ("chewy", "chewy.com"),
        ("petco", "petco.com"),
        ("petsmart", "petsmart.com"),
        ("rover", "rover.com"),
        ("wagwalking", "wagwalking.com"),
    ]
}
