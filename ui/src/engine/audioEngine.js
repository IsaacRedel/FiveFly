/**
 * Persistent audio engine (hidden). Plays the player's own track and the speakers/vehicles of nearby
 * players, driven by `{ target: "audio-engine" }` messages from client/audio_engine.lua.
 */
const resourceName = typeof GetParentResourceName === "function" ? GetParentResourceName() : "fivefy";
const FADE_DURATION_MS = 220;
const FADE_STEP_MS = 35;

let player = null;
let playerReady = false;
let pendingTrack = null;
let volume = 100;
let externalVolume = 100;
let masterVolume = 100;
let muted = false;
let externalMuted = false;
let fadeTimer = null;
let appliedVolume = 100;
let progressTimer = null;
let streamAudio = null;
const streamEntry = {
  fadeTimer: null,
  appliedVolume: 0,
};
const externalPlayers = {};
const pendingExternalSources = {};
const externalSourceVersions = {};

function postNui(action, payload = {}) {
  return fetch(`https://${resourceName}/${action}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json; charset=UTF-8",
    },
    body: JSON.stringify(payload),
  }).catch(() => null);
}

function getYouTubeEmbedOrigin() {
  try {
    if (window.location.origin && window.location.origin !== "null") {
      return window.location.origin;
    }

    const host = window.location.host || `cfx-nui-${resourceName}`;
    return `https://${host}`;
  } catch (_) {
    return `https://cfx-nui-${resourceName}`;
  }
}

function getTrackVideoId(track) {
  if (!track || typeof track !== "object") return "";
  return String(track.videoId || track.id || "").trim();
}

function getTrackStreamUrl(track) {
  if (!track || typeof track !== "object") return "";
  const url = String(track.streamUrl || track.url || "").trim();
  return /^https?:\/\//i.test(url) ? url : "";
}

function getTrackKey(track) {
  return getTrackStreamUrl(track) || getTrackVideoId(track);
}

function bumpExternalVersion(sourceId) {
  const safeSourceId = String(sourceId || "");
  externalSourceVersions[safeSourceId] = (externalSourceVersions[safeSourceId] || 0) + 1;
  return externalSourceVersions[safeSourceId];
}

function getExternalVersion(sourceId) {
  return externalSourceVersions[String(sourceId || "")] || 0;
}

function normalizeVolume(value) {
  return Math.max(0, Math.min(100, Math.round(Number(value) || 0)));
}

function applyMasterVolume(value) {
  return normalizeVolume((normalizeVolume(value) * masterVolume) / 100);
}

function getSourcePlaybackPosition(source = {}) {
  const playback = source.playback || {};
  const position = Math.max(0, Number(playback.position) || 0);

  if (source.status === "online" && Number(playback.startedAt) > 0) {
    return position + Math.max(0, (Date.now() / 1000) - Number(playback.startedAt));
  }

  return position;
}

function isSourcePaused(source = {}) {
  return source.status === "paused";
}

function syncExternalTransport(entry, source = {}) {
  if (!entry?.player) return;

  if (isSourcePaused(source)) {
    if (typeof entry.player.pauseVideo === "function") {
      entry.player.pauseVideo();
    } else if (typeof entry.player.pause === "function") {
      entry.player.pause();
    }
    return;
  }

  if (typeof entry.player.playVideo === "function") {
    entry.player.playVideo();
  } else if (typeof entry.player.play === "function") {
    entry.player.play().catch(() => null);
  }
}

function syncExternalPosition(entry, source = {}) {
  if (!entry?.player) return;

  const position = getSourcePlaybackPosition(source);

  if (typeof entry.player.getCurrentTime === "function" && typeof entry.player.seekTo === "function") {
    const currentTime = Number(entry.player.getCurrentTime()) || 0;

    if (Math.abs(currentTime - position) > 1.5) {
      entry.player.seekTo(position, true);
    }
    return;
  }

  if ("currentTime" in entry.player) {
    const currentTime = Number(entry.player.currentTime) || 0;

    if (Math.abs(currentTime - position) > 1.5) {
      try {
        entry.player.currentTime = position;
      } catch (_) {}
    }
  }
}

