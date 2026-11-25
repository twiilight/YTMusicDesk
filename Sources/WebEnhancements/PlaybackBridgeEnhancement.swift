import CoreDomain

/// Bidirectional playback bridge between YouTube Music's web player and the native macOS SwiftUI player.
/// Observes `<video>`, `navigator.mediaSession`, and `ytmusic-player-bar` state, pushing compact JSON
/// snapshots through `WKScriptMessageHandler` and exposing `window.__ytmDesktop.dispatch(action, payload)`.
public struct PlaybackBridgeEnhancement: WebEnhancement {
    public let id = "macos.playback-bridge"
    public let displayName = "Native Playback Bridge"

    public init() {}

    public func scriptInjections() -> [WebScriptInjection] {
        [
            WebScriptInjection(
                source: Self.bridgeScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        ]
    }

    private static let bridgeScript: String = {
        let handlerName = WebBridgeContract.messageHandlerName
        let namespace = WebBridgeContract.jsNamespace

        return """
        (function() {
          const host = (window.location && window.location.hostname || '').toLowerCase();
          if (host !== 'music.youtube.com') { return; }
          if (window.\(namespace) && window.\(namespace).__initialized) { return; }

          const HANDLER = '\(handlerName)';
          let attachedVideo = null;
          let attachedBar = null;
          let barObserver = null;
          let lastSignature = '';
          let lastTimePushMs = 0;

          function postMessage(payload) {
            try {
              const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[HANDLER];
              if (handler) {
                handler.postMessage(payload);
              }
            } catch (_) {}
          }

          function getVideo() {
            return document.querySelector('video.html5-main-video') || document.querySelector('video');
          }

          function getPlayerBar() {
            return document.querySelector('ytmusic-player-bar');
          }

          function getPlayerApi() {
            const player = document.querySelector('ytmusic-player');
            if (player && player.playerApi) { return player.playerApi; }
            const moviePlayer = document.getElementById('movie_player');
            if (moviePlayer && typeof moviePlayer.getCurrentTime === 'function') { return moviePlayer; }
            return null;
          }

          function upgradeArtworkURL(raw) {
            if (!raw || typeof raw !== 'string') { return null; }
            if (raw.includes('googleusercontent.com')) {
              return raw
                .replace(/=w\\d+-h\\d+[^&]*/i, '=w900-h900-l90-rj')
                .replace(/=s\\d+[^&]*/i, '=s900');
            }
            return raw;
          }

          function pickBestArtwork(mediaMeta, bar) {
            if (mediaMeta && Array.isArray(mediaMeta.artwork) && mediaMeta.artwork.length > 0) {
              let best = mediaMeta.artwork[mediaMeta.artwork.length - 1];
              let bestArea = 0;
              for (const item of mediaMeta.artwork) {
                if (!item || !item.src) { continue; }
                const parts = (item.sizes || '').toLowerCase().split('x');
                const area = parts.length === 2 ? (parseInt(parts[0], 10) || 0) * (parseInt(parts[1], 10) || 0) : 0;
                if (area >= bestArea) {
                  bestArea = area;
                  best = item;
                }
              }
              if (best && best.src) {
                return upgradeArtworkURL(best.src);
              }
            }
            const img = bar && bar.querySelector('img.image.ytmusic-player-bar');
            if (img && img.src && !img.src.startsWith('data:image/gif')) {
              return upgradeArtworkURL(img.src);
            }
            return null;
          }

          function readMetadata(bar) {
            const mediaMeta = (navigator.mediaSession && navigator.mediaSession.metadata) || null;
            let title = '';
            let artist = '';
            let album = '';

            // 1. Prefer live `ytmusic-player-bar` DOM first (updates synchronously with track switches;
            //    `navigator.mediaSession.metadata` can briefly lag behind in WebKit).
            if (bar) {
              const titleEl = bar.querySelector('.title.ytmusic-player-bar');
              if (titleEl && titleEl.textContent) {
                title = titleEl.textContent.trim();
              }
              const bylineEl = bar.querySelector('.byline.ytmusic-player-bar');
              if (bylineEl && bylineEl.textContent) {
                const rawByline = bylineEl.textContent.trim();
                const segments = rawByline.split('•').map(s => s.trim()).filter(Boolean);
                if (segments.length > 0) { artist = segments[0]; }
                if (segments.length > 1 && !/^\\d{4}$/.test(segments[1])) {
                  album = segments[1];
                }
              }
            }

            // 2. Fallback to MediaSession metadata (and fill album if DOM omitted it)
            if (!title && mediaMeta && mediaMeta.title) {
              title = String(mediaMeta.title).trim();
            }
            if (!artist && mediaMeta && mediaMeta.artist) {
              artist = String(mediaMeta.artist).trim();
            }
            if (!album && mediaMeta && mediaMeta.album) {
              album = String(mediaMeta.album).trim();
            }

            let videoID = null;
            try {
              const api = getPlayerApi();
              if (api && typeof api.getVideoData === 'function') {
                const vd = api.getVideoData();
                if (vd && vd.video_id) { videoID = String(vd.video_id); }
                if (!title && vd && vd.title) { title = String(vd.title).trim(); }
                if (!artist && vd && vd.author) { artist = String(vd.author).trim(); }
              }
            } catch (_) {}

            if (!videoID) {
              try {
                const urlParam = new URL(window.location.href).searchParams.get('v');
                if (urlParam) { videoID = urlParam; }
              } catch (_) {}
            }

            // Prefer bar artwork when available (stays locked to the active bar title), fallback to MediaSession.
            let artworkURL = null;
            const img = bar && bar.querySelector('img.image.ytmusic-player-bar');
            if (img && img.src && !img.src.startsWith('data:image/gif')) {
              artworkURL = upgradeArtworkURL(img.src);
            }
            if (!artworkURL) {
              artworkURL = pickBestArtwork(mediaMeta, bar);
            }

            return { title, artist, album, artworkURL, videoID };
          }

          function isButtonEnabled(selector, bar) {
            if (!bar) { return false; }
            const el = bar.querySelector(selector);
            if (!el) { return false; }
            const inner = el.querySelector('button') || el;
            if (inner.disabled) { return false; }
            if (el.hasAttribute('disabled') || inner.getAttribute('aria-disabled') === 'true') { return false; }
            return true;
          }

          function readLikeStatus(bar) {
            if (!bar) { return 'indifferent'; }
            const renderer = bar.querySelector('ytmusic-like-button-renderer');
            if (!renderer) { return 'indifferent'; }
            const attr = (renderer.getAttribute('like-status') || '').toUpperCase();
            if (attr === 'LIKE') { return 'like'; }
            if (attr === 'DISLIKE') { return 'dislike'; }
            const likeBtn = renderer.querySelector('.like button, .like');
            if (likeBtn && likeBtn.getAttribute('aria-pressed') === 'true') { return 'like'; }
            return 'indifferent';
          }

          function readRepeatMode(bar) {
            if (!bar) { return 'off'; }
            const modeProp = String(bar.repeatMode_ || bar.getAttribute('repeat-mode_') || '').toUpperCase();
            if (modeProp === 'ONE') { return 'one'; }
            if (modeProp === 'ALL') { return 'all'; }
            const repeatBtn = bar.querySelector('.repeat button, .repeat');
            const label = (repeatBtn && (repeatBtn.getAttribute('aria-label') || repeatBtn.getAttribute('title')) || '').toLowerCase();
            if (label.includes('one') || label.includes('单曲')) { return 'one'; }
            if (label.includes('all') || label.includes('列表') || label.includes('全部')) { return 'all'; }
            return 'off';
          }

          function readShuffleState(bar) {
            if (!bar) { return false; }
            const el = bar.querySelector('.shuffle');
            if (!el) { return false; }
            const inner = el.querySelector('button') || el;
            return inner.getAttribute('aria-pressed') === 'true' || el.getAttribute('aria-pressed') === 'true';
          }

          function readPageLyricsFallback() {
            const desc = document.querySelector('ytmusic-description-shelf-renderer .non-expandable.description');
            // Only read page lyrics when the Lyrics tab is visibly mounted (avoid stale hidden DOM from prior track)
            if (desc && desc.offsetParent !== null && desc.textContent) {
              const text = desc.textContent.trim();
              if (text.length > 20) { return text; }
            }
            return null;
          }

          function collectState() {
            const video = getVideo();
            const bar = getPlayerBar();
            const api = getPlayerApi();
            const meta = readMetadata(bar);

            let currentTime = 0;
            let duration = 0;
            let isPlaying = false;
            let volume = 1.0;
            let isMuted = false;

            if (video) {
              currentTime = Number.isFinite(video.currentTime) ? video.currentTime : 0;
              duration = Number.isFinite(video.duration) ? video.duration : 0;
              isPlaying = !video.paused && !video.ended && video.readyState > 1;
              volume = Number.isFinite(video.volume) ? video.volume : 1.0;
              isMuted = Boolean(video.muted);
            }

            if (api) {
              try {
                if (duration <= 0 && typeof api.getDuration === 'function') {
                  const d = api.getDuration();
                  if (Number.isFinite(d) && d > 0) { duration = d; }
                }
                if (typeof api.getVolume === 'function') {
                  const v = api.getVolume();
                  if (Number.isFinite(v)) { volume = Math.max(0, Math.min(1, v / 100)); }
                }
                if (typeof api.isMuted === 'function') {
                  isMuted = Boolean(api.isMuted());
                }
              } catch (_) {}
            }

            return {
              type: 'playbackState',
              title: meta.title,
              artist: meta.artist,
              album: meta.album,
              artworkURL: meta.artworkURL,
              videoID: meta.videoID,
              isPlaying,
              currentTime,
              duration,
              volume,
              isMuted,
              isShuffled: readShuffleState(bar),
              repeatMode: readRepeatMode(bar),
              likeStatus: readLikeStatus(bar),
              hasPrevious: isButtonEnabled('.previous-button', bar),
              hasNext: isButtonEnabled('.next-button', bar),
              pageLyricsText: readPageLyricsFallback()
            };
          }

          function emitState(force) {
            const state = collectState();
            const now = Date.now();
            const sig = [
              state.videoID || '',
              state.title,
              state.artist,
              state.artworkURL || '',
              state.isPlaying ? '1' : '0',
              Math.round(state.duration),
              Math.round(state.volume * 100),
              state.isMuted ? '1' : '0',
              state.isShuffled ? '1' : '0',
              state.repeatMode,
              state.likeStatus,
              state.hasPrevious ? '1' : '0',
              state.hasNext ? '1' : '0'
            ].join('|');

            const timeDue = state.isPlaying && (now - lastTimePushMs >= 350);
            if (!force && sig === lastSignature && !timeDue) {
              return;
            }
            lastSignature = sig;
            lastTimePushMs = now;
            postMessage(state);
          }

          function ensureObservers() {
            const video = getVideo();
            if (video && video !== attachedVideo) {
              attachedVideo = video;
              ['play', 'pause', 'ended', 'seeking', 'seeked', 'loadedmetadata', 'durationchange', 'volumechange'].forEach(evt => {
                video.addEventListener(evt, () => emitState(true), { passive: true });
              });
              video.addEventListener('timeupdate', () => emitState(false), { passive: true });
              emitState(true);
            }

            const bar = getPlayerBar();
            if (bar && bar !== attachedBar) {
              attachedBar = bar;
              if (barObserver) { barObserver.disconnect(); }
              let pending = null;
              barObserver = new MutationObserver(() => {
                if (pending) { return; }
                pending = setTimeout(() => {
                  pending = null;
                  emitState(true);
                }, 80);
              });
              barObserver.observe(bar, {
                subtree: true,
                childList: true,
                characterData: true,
                attributes: true,
                attributeFilter: ['like-status', 'aria-pressed', 'aria-label', 'disabled', 'aria-disabled', 'repeat-mode_', 'src']
              });
              emitState(true);
            }
          }

          function clickControl(selector) {
            const bar = getPlayerBar();
            if (!bar) { return false; }
            const el = bar.querySelector(selector);
            if (!el) { return false; }
            const target = el.querySelector('button') || el;
            target.click();
            return true;
          }

          function dispatch(action, payload) {
            const video = getVideo();
            const api = getPlayerApi();

            switch (action) {
              case 'togglePlayPause':
                if (!clickControl('#play-pause-button') && video) {
                  if (video.paused) { video.play().catch(() => {}); }
                  else { video.pause(); }
                }
                break;

              case 'nextTrack':
                clickControl('.next-button');
                break;

              case 'previousTrack':
                clickControl('.previous-button');
                break;

              case 'seek': {
                const seconds = Number(payload);
                if (Number.isFinite(seconds) && seconds >= 0) {
                  if (api && typeof api.seekTo === 'function') {
                    api.seekTo(seconds, true);
                  } else if (video) {
                    video.currentTime = seconds;
                  }
                }
                break;
              }

              case 'setVolume': {
                const vol = Math.max(0, Math.min(1, Number(payload)));
                if (Number.isFinite(vol)) {
                  if (api && typeof api.setVolume === 'function') {
                    api.setVolume(Math.round(vol * 100));
                    if (vol > 0 && typeof api.isMuted === 'function' && api.isMuted() && typeof api.unMute === 'function') {
                      api.unMute();
                    }
                  }
                  if (video) {
                    video.volume = vol;
                    if (vol > 0 && video.muted) { video.muted = false; }
                  }
                }
                break;
              }

              case 'toggleMute':
                if (!clickControl('.volume')) {
                  if (api && typeof api.isMuted === 'function') {
                    if (api.isMuted()) { api.unMute && api.unMute(); }
                    else { api.mute && api.mute(); }
                  } else if (video) {
                    video.muted = !video.muted;
                  }
                }
                break;

              case 'toggleLike':
                clickControl('ytmusic-like-button-renderer .like');
                break;

              case 'toggleShuffle':
                clickControl('.shuffle');
                break;

              case 'cycleRepeat':
                clickControl('.repeat');
                break;
            }

            setTimeout(() => emitState(true), 60);
            setTimeout(() => emitState(true), 240);
          }

          window.\(namespace) = {
            __initialized: true,
            dispatch,
            syncNow: () => emitState(true)
          };

          ensureObservers();
          setInterval(() => {
            ensureObservers();
            emitState(false);
          }, 900);
        })();
        """
    }()
}
