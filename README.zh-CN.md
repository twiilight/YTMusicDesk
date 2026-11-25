<div align="center">
  <img src="assets/app-icon.png" width="96" height="96" alt="YTMusicDesk Icon" />

  <h1>YTMusicDesk</h1>

  <p>
    一款轻量、原生的 unofficial YouTube Music macOS 桌面客户端。
  </p>

  <p>
    <strong>macOS 14+</strong> &nbsp;·&nbsp;
    <strong>Swift 6 &amp; SwiftUI</strong> &nbsp;·&nbsp;
    <strong>Native WebKit</strong> &nbsp;·&nbsp;
    <strong>~3 MB</strong>
  </p>

  <p>
    <a href="README.md">English</a> &nbsp;|&nbsp; <strong>简体中文</strong>
  </p>
</div>

<br />

<p align="center">
  <img src="assets/preview-playlist.png" alt="Example Playlist & Native Frosted Player Bar" width="100%" />
</p>

<p align="center">
  <img src="assets/preview-lyrics.png" alt="Immersive Now Playing & Synced Scrolling Lyrics" width="100%" />
</p>

## 安装使用

### 直接下载安装包（推荐）

前往 **Releases** 下载最新版 `.dmg`（通用架构，支持 Apple Silicon 与 Intel，需 **macOS 14.0+**），打开后将 **YTMusicDesk.app** 拖入 **Applications** 即可。

> 由于项目采用本地 ad-hoc 签名（未公证），首次打开如遇 macOS 提示“无法验证开发者”或“已损坏”，在终端执行一次以下命令即可：
>
> ```bash
> xattr -cr "/Applications/YTMusicDesk.app"
> ```

### 从源码构建

环境要求：**macOS 14.0+** 与 **Swift 6+**（安装 Xcode 或 Command Line Tools 均可）。

```bash
# 构建并安装到「应用程序」（自动出现在启动台与聚焦搜索）
make install

# 打包通用架构 .dmg 与 .zip 发布包到 dist/
make dmg
```

## 快捷键

| 快捷键 | 功能 |
| :--- | :--- |
| `⌘L` / `Esc` | 展开 / 收起沉浸式歌词播放器 |
| `⌥⌘P` | 播放 / 暂停 |
| `⌥⌘←` / `⌥⌘→` | 上一首 / 下一首 |
| `⌥⌘↑` / `⌥⌘↓` / `⌥⌘M` | 增大 / 减小音量 / 静音 |
| `⌥⌘L` | 喜欢当前曲目 |
| `⌘[` / `⌘]` / `⌘R` | 后退 / 前进 / 刷新 |
| `⌘W` / `⌘Q` | 隐藏窗口（后台继续播放） / 彻底退出 |

---

<p align="center">
  <sub>基于 <a href="LICENSE">MIT</a> 协议开源的非官方桌面客户端。音乐内容与账号体系均直接由官方 YouTube Music 网页提供，时间轴歌词由 <a href="https://lrclib.net">LRCLIB</a> 提供支持。</sub>
</p>