function loadExternalYouTube(targetPlayer, videoId, source = {}) {
  if (!targetPlayer || typeof targetPlayer.loadVideoById !== "function") return;

  targetPlayer.loadVideoById({
    videoId,
    startSeconds: getSourcePlaybackPosition(source),
  });

  window.setTimeout(() => syncExternalTransport({ player: targetPlayer }, source), 120);
}

function shouldMutePlayer(targetPlayer, explicitMuted = null) {
  if (explicitMuted !== null) return explicitMuted === true;
  return targetPlayer === player || targetPlayer === streamAudio ? muted : externalMuted;
}

function setPlayerVolume(targetPlayer, targetVolume, explicitMuted = null) {
  if (!targetPlayer) return;

  const safeVolume = normalizeVolume(targetVolume);
  const outputVolume = applyMasterVolume(safeVolume);
  const isMuted = shouldMutePlayer(targetPlayer, explicitMuted);
  const shouldMute = isMuted || outputVolume <= 0 || safeVolume <= 0;

  if (typeof targetPlayer.setVolume === "function") {
    targetPlayer.setVolume(outputVolume);
  } else if ("volume" in targetPlayer) {
    targetPlayer.volume = outputVolume / 100;
  } else {
    return;
  }

  if (targetPlayer === player) {
    appliedVolume = safeVolume;
  }

  if (typeof targetPlayer.mute === "function" && typeof targetPlayer.unMute === "function") {
    if (shouldMute) {
      targetPlayer.mute();
    } else {
      targetPlayer.unMute();
    }
  } else if ("muted" in targetPlayer) {
    targetPlayer.muted = shouldMute;
  }
}

function fadeVolumeTo(targetVolume, targetPlayer = player, entry = null, explicitMuted = null) {
  if (!targetPlayer) return;

  const isMuted = shouldMutePlayer(targetPlayer, explicitMuted);
  const target = isMuted ? 0 : normalizeVolume(targetVolume);
  const timerKey = entry ? "fadeTimer" : null;

  if (entry?.fadeTimer) {
    window.clearInterval(entry.fadeTimer);
    entry.fadeTimer = null;
  } else if (!entry && fadeTimer) {
    window.clearInterval(fadeTimer);
    fadeTimer = null;
  }

  const start = targetPlayer === player ? appliedVolume : normalizeVolume(entry?.appliedVolume ?? target);
  const steps = Math.max(1, Math.ceil(FADE_DURATION_MS / FADE_STEP_MS));
  let step = 0;

  const timer = window.setInterval(() => {
    step += 1;
    const progress = Math.min(1, step / steps);
    const nextVolume = start + ((target - start) * progress);
    setPlayerVolume(targetPlayer, nextVolume, isMuted);

    if (entry) {
      entry.appliedVolume = normalizeVolume(nextVolume);
    }

    if (progress >= 1) {
      window.clearInterval(timer);
      if (entry && timerKey) entry[timerKey] = null;
      if (!entry) fadeTimer = null;
    }
  }, FADE_STEP_MS);

  if (entry && timerKey) {
    entry[timerKey] = timer;
  } else {
    fadeTimer = timer;
  }
}

function fadeOutThen(callback, targetPlayer = player, entry = null, explicitMuted = null) {
  fadeVolumeTo(0, targetPlayer, entry, explicitMuted);
  window.setTimeout(callback, FADE_DURATION_MS + FADE_STEP_MS);
}

function clearEntryFade(entry) {
  if (!entry?.fadeTimer) return;

  window.clearInterval(entry.fadeTimer);
  entry.fadeTimer = null;
}

function applyVolume() {
  if (playerReady && player && typeof player.setVolume === "function") {
    fadeVolumeTo(volume);
  }

  if (streamAudio) {
    fadeVolumeTo(volume, streamAudio, streamEntry);
  }
}

