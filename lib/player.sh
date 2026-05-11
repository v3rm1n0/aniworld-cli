#!/usr/bin/env bash
# player.sh - Video Player Integration

# Portable sed -i: handles BSD (macOS) vs GNU (Linux) difference
sed_inplace() {
    local expr="$1" file="$2"
    if sed --version 2>/dev/null | grep -q GNU; then
        sed -i "$expr" "$file"
    else
        sed -i '' "$expr" "$file"
    fi
}

# Prüfe verfügbare Player (Windows-kompatibel)
get_available_player() {
    if command -v iina &>/dev/null || [ -f "/Applications/IINA.app/Contents/MacOS/IINA" ]; then
        echo "iina"
    elif command -v mpv &>/dev/null || command -v mpv.exe &>/dev/null; then
        echo "mpv"
    elif command -v vlc &>/dev/null || command -v vlc.exe &>/dev/null; then
        echo "vlc"
    else
        echo ""
    fi
}

# Spiele Video ab
play_video() {
    local video_url="$1"
    local player
    player=$(get_available_player)

    if [ -z "$player" ]; then
        show_error "Kein Video-Player gefunden (mpv oder vlc benötigt)"
        return 1
    fi

    # Töte vorherige aniworld-cli mpv-Instanz (nur unsere, nicht fremde)
    if [ -n "${ANIWORLD_MPV_PID:-}" ] && kill -0 "$ANIWORLD_MPV_PID" 2>/dev/null; then
        kill "$ANIWORLD_MPV_PID" 2>/dev/null || true
        wait "$ANIWORLD_MPV_PID" 2>/dev/null || true
    fi

    # Windows-kompatibel: Finde den korrekten Befehl
    local player_cmd=""
    if [ "$player" = "mpv" ]; then
        if command -v mpv &>/dev/null; then
            player_cmd="mpv"
        elif command -v mpv.exe &>/dev/null; then
            player_cmd="mpv.exe"
        fi
    elif [ "$player" = "vlc" ]; then
        if command -v vlc &>/dev/null; then
            player_cmd="vlc"
        elif command -v vlc.exe &>/dev/null; then
            player_cmd="vlc.exe"
        fi
    fi

    case "$player" in
        iina)
           local iina_cmd="/Applications/IINA.app/Contents/MacOS/IINA"
           local iina_slang iina_alang
           case "${LANG_PREFERENCE:-}" in
               EngSub) iina_slang="en,de" ; iina_alang="en,de" ;;
               *)      iina_slang="de,en" ; iina_alang="de,en" ;;
           esac
           "$iina_cmd" --no-stdin \
               --mpv-slang="$iina_slang" \
               --mpv-alang="$iina_alang" \
               "$video_url" >/dev/null 2>&1 &
           ANIWORLD_MPV_PID=$!
        ;;
        mpv)
            # Prüfe ob yt-dlp verfügbar ist
            local ytdl_path=""
            if command -v yt-dlp &>/dev/null; then
                ytdl_path="yt-dlp"
            elif command -v yt-dlp.exe &>/dev/null; then
                ytdl_path="yt-dlp.exe"
            elif command -v youtube-dl &>/dev/null; then
                ytdl_path="youtube-dl"
            fi

            # Bestimme Referrer basierend auf Hoster
            local referrer="https://aniworld.to"
            if [[ "$video_url" == *"filemoon"* ]] || [[ "$video_url" == *"ico3c.com"* ]]; then
                referrer="https://filemoon.to/"
            fi

            # Sprach-Tracks basierend auf LANG_PREFERENCE
            local slang alang
            case "${LANG_PREFERENCE:-}" in
                EngSub) slang="en,de" ; alang="en,de" ;;
                *)      slang="de,en" ; alang="de,en" ;;
            esac

            if [ -n "$ytdl_path" ]; then
                "$player_cmd" "$video_url" \
                    --referrer="$referrer" \
                    --user-agent="$USER_AGENT" \
                    --script-opts=ytdl_hook-ytdl_path="$ytdl_path" \
                    --ytdl-format=bestvideo+bestaudio/best \
                    --force-media-title="$CURRENT_TITLE" \
                    --slang="$slang" \
                    --alang="$alang" \
                    --cache=yes \
                    --demuxer-max-bytes=150M \
                    --demuxer-max-back-bytes=75M \
                    --demuxer-readahead-secs=30 \
                    --cache-secs=10 \
                    --hls-bitrate=max \
                    --stream-buffer-size=2M \
                    --demuxer-lavf-o=timeout=10000000 \
                    >/dev/null 2>&1 &
                ANIWORLD_MPV_PID=$!
            else
                "$player_cmd" "$video_url" \
                    --referrer="$referrer" \
                    --user-agent="$USER_AGENT" \
                    --force-media-title="$CURRENT_TITLE" \
                    --slang="$slang" \
                    --alang="$alang" \
                    --cache=yes \
                    --demuxer-max-bytes=150M \
                    --demuxer-max-back-bytes=75M \
                    --demuxer-readahead-secs=30 \
                    --cache-secs=10 \
                    --hls-bitrate=max \
                    --stream-buffer-size=2M \
                    --demuxer-lavf-o=timeout=10000000 \
                    >/dev/null 2>&1 &
                ANIWORLD_MPV_PID=$!
            fi
            ;;
        vlc)
            # Bestimme Referrer basierend auf Hoster
            local referrer="https://aniworld.to"
            if [[ "$video_url" == *"filemoon"* ]] || [[ "$video_url" == *"ico3c.com"* ]]; then
                referrer="https://filemoon.to/"
            fi

            local vlc_lang
            case "${LANG_PREFERENCE:-}" in
                EngSub) vlc_lang="en,de" ;;
                *)      vlc_lang="de,en" ;;
            esac

            "$player_cmd" "$video_url" \
                --http-referrer="$referrer" \
                --http-user-agent="$USER_AGENT" \
                --sub-language="$vlc_lang" \
                --audio-language="$vlc_lang" \
                --no-loop \
                --play-and-exit \
                --file-caching=5000 \
                --network-caching=5000 \
                --live-caching=5000 \
                >/dev/null 2>&1 &
            ANIWORLD_MPV_PID=$!
            ;;
    esac
}

# Konfiguriere Player-Präferenz
get_player_preference() {
    if [ -f "$CONFIG_FILE" ]; then
        grep "^player=" "$CONFIG_FILE" | cut -d'=' -f2
    fi
}

# Setze Player-Präferenz
set_player_preference() {
    local player="$1"
    mkdir -p "$DATA_DIR"

    if [ -f "$CONFIG_FILE" ]; then
        sed_inplace "/^player=/d" "$CONFIG_FILE"
    fi

    echo "player=${player}" >> "$CONFIG_FILE"
}
