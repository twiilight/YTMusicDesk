import CoreDomain
import Foundation
import LyricsService
import Testing
import WebEngine
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

    @Test("Clamps floating lyrics font size preferences within bounds")
    func clampsFloatingLyricsFontSize() {
        var prefs = FloatingLyricsPreferences(fontSize: 24)
        for _ in 0..<20 { prefs.increaseFontSize() }
        #expect(prefs.fontSize == FloatingLyricsPreferences.maxFontSize)

        for _ in 0..<20 { prefs.decreaseFontSize() }
        #expect(prefs.fontSize == FloatingLyricsPreferences.minFontSize)
    }

    @Test("Resolves floating desktop lyric line across synced, intro, instrumental, and idle states")
    func resolvesFloatingDesktopLyricLine() {
        let idle = FloatingLyricsDisplayResolver.resolve(
            playbackState: PlaybackState(),
            lyricsState: .idle,
            at: 0
        )
        #expect(idle.text == "YTMusicDesk")
        #expect(idle.isActiveLyric == false)

        let track = TrackMetadata(title: "Neon Horizon", artist: "Solaris Drive", duration: 234)
        let playback = PlaybackState(track: track, isPlaying: true, currentTime: 20, duration: 234)
        let syncedDoc = LyricsDocument(
            source: "LRCLIB",
            content: .synced([
                LyricLine(id: 0, startTime: 10, text: "First lyric"),
                LyricLine(id: 1, startTime: 18, text: "Second lyric")
            ])
        )

        let intro = FloatingLyricsDisplayResolver.resolve(
            playbackState: playback,
            lyricsState: .loaded(syncedDoc),
            at: 3.0
        )
        #expect(intro.text == "♪ Neon Horizon — Solaris Drive")
        #expect(intro.isActiveLyric == false)

        let active = FloatingLyricsDisplayResolver.resolve(
            playbackState: playback,
            lyricsState: .loaded(syncedDoc),
            at: 19.0
        )
        #expect(active.text == "Second lyric")
        #expect(active.isActiveLyric == true)

        let instrumental = FloatingLyricsDisplayResolver.resolve(
            playbackState: playback,
            lyricsState: .loaded(LyricsDocument(source: "LRCLIB", content: .instrumental)),
            at: 19.0,
            prefersChinese: true
        )
        #expect(instrumental.text == "♪ Neon Horizon · 纯音乐")
        #expect(instrumental.isActiveLyric == false)
    }

    @Test("Rejects unrelated songs even when they have synced lyrics")
    func rejectsWrongSongMatches() {
        let track = TrackMetadata(
            title: "Christmas Song",
            artist: "back number",
            duration: 340
        )
        let query = TrackQueryNormalizer.normalize(track)

        let unrelatedSynced = LRCLIBRecord(
            trackName: "Angel in the Snow",
            artistName: "Different Artist",
            duration: 210,
            syncedLyrics: "[00:11.09]There's an angel in the snow"
        )
        let sameTitleDifferentSong = LRCLIBRecord(
            trackName: "Christmas Song",
            artistName: "Nat King Cole",
            duration: 192,
            syncedLyrics: "[00:10.00]Chestnuts roasting on an open fire"
        )

        #expect(LRCLIBCandidateMatcher.selectBest(from: [unrelatedSynced, sameTitleDifferentSong], for: query) == nil)
    }

    @Test("Accepts localized artist name only when title is exact and duration matches closely")
    func acceptsLocalizedArtistWithExactTitleAndDuration() {
        let track = TrackMetadata(title: "晴天", artist: "周杰伦", duration: 269)
        let query = TrackQueryNormalizer.normalize(track)

        let localizedMatch = LRCLIBRecord(
            trackName: "晴天",
            artistName: "Jay Chou",
            duration: 270,
            syncedLyrics: "[00:28.00]故事的小黄花"
        )
        let wrongDuration = LRCLIBRecord(
            trackName: "晴天",
            artistName: "Other Singer",
            duration: 240,
            syncedLyrics: "[00:10.00]Wrong song"
        )

        let selected = LRCLIBCandidateMatcher.selectBest(from: [wrongDuration, localizedMatch], for: query)
        #expect(selected == localizedMatch)
    }

    @Test("Track identityKey changes when title or artist settles for the same videoID")
    func identityKeyReflectsMetadataSettlement() {
        let stale = TrackMetadata(title: "Old Song", artist: "Old Artist", videoID: "newVid123")
        let settled = TrackMetadata(title: "New Song", artist: "New Artist", videoID: "newVid123")
        #expect(stale.identityKey != settled.identityKey)
    }
}

@Suite("PlaybackBridgeCodec")
struct PlaybackBridgeCodecTests {
    @Test("Does not carry over previous track duration or artwork when switching to a new track")
    func preventsStaleCarryoverAcrossTracks() {
        let prevTrack = TrackMetadata(
            title: "Song A",
            artist: "Artist A",
            artworkURL: URL(string: "https://example.com/a.jpg"),
            videoID: "vidA",
            duration: 240
        )
        let prevState = PlaybackState(track: prevTrack, isPlaying: true, currentTime: 80, duration: 240)

        let payload: [String: Any] = [
            "type": "playbackState",
            "title": "Song B",
            "artist": "Artist B",
            "videoID": "vidB",
            "isPlaying": true,
            "currentTime": 0.0,
            "duration": 0.0
        ]

        let decoded = PlaybackBridgeCodec.decodePlaybackState(from: payload, previous: prevState, sampledUptime: 100)
        #expect(decoded?.track?.title == "Song B")
        #expect(decoded?.track?.duration == 0)
        #expect(decoded?.track?.artworkURL == nil)
    }

    @Test("Encodes seek and volume commands with clamped optimistic state")
    func encodesClampedCommands() {
        let state = PlaybackState(
            track: TrackMetadata(title: "Demo", artist: "Artist", duration: 180),
            isPlaying: true,
            currentTime: 30,
            duration: 180,
            volume: 0.5,
            isMuted: true
        )

        let seek = PlaybackBridgeCodec.encode(command: .seek(999), currentState: state, sampledUptime: 42)
        #expect(seek.optimisticState.currentTime == 180)
        #expect(seek.javascript.contains("dispatch('seek', 180.0)"))

        let vol = PlaybackBridgeCodec.encode(command: .setVolume(1.5), currentState: state, sampledUptime: 42)
        #expect(vol.optimisticState.volume == 1.0)
        #expect(vol.optimisticState.isMuted == false)
    }
}