function readCurrentProgress(positionOverride = null) {
  if (streamAudio) {
    return {
      videoId: pendingTrack?.videoId || "",
      position: (positionOverride ?? streamAudio.currentTime) || 0,
      duration: Number.isFinite(streamAudio.duration) ? streamAudio.duration : 0,
    };
  }

  if (!playerReady || !player) {
    return {
      videoId: pendingTrack?.videoId || "",
      position: Math.max(0, Number(positionOverride) || 0),
      duration: 0,
    };
  }

  const videoData = typeof player.getVideoData === "function" ? player.getVideoData() || {} : {};
  const position = typeof player.getCurrentTime === "function" ? player.getCurrentTime() || 0 : 0;
  const duration = typeof player.getDuration === "function" ? player.getDuration() || 0 : 0;

  return {
    videoId: videoData.video_id || pendingTrack?.videoId || "",
    position: positionOverride ?? position,
    duration,
  };
}

function postCurrentProgress(positionOverride = null) {
  postNui("engine.progress", readCurrentProgress(positionOverride));
}

function startProgressTimer() {
  if (progressTimer) window.clearInterval(progressTimer);

  progressTimer = window.setInterval(() => {
    postCurrentProgress();
  }, 1000);
}

function stopStreamAudio() {
  if (!streamAudio) return;

  streamAudio.pause();
  streamAudio.removeAttribute("src");
  streamAudio.load();
  streamAudio = null;
  streamEntry.appliedVolume = 0;

  if (streamEntry.fadeTimer) {
    window.clearInterval(streamEntry.fadeTimer);
    streamEntry.fadeTimer = null;
  }
}

function playTrack(track, playback = {}) {
  const videoId = getTrackVideoId(track);
  const streamUrl = getTrackStreamUrl(track);
  if (!videoId && !streamUrl) return;
  const previousKey = getTrackKey(pendingTrack);

  pendingTrack = {
    ...track,
    videoId: videoId || streamUrl,
  };

  if (streamUrl) {
    if (playerReady && player && typeof player.pauseVideo === "function") {
      player.pauseVideo();
    }

    const load = () => {
      stopStreamAudio();
      streamAudio = new Audio(streamUrl);
      streamAudio.preload = "none";
      streamAudio.loop = true;
      streamAudio.addEventListener("error", () => {
        postNui("engine.error", {
          code: "stream_error",
          videoId: pendingTrack?.videoId || "",
        });
      });
      setPlayerVolume(streamAudio, 0);
      try {
        streamAudio.currentTime = Math.max(0, Number(playback.position) || 0);
      } catch (_) {}
      streamAudio.play().catch(() => {
        postNui("engine.error", {
          code: "stream_play_failed",
          videoId: pendingTrack?.videoId || "",
        });
      });
      fadeVolumeTo(volume, streamAudio, streamEntry);
      startProgressTimer();
    };

    if (previousKey && previousKey !== streamUrl && streamAudio) {
      fadeOutThen(() => load(), streamAudio, streamEntry);
    } else {
      load();
    }
    return;
  }

  stopStreamAudio();

  if (!playerReady || !player || typeof player.loadVideoById !== "function") {
    return;
  }

  const load = () => {
    setPlayerVolume(player, 0);
    player.loadVideoById({
      videoId,
      startSeconds: Math.max(0, Number(playback.position) || 0),
    });

    fadeVolumeTo(volume);
    startProgressTimer();
  };

  if (previousKey && previousKey !== videoId) {
    fadeOutThen(() => load());
  } else {
    load();
  }
}

function pauseTrack() {
  if (streamAudio) {
    fadeOutThen(() => streamAudio?.pause(), streamAudio, streamEntry);
    return;
  }

  if (playerReady && player && typeof player.pauseVideo === "function") {
    fadeOutThen(() => player.pauseVideo());
  }
}

function resumeTrack() {
  if (streamAudio) {
    streamAudio.play().catch(() => null);
    fadeVolumeTo(volume, streamAudio, streamEntry);
    return;
  }

  if (playerReady && player && typeof player.playVideo === "function") {
    player.playVideo();
    fadeVolumeTo(volume);
  }
}

