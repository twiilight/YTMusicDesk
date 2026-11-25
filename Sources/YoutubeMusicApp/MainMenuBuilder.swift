import AppKit
import CoreDomain
import DesignSystem

/// Receives menu bar commands so `MainMenuBuilder` remains decoupled from `AppDelegate`.
@MainActor
protocol MenuActionTarget: AnyObject {
    func performReload()
    func performGoBack()
    func performGoForward()
    func performGoHome()
    func performZoomIn()
    func performZoomOut()
    func performResetZoom()
    func performCopyCurrentURL()
    func performOpenInBrowser()
    func performToggleFullScreen()

    // Playback & Lyrics
    func performTogglePlayPause()
    func performPreviousTrack()
    func performNextTrack()
    func performToggleImmersiveLyrics()
    func performToggleFloatingLyrics()
    func performToggleFloatingLyricsLock()
    func performToggleLike()
    func performVolumeUp()
    func performVolumeDown()
    func performToggleMute()
}

/// Constructs an authentic native macOS menu bar with standard Edit shortcuts,
/// playback controls, lyrics view toggle, and restrained browser navigation shortcuts.
@MainActor
final class MainMenuBuilder: NSObject {
    private weak var actionTarget: (any MenuActionTarget)?
    private let appName: String

    init(appName: String, actionTarget: any MenuActionTarget) {
        self.appName = appName
        self.actionTarget = actionTarget
        super.init()
    }

    func buildMainMenu() -> NSMenu {
        let zh = LocalizedCopy.prefersChinese
        let mainMenu = NSMenu()

        mainMenu.addItem(makeAppMenuItem(zh: zh))
        mainMenu.addItem(makeEditMenuItem(zh: zh))
        mainMenu.addItem(makeViewMenuItem(zh: zh))
        mainMenu.addItem(makePlaybackMenuItem(zh: zh))
        mainMenu.addItem(makeNavigateMenuItem(zh: zh))
        mainMenu.addItem(makeWindowMenuItem(zh: zh))
        mainMenu.addItem(makeHelpMenuItem(zh: zh))

        return mainMenu
    }

    // MARK: - Menus

