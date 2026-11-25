import SwiftUI

/// Centralized aesthetic tokens ensuring visual coherence across native chrome,
/// frosted glass player bar, ambient immersive lyrics, launch surface, and recovery states.
public enum ThemeTokens {
    public enum Colors {
        /// Matches YouTube Music's `#030303` obsidian canvas for seamless titlebar fusion.
        public static let canvasObsidian = Color(red: 3.0 / 255.0, green: 3.0 / 255.0, blue: 3.0 / 255.0)
        public static let elevatedSurface = Color(red: 18.0 / 255.0, green: 18.0 / 255.0, blue: 22.0 / 255.0)
        public static let playerBarBase = Color(red: 12.0 / 255.0, green: 12.0 / 255.0, blue: 15.0 / 255.0)

        public static let hairlineStroke = Color.white.opacity(0.075)
        public static let glassHighlight = Color.white.opacity(0.12)
        public static let chromeControlRest = Color.white.opacity(0.48)
        public static let chromeControlHover = Color.white.opacity(0.94)
        public static let chromeControlDisabled = Color.white.opacity(0.18)
        public static let chromeHoverPlate = Color.white.opacity(0.09)

        public static let titleMuted = Color.white.opacity(0.56)
        public static let titlePrimary = Color.white.opacity(0.94)
        public static let bodySecondary = Color.white.opacity(0.58)

        public static let accentCrimson = Color(red: 1.0, green: 0.14, blue: 0.27)
        public static let accentVermilion = Color(red: 1.0, green: 0.34, blue: 0.38)
    }

    public enum Metrics {
        public static let titlebarHeight: CGFloat = 38
        public static let playerBarHeight: CGFloat = 76
        public static let trafficLightsLeadingInset: CGFloat = 78
        public static let fullScreenLeadingInset: CGFloat = 14
        public static let chromeButtonWidth: CGFloat = 26
        public static let chromeButtonHeight: CGFloat = 24
        public static let chromeCornerRadius: CGFloat = 6
    }

    public enum Motion {
        public static let chromeHover = Animation.easeOut(duration: 0.15)
        public static let progressSmooth = Animation.easeOut(duration: 0.22)
        public static let splashFadeOut = Animation.easeOut(duration: 0.42)
        public static let paletteBlend = Animation.easeInOut(duration: 1.05)
        public static let immersiveToggle = Animation.spring(response: 0.42, dampingFraction: 0.88)
        public static let artworkPulse = Animation.spring(response: 0.48, dampingFraction: 0.78)
        public static let lyricScroll = Animation.spring(response: 0.56, dampingFraction: 0.86)
    }
}

/// Lightweight locale helper so native chrome, player controls, and lyrics states
/// adapt gracefully to Simplified Chinese or English macOS.
public enum LocalizedCopy {
    public static var prefersChinese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
    }

    public static var backTooltip: String { prefersChinese ? "后退 (⌘[)" : "Back (⌘[)" }
    public static var forwardTooltip: String { prefersChinese ? "前进 (⌘])" : "Forward (⌘])" }
    public static var reloadTooltip: String { prefersChinese ? "重新加载 (⌘R)" : "Reload (⌘R)" }
    public static var resetZoomTooltip: String { prefersChinese ? "恢复默认缩放 (⌘0)" : "Reset Zoom (⌘0)" }
    public static var retryButton: String { prefersChinese ? "重试" : "Retry" }
    public static var openInBrowserButton: String { prefersChinese ? "在浏览器中打开" : "Open in Browser" }

    // Player & Lyrics
    public static var idleTrackPlaceholder: String { prefersChinese ? "选择一首歌曲开始聆听" : "Choose a song to start playing" }
    public static var playTooltip: String { prefersChinese ? "播放 / 暂停 (⌥⌘P)" : "Play / Pause (⌥⌘P)" }
    public static var previousTooltip: String { prefersChinese ? "上一首 (⌥⌘←)" : "Previous (⌥⌘←)" }
    public static var nextTooltip: String { prefersChinese ? "下一首 (⌥⌘→)" : "Next (⌥⌘→)" }
    public static var shuffleTooltip: String { prefersChinese ? "随机播放" : "Shuffle" }
    public static var repeatTooltip: String { prefersChinese ? "循环模式" : "Repeat" }
    public static var likeTooltip: String { prefersChinese ? "喜欢" : "Like" }
    public static var muteTooltip: String { prefersChinese ? "静音" : "Mute" }
    public static var lyricsTooltip: String { prefersChinese ? "歌词与沉浸播放器 (⌘L)" : "Lyrics & Now Playing (⌘L)" }
    public static var collapseNowPlayingTooltip: String { prefersChinese ? "收起正在播放 (Esc)" : "Close Now Playing (Esc)" }
    public static var lyricsUnavailableTitle: String { prefersChinese ? "暂未找到该曲目的歌词" : "Lyrics Unavailable" }
    public static var lyricsUnavailableSubtitle: String { prefersChinese ? "部分纯音乐、现场版或小众曲目可能暂无时间轴歌词" : "Synced lyrics aren't available for this track yet." }
    public static var lyricsInstrumentalTitle: String { prefersChinese ? "纯音乐，请静心欣赏" : "Instrumental" }
    public static var plainLyricsBadge: String { prefersChinese ? "静态歌词 · 暂不支持逐行滚动" : "Plain lyrics · Time-sync unavailable" }
    public static var retryLyricsButton: String { prefersChinese ? "重新匹配歌词" : "Retry Lyrics" }

    // Floating Desktop Lyrics
    public static var floatingLyricsTooltip: String { prefersChinese ? "桌面浮动歌词 (⇧⌘L)" : "Floating Desktop Lyrics (⇧⌘L)" }
    public static var floatingFontSmallerTooltip: String { prefersChinese ? "减小歌词字号" : "Smaller Lyrics Font" }
    public static var floatingFontLargerTooltip: String { prefersChinese ? "增大歌词字号" : "Larger Lyrics Font" }
    public static var floatingLockTooltip: String { prefersChinese ? "锁定鼠标穿透（按 ⇧⌥⌘L 解锁）" : "Lock Click-Through (Press ⇧⌥⌘L to Unlock)" }
    public static var floatingCloseTooltip: String { prefersChinese ? "关闭浮动歌词 (⇧⌘L)" : "Close Floating Lyrics (⇧⌘L)" }
}