function stopTrack() {
  if (streamAudio) {
    fadeOutThen(() => stopStreamAudio(), streamAudio, streamEntry);
  }

  if (playerReady && player && typeof player.stopVideo === "function") {
    fadeOutThen(() => player.stopVideo());
  }

  pendingTrack = null;
}

function seekTrack(position) {
  const safePosition = Math.max(0, Number(position) || 0);

  if (streamAudio) {
    try {
      streamAudio.currentTime = safePosition;
    } catch (_) {}
    streamAudio.play().catch(() => null);
    fadeVolumeTo(volume, streamAudio, streamEntry);
    postCurrentProgress(safePosition);
    return;
  }

  if (!playerReady || !player || typeof player.seekTo !== "function") return;

  player.seekTo(safePosition, true);
  if (typeof player.playVideo === "function") {
    player.playVideo();
    fadeVolumeTo(volume);
  }
  postCurrentProgress(safePosition);
}

function getExternalElement(sourceId) {
  const elementId = `external-player-${sourceId}`;
  let element = document.getElementById(elementId);

  if (!element) {
    element = document.createElement("div");
    element.id = elementId;
    element.style.position = "fixed";
    element.style.left = "-9999px";
    element.style.top = "-9999px";
    element.style.width = "1px";
    element.style.height = "1px";
    document.body.appendChild(element);
  }

  return element;
}

function applyExternalVolume(sourceId, source = {}) {
  const entry = externalPlayers[sourceId];
  if (!entry?.ready || !entry.player) return;
  if (entry.parked && !pendingExternalSources[sourceId]) return;
  if (typeof entry.player.setVolume !== "function" && !("volume" in entry.player)) return;

  const storedSource = pendingExternalSources[sourceId] || {};
  const sourceVolume = normalizeVolume(source.volume ?? storedSource.volume ?? 100);
  fadeVolumeTo(Math.min(externalVolume, sourceVolume), entry.player, entry, externalMuted);
}

function playExternalSource(sourceId, source = {}) {
  const track = source.track || source.currentTrack || source;
  const videoId = getTrackVideoId(track);
  const streamUrl = getTrackStreamUrl(track);
  if (!sourceId || (!videoId && !streamUrl)) return;
  const sourceVersion = bumpExternalVersion(sourceId);
  const previousSource = pendingExternalSources[sourceId] || {};
  const previousTrack = previousSource.track || previousSource.currentTrack || previousSource;
  const previousKey = getTrackKey(previousTrack);

  pendingExternalSources[sourceId] = source;

  if (streamUrl) {
    if (!externalPlayers[sourceId] || externalPlayers[sourceId].kind !== "stream") {
      destroyExternalPlayer(sourceId);
      const audio = new Audio(streamUrl);
      audio.preload = "none";
      audio.loop = true;
      externalPlayers[sourceId] = {
        kind: "stream",
        ready: true,
        parked: false,
        fadeTimer: null,
        appliedVolume: 0,
        player: audio,
      };
      setPlayerVolume(audio, 0);
      try {
        audio.currentTime = getSourcePlaybackPosition(source);
      } catch (_) {}
      syncExternalTransport(externalPlayers[sourceId], source);
      applyExternalVolume(sourceId, source);
      return;
    }

    const entry = externalPlayers[sourceId];
    const load = () => {
      if (getExternalVersion(sourceId) !== sourceVersion) return;

      entry.player.src = streamUrl;
      entry.player.load();
      try {
        entry.player.currentTime = getSourcePlaybackPosition(source);
      } catch (_) {}
      syncExternalTransport(entry, source);
      applyExternalVolume(sourceId, source);
    };

    if (previousKey && previousKey !== streamUrl) {
      fadeOutThen(() => load(), entry.player, entry);
    } else {
      load();
    }
    return;
  }

  if (externalPlayers[sourceId]?.kind === "stream") {
    destroyExternalPlayer(sourceId);
  }

  if (!playerReady || typeof YT === "undefined" || !YT.Player) {
    return;
  }

  if (!externalPlayers[sourceId]) {
    const element = getExternalElement(sourceId);
    const embedOrigin = getYouTubeEmbedOrigin();

    externalPlayers[sourceId] = {
      kind: "youtube",
      ready: false,
      parked: false,
      fadeTimer: null,
      appliedVolume: 0,
      player: new YT.Player(element.id, {
        width: "1",
        height: "1",
        playerVars: {
          autoplay: 1,
          controls: 0,
          disablekb: 1,
          enablejsapi: 1,
          playsinline: 1,
          origin: embedOrigin,
          widget_referrer: embedOrigin,
        },
        events: {
          onReady(event) {
            if (getExternalVersion(sourceId) !== sourceVersion) return;

            externalPlayers[sourceId].ready = true;
            externalPlayers[sourceId].parked = false;
            setPlayerVolume(event.target, 0);
            loadExternalYouTube(event.target, videoId, source);
            applyExternalVolume(sourceId, source);
          },
        },
      }),
    };
    return;
  }

  const entry = externalPlayers[sourceId];
  if (entry.ready && typeof entry.player.loadVideoById === "function") {
    const load = () => {
      if (getExternalVersion(sourceId) !== sourceVersion) return;

      entry.parked = false;
      setPlayerVolume(entry.player, 0);
      loadExternalYouTube(entry.player, videoId, source);
      applyExternalVolume(sourceId, source);
    };

    if (previousKey && previousKey !== videoId) {
      fadeOutThen(() => load(), entry.player, entry);
    } else {
      load();
    }
  }
}

