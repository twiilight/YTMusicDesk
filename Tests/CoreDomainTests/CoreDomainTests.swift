import CoreDomain
import Foundation
import LyricsService
import Testing
import WebEnhancements

@Suite("NavigationPolicy")
struct NavigationPolicyTests {
    let policy = NavigationPolicy()

    @Test("Allows music.youtube.com in main view even on new window requests")
    func allowsPrimaryHostInMainView() {
        let normal = NavigationRequest(url: URL(string: "https://music.youtube.com/explore"))
        let newTab = NavigationRequest(
            url: URL(string: "https://music.youtube.com/watch?v=abc123"),
            isMainFrame: true,
            isNewWindowRequest: true
        )

        #expect(policy.decide(for: normal) == .allowInMainView)
        #expect(policy.decide(for: newTab) == .allowInMainView)
    }

    @Test("Routes Google Sign-In popups to dedicated auth popup while keeping in-frame redirects in-app")
    func routesGoogleAuthFlowsCorrectly() {
        let inFrameAuth = NavigationRequest(
            url: URL(string: "https://accounts.google.com/v3/signin/identifier"),
            isMainFrame: true,
            isNewWindowRequest: false
        )
        let popupAuth = NavigationRequest(
            url: URL(string: "https://accounts.google.co.jp/o/oauth2/auth"),
            isMainFrame: true,
            isNewWindowRequest: true
        )
        let blankPopup = NavigationRequest(
            url: URL(string: "about:blank"),
            isMainFrame: true,
            isNewWindowRequest: true
        )

        #expect(policy.decide(for: inFrameAuth) == .allowInMainView)
        #expect(policy.decide(for: popupAuth) == .openInAuthPopup)
        #expect(policy.decide(for: blankPopup) == .openInAuthPopup)
    }

    @Test("Allows YouTube account session bounces in-app while opening unrelated YouTube pages externally")
    func distinguishesYouTubeSessionFromGeneralLinks() {
        let signInBounce = NavigationRequest(
            url: URL(string: "https://www.youtube.com/signin?next=https%3A%2F%2Fmusic.youtube.com")
        )
        let channelSwitcher = NavigationRequest(
            url: URL(string: "https://www.youtube.com/channel_switcher")
        )
        let regularVideo = NavigationRequest(
            url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        )

        #expect(policy.decide(for: signInBounce) == .allowInMainView)
        #expect(policy.decide(for: channelSwitcher) == .allowInMainView)
        #expect(policy.decide(for: regularVideo) == .openInExternalBrowser)
    }

    @Test("Always permits subframes so embedded session checks stay intact")
    func permitsSubframes() {
        let iframe = NavigationRequest(
            url: URL(string: "https://accounts.google.com/RotateCookiesPage"),
            isMainFrame: false,
            isNewWindowRequest: false
        )
        #expect(policy.decide(for: iframe) == .allowInMainView)
    }

    @Test("Hands off third-party and non-HTTP URLs to the external macOS browser")
    func opensExternalLinksOutsideApp() {
        let support = NavigationRequest(url: URL(string: "https://support.google.com/youtubemusic"))
        let mailto = NavigationRequest(url: URL(string: "mailto:artist@example.com"))

        #expect(policy.decide(for: support) == .openInExternalBrowser)
        #expect(policy.decide(for: mailto) == .openInExternalBrowser)
    }
}

@Suite("WebPageState")
struct WebPageStateTests {
    @Test("Formats YouTube Music document titles cleanly for the integrated titlebar")
    func formatsDisplayTitle() {
        var state = WebPageState(rawTitle: "")
        #expect(state.displayTitle == "YTMusicDesk")

        state.rawTitle = "YouTube Music"
        #expect(state.displayTitle == "YTMusicDesk")

        state.rawTitle = "Bohemian Rhapsody - YouTube Music"
        #expect(state.displayTitle == "Bohemian Rhapsody")

        state.rawTitle = "  Nightcall - Kavinsky - YouTube Music  "
        #expect(state.displayTitle == "Nightcall - Kavinsky")
    }

    @Test("Hides launch splash once initial load finishes or when a load error occurs")
    func launchSplashVisibility() {
        var state = WebPageState()
        #expect(state.showsLaunchSplash == true)

        state.loadFailure = LoadFailure(title: "Offline", message: "No internet", failingURL: nil, isOffline: true)
        #expect(state.showsLaunchSplash == false)

        state.loadFailure = nil
        state.hasCompletedInitialLoad = true
        #expect(state.showsLaunchSplash == false)
    }
}