    private func makeAppMenuItem(zh: Bool) -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: appName)

        menu.addItem(
            withTitle: zh ? "关于 \(appName)" : "About \(appName)",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        menu.addItem(.separator())

        let servicesItem = NSMenuItem(title: zh ? "服务" : "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        menu.addItem(servicesItem)
        menu.addItem(.separator())

        menu.addItem(
            withTitle: zh ? "隐藏 \(appName)" : "Hide \(appName)",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )

        let hideOthers = menu.addItem(
            withTitle: zh ? "隐藏其他" : "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]

        menu.addItem(
            withTitle: zh ? "全部显示" : "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        menu.addItem(.separator())

        menu.addItem(
            withTitle: zh ? "退出 \(appName)" : "Quit \(appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        item.submenu = menu
        return item
    }

    private func makeEditMenuItem(zh: Bool) -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: zh ? "编辑" : "Edit")

        menu.addItem(withTitle: zh ? "撤销" : "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = menu.addItem(withTitle: zh ? "重做" : "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(withTitle: zh ? "剪切" : "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: zh ? "拷贝" : "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: zh ? "粘贴" : "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: zh ? "全选" : "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        item.submenu = menu
        return item
    }

    private func makeViewMenuItem(zh: Bool) -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: zh ? "显示" : "View")

        menu.addItem(
            makeActionItem(
                title: zh ? "歌词与沉浸播放器" : "Lyrics & Now Playing",
                action: #selector(handleToggleImmersiveLyrics),
                key: "l"
            )
        )
        menu.addItem(
            makeActionItem(
                title: zh ? "桌面浮动歌词" : "Floating Desktop Lyrics",
                action: #selector(handleToggleFloatingLyrics),
                key: "l",
                modifiers: [.command, .shift]
            )
        )
        menu.addItem(
            makeActionItem(
                title: zh ? "锁定 / 解锁浮动歌词穿透" : "Toggle Floating Lyrics Click-Through",
                action: #selector(handleToggleFloatingLyricsLock),
                key: "l",
                modifiers: [.command, .shift, .option]
            )
        )
        menu.addItem(.separator())
        menu.addItem(makeActionItem(title: zh ? "重新加载" : "Reload", action: #selector(handleReload), key: "r"))
        menu.addItem(.separator())
        menu.addItem(makeActionItem(title: zh ? "实际大小" : "Actual Size", action: #selector(handleResetZoom), key: "0"))
        menu.addItem(makeActionItem(title: zh ? "放大" : "Zoom In", action: #selector(handleZoomIn), key: "="))
        menu.addItem(makeActionItem(title: zh ? "缩小" : "Zoom Out", action: #selector(handleZoomOut), key: "-"))
        menu.addItem(.separator())

        let fullScreen = makeActionItem(
            title: zh ? "切换全屏" : "Toggle Full Screen",
            action: #selector(handleToggleFullScreen),
            key: "f",
            modifiers: [.command, .control]
        )
        menu.addItem(fullScreen)

        item.submenu = menu
        return item
    }

    private func makePlaybackMenuItem(zh: Bool) -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: zh ? "播放" : "Playback")

        menu.addItem(
            makeActionItem(
                title: zh ? "播放 / 暂停" : "Play / Pause",
                action: #selector(handleTogglePlayPause),
                key: "p",
                modifiers: [.command, .option]
            )
        )
        menu.addItem(
            makeActionItem(
                title: zh ? "上一首" : "Previous Track",
                action: #selector(handlePreviousTrack),
                key: String(UnicodeScalar(NSLeftArrowFunctionKey)!),
                modifiers: [.command, .option]
            )
        )
        menu.addItem(
            makeActionItem(
                title: zh ? "下一首" : "Next Track",
                action: #selector(handleNextTrack),
                key: String(UnicodeScalar(NSRightArrowFunctionKey)!),
                modifiers: [.command, .option]
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            makeActionItem(
                title: zh ? "喜欢当前歌曲" : "Like Current Track",
                action: #selector(handleToggleLike),
                key: "l",
                modifiers: [.command, .option]
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            makeActionItem(
                title: zh ? "增大音量" : "Volume Up",
                action: #selector(handleVolumeUp),
                key: String(UnicodeScalar(NSUpArrowFunctionKey)!),
                modifiers: [.command, .option]
            )
        )
        menu.addItem(
            makeActionItem(
                title: zh ? "减小音量" : "Volume Down",
                action: #selector(handleVolumeDown),
                key: String(UnicodeScalar(NSDownArrowFunctionKey)!),
                modifiers: [.command, .option]
            )
        )
        menu.addItem(
            makeActionItem(
                title: zh ? "静音" : "Mute",
                action: #selector(handleToggleMute),
                key: "m",
                modifiers: [.command, .option]
            )
        )

        item.submenu = menu
        return item
    }

    private func makeNavigateMenuItem(zh: Bool) -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: zh ? "导航" : "Navigate")

        menu.addItem(makeActionItem(title: zh ? "后退" : "Back", action: #selector(handleGoBack), key: "["))
        menu.addItem(makeActionItem(title: zh ? "前进" : "Forward", action: #selector(handleGoForward), key: "]"))
        menu.addItem(
            makeActionItem(
                title: zh ? "首页" : "Home",
                action: #selector(handleGoHome),
                key: "h",
                modifiers: [.command, .shift]
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            makeActionItem(
                title: zh ? "拷贝当前链接" : "Copy Current Link",
                action: #selector(handleCopyURL),
                key: "c",
                modifiers: [.command, .shift]
            )
        )

        item.submenu = menu
        return item
    }

    private func makeWindowMenuItem(zh: Bool) -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: zh ? "窗口" : "Window")

        menu.addItem(withTitle: zh ? "关闭窗口" : "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        menu.addItem(withTitle: zh ? "最小化" : "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: zh ? "缩放" : "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(
            withTitle: zh ? "前置全部窗口" : "Bring All to Front",
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )

        NSApp.windowsMenu = menu
        item.submenu = menu
        return item
    }

    private func makeHelpMenuItem(zh: Bool) -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: zh ? "帮助" : "Help")

        menu.addItem(
            makeActionItem(
                title: zh ? "在默认浏览器中打开当前页面" : "Open Current Page in Browser",
                action: #selector(handleOpenInBrowser),
                key: ""
            )
        )

        NSApp.helpMenu = menu
        item.submenu = menu
        return item
    }

    private func makeActionItem(
        title: String,
        action: Selector,
        key: String,
        modifiers: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        return item
    }

    // MARK: - Objective-C Action Dispatch

    @objc private func handleReload() { actionTarget?.performReload() }
    @objc private func handleGoBack() { actionTarget?.performGoBack() }
    @objc private func handleGoForward() { actionTarget?.performGoForward() }
    @objc private func handleGoHome() { actionTarget?.performGoHome() }
    @objc private func handleZoomIn() { actionTarget?.performZoomIn() }
    @objc private func handleZoomOut() { actionTarget?.performZoomOut() }
    @objc private func handleResetZoom() { actionTarget?.performResetZoom() }
    @objc private func handleCopyURL() { actionTarget?.performCopyCurrentURL() }
    @objc private func handleOpenInBrowser() { actionTarget?.performOpenInBrowser() }
    @objc private func handleToggleFullScreen() { actionTarget?.performToggleFullScreen() }

    @objc private func handleTogglePlayPause() { actionTarget?.performTogglePlayPause() }
    @objc private func handlePreviousTrack() { actionTarget?.performPreviousTrack() }
    @objc private func handleNextTrack() { actionTarget?.performNextTrack() }
    @objc private func handleToggleImmersiveLyrics() { actionTarget?.performToggleImmersiveLyrics() }
    @objc private func handleToggleFloatingLyrics() { actionTarget?.performToggleFloatingLyrics() }
    @objc private func handleToggleFloatingLyricsLock() { actionTarget?.performToggleFloatingLyricsLock() }
    @objc private func handleToggleLike() { actionTarget?.performToggleLike() }
    @objc private func handleVolumeUp() { actionTarget?.performVolumeUp() }
    @objc private func handleVolumeDown() { actionTarget?.performVolumeDown() }
    @objc private func handleToggleMute() { actionTarget?.performToggleMute() }
}