function updateExternalSource(sourceId, source = {}) {
  if (!sourceId) return;
  bumpExternalVersion(sourceId);

  const previousSource = pendingExternalSources[sourceId] || {};
  const previousTrack = previousSource.track || previousSource.currentTrack || previousSource;
  const previousKey = getTrackKey(previousTrack);
  const nextSource = {
    ...previousSource,
    ...source,
  };
  const nextTrack = nextSource.track || nextSource.currentTrack || nextSource;
  const nextKey = getTrackKey(nextTrack);
  const previousNonce = Number(previousSource.playback?.nonce) || 0;
  const nextNonce = Number(nextSource.playback?.nonce) || 0;

  if (!externalPlayers[sourceId]) {
    playExternalSource(sourceId, nextSource);
    return;
  }

  if (previousKey !== nextKey) {
    playExternalSource(sourceId, nextSource);
    return;
  }

  pendingExternalSources[sourceId] = nextSource;
  if (previousNonce !== nextNonce) {
    syncExternalPosition(externalPlayers[sourceId], nextSource);
  }
  syncExternalTransport(externalPlayers[sourceId], nextSource);
  applyExternalVolume(sourceId, nextSource);
}

function setExternalVolume(sourceId, sourceVolume) {
  if (!sourceId) return;

  pendingExternalSources[sourceId] = {
    ...(pendingExternalSources[sourceId] || {}),
    volume: Math.max(0, Math.min(100, Math.round(Number(sourceVolume) || 0))),
  };

  applyExternalVolume(sourceId, pendingExternalSources[sourceId]);
}

function destroyExternalPlayer(sourceId) {
  const entry = externalPlayers[sourceId];

  if (entry?.kind === "youtube") {
    parkYouTubeEntry(sourceId, entry);
    return;
  }

  clearEntryFade(entry);

  if (entry?.player && typeof entry.player.pause === "function") {
    entry.player.pause();
    entry.player.removeAttribute("src");
    entry.player.load();
  }

  delete externalPlayers[sourceId];
  delete pendingExternalSources[sourceId];

  const element = document.getElementById(`external-player-${sourceId}`);
  if (element) element.remove();
}

function parkYouTubeEntry(sourceId, entry) {
  clearEntryFade(entry);
  delete pendingExternalSources[sourceId];

  if (!entry?.player) return;

  entry.parked = true;
  entry.appliedVolume = 0;

  setPlayerVolume(entry.player, 0, true);

  try {
    if (typeof entry.player.stopVideo === "function") {
      entry.player.stopVideo();
    } else if (typeof entry.player.pauseVideo === "function") {
      entry.player.pauseVideo();
    }
  } catch (_) {}
}