@Suite("EnhancementRegistry")
struct EnhancementRegistryTests {
    @Test("Compiles host-scoped CSS/JS enhancements cleanly and respects disabled IDs")
    func registryRespectsDisableOverridesAndHostScoping() {
        let full = EnhancementRegistry.defaultRegistry()
        #expect(full.activeEnhancements.count == 4)
        let injections = full.compiledInjections()
        #expect(injections.count == 4)
        #expect(injections.allSatisfy { $0.source.contains("music.youtube.com") })

        let filtered = EnhancementRegistry.defaultRegistry(
            disabledIDs: ["macos.viewport-ergonomics", "macos.hide-web-player-bar"]
        )
        #expect(filtered.activeEnhancements.count == 2)
        #expect(filtered.activeEnhancements.map(\.id) == ["macos.chrome-refinement", "macos.playback-bridge"])
    }
}

@Suite("PlaybackAndLyrics")
struct PlaybackAndLyricsTests {
    @Test("Interpolates live playback position only while playing and clamps to duration")
    func interpolatesPlaybackPosition() {
        let state = PlaybackState(
            track: TrackMetadata(title: "Nightcall", artist: "Kavinsky", duration: 258),
            isPlaying: true,
            currentTime: 100,
            duration: 258,
            sampledUptime: 500
        )

        #expect(state.interpolatedTime(at: 502.5) == 102.5)
        #expect(state.interpolatedTime(at: 900) == 258)

        var paused = state
        paused.isPlaying = false
        #expect(paused.interpolatedTime(at: 510) == 100)
    }

    @Test("Parses multi-timestamp, offset, and enhanced LRC lyrics cleanly")
    func parsesLRCFormats() {
        let raw = """
        [ti:Demo Track]
        [offset:500]
        [00:10.00][01:02.50]Repeated chorus line
        [00:05.250]<00:05.25>Opening <00:06.10>verse
        [00:15.00]
        """

        let lines = LRCParser.parseSynced(raw)
        #expect(lines.count == 3)
        #expect(lines[0].text == "Opening verse")
        #expect(abs(lines[0].startTime - 5.75) < 0.001)
        #expect(lines[1].text == "Repeated chorus line")
        #expect(abs(lines[1].startTime - 10.50) < 0.001)
        #expect(lines[2].text == "Repeated chorus line")
        #expect(abs(lines[2].startTime - 63.00) < 0.001)
    }

    @Test("Computes active lyric index accurately with binary search")
    func syncsActiveLyricIndex() {
        let lines = [
            LyricLine(id: 0, startTime: 5.0, text: "Line 1"),
            LyricLine(id: 1, startTime: 12.0, text: "Line 2"),
            LyricLine(id: 2, startTime: 24.5, text: "Line 3")
        ]

        #expect(LyricsSyncEngine.activeLineIndex(in: lines, at: 1.0, leadOffset: 0.2) == nil)
        #expect(LyricsSyncEngine.activeLineIndex(in: lines, at: 4.85, leadOffset: 0.2) == 0)
        #expect(LyricsSyncEngine.activeLineIndex(in: lines, at: 15.0, leadOffset: 0.2) == 1)
        #expect(LyricsSyncEngine.activeLineIndex(in: lines, at: 80.0, leadOffset: 0.2) == 2)
    }

    @Test("Normalizes YouTube Music noise suffixes for high lyrics match accuracy")
    func normalizesYouTubeTrackMetadata() {
        let track = TrackMetadata(
            title: "晴天 (Official Music Video) [HD]",
            artist: "周杰伦 - Topic",
            album: "叶惠美",
            duration: 269.4
        )
        let normalized = TrackQueryNormalizer.normalize(track)
        #expect(normalized.title == "晴天")
        #expect(normalized.artist == "周杰伦")
        #expect(normalized.duration == 269)

        let bylineTrack = TrackMetadata(
            title: "Blinding Lights (Official Audio) (feat. Guest)",
            artist: "The Weeknd • After Hours • 2020",
            duration: 200
        )
        let bylineNormalized = TrackQueryNormalizer.normalize(bylineTrack)
        #expect(bylineNormalized.title == "Blinding Lights")
        #expect(bylineNormalized.artist == "The Weeknd")
    }
}