function removeExternalSource(sourceId) {
  const entry = externalPlayers[sourceId];
  const removeVersion = bumpExternalVersion(sourceId);

  if (entry?.kind === "youtube" && entry.player) {
    fadeOutThen(() => {
      if (externalPlayers[sourceId] === entry && getExternalVersion(sourceId) === removeVersion) {
        parkYouTubeEntry(sourceId, entry);
      }
    }, entry.player, entry, true);
    return;
  }

  if (entry?.player) {
    fadeOutThen(() => {
      if (externalPlayers[sourceId] === entry && getExternalVersion(sourceId) === removeVersion) {
        destroyExternalPlayer(sourceId);
      }
    }, entry.player, entry);
    return;
  }

  destroyExternalPlayer(sourceId);
}

function initYouTubePlayer() {
  const embedOrigin = getYouTubeEmbedOrigin();

  player = new YT.Player("youtube-player", {
    width: "1",
    height: "1",
    playerVars: {
      autoplay: 0,
      controls: 0,
      disablekb: 1,
      enablejsapi: 1,
      playsinline: 1,
      origin: embedOrigin,
      widget_referrer: embedOrigin,
    },
    events: {
      onReady() {
        playerReady = true;
        applyVolume();
        postNui("engine.ready");

        if (pendingTrack) {
          playTrack(pendingTrack);
        }

        for (const [sourceId, source] of Object.entries(pendingExternalSources)) {
          playExternalSource(sourceId, source);
        }
      },
      onStateChange(event) {
        if (event.data === YT.PlayerState.ENDED) {
          postNui("engine.ended", {
            videoId: pendingTrack?.videoId || "",
          });
        }
      },
      onError(event) {
        postNui("engine.error", {
          code: event.data,
          videoId: pendingTrack?.videoId || "",
        });
      },
    },
  });
}

// Register the callback before loading the IFrame API: as a module this file runs after parsing, so a
// <script src="iframe_api"> in the page could finish first and call an undefined callback.
if (window.YT && window.YT.Player) {
  initYouTubePlayer();
} else {
  window.onYouTubeIframeAPIReady = initYouTubePlayer;

  const apiScript = document.createElement("script");
  apiScript.src = "https://www.youtube.com/iframe_api";
  apiScript.async = true;
  document.head.appendChild(apiScript);
}

window.addEventListener("message", (event) => {
  const message = event.data || {};
  if (message.target !== "audio-engine") return;

  const payload = message.payload || {};

  if (message.action === "engine.play") {
    playTrack(payload.track, payload.playback);
  } else if (message.action === "engine.pause") {
    pauseTrack();
  } else if (message.action === "engine.resume") {
    resumeTrack();
  } else if (message.action === "engine.stop") {
    stopTrack();
  } else if (message.action === "engine.seek") {
    seekTrack(payload.position);
  } else if (message.action === "engine.volume") {
    volume = Math.max(0, Math.min(100, Math.round(Number(payload.value) || 0)));
    externalVolume = Math.max(0, Math.min(100, Math.round(Number(payload.externalValue ?? payload.value) || 0)));
    muted = payload.muted === true;
    externalMuted = payload.externalMuted === true;
    applyVolume();
    for (const [sourceId, source] of Object.entries(pendingExternalSources)) {
      applyExternalVolume(sourceId, source);
    }
  } else if (message.action === "engine.masterVolume") {
    masterVolume = normalizeVolume(payload.value ?? payload.volume ?? masterVolume);
    applyVolume();
    for (const [sourceId, source] of Object.entries(pendingExternalSources)) {
      applyExternalVolume(sourceId, source);
    }
  } else if (message.action === "engine.external.add") {
    playExternalSource(String(payload.sourceId || ""), payload.source || {});
  } else if (message.action === "engine.external.update") {
    updateExternalSource(String(payload.sourceId || ""), payload.source || {});
  } else if (message.action === "engine.external.volume") {
    setExternalVolume(String(payload.sourceId || ""), payload.volume);
  } else if (message.action === "engine.external.remove") {
    removeExternalSource(String(payload.sourceId || ""));
  }
});
