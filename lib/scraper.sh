# scraper.sh - Web Scraping Functions

# Session Cache für HTML-Seiten (reduziert HTTP-Requests)
# Bash 3.2 compatible: tmpdir-based cache instead of declare -A
_HTML_CACHE_DIR=""

_init_html_cache() {
    _HTML_CACHE_DIR=$(mktemp -d)
}

_html_cache_get() {
    local key="$1"
    local cache_file="${_HTML_CACHE_DIR}/${key}"
    [ -f "$cache_file" ] && cat "$cache_file"
}

_html_cache_set() {
    local key="$1" value="$2"
    printf '%s' "$value" > "${_HTML_CACHE_DIR}/${key}"
}

# Default: German Dub, fallback to GerSub, then EngSub
LANG_PREFERENCE="GerDub"
export LANG_PREFERENCE

# Hole HTML mit Cache
get_anime_html() {
    local slug="$1"

    # Prüfe Cache
    local cached
    cached=$(_html_cache_get "$slug")
    if [ -n "$cached" ]; then
        echo "$cached"
        return 0
    fi

    # Lade HTML
    local html
    html=$(curl -s --compressed -A "$USER_AGENT" "${BASE_URL}/anime/stream/${slug}")

    # Speichere im Cache
    _html_cache_set "$slug" "$html"

    echo "$html"
}

# Suche nach Anime
search_anime() {
    local query="$1"

    show_loading "Suche nach '${query}'"

    # AJAX-Request an die Search-API (mit Compression und Timeout)
    local json
    json=$(curl -s --compressed --max-time 10 -X POST \
                -A "$USER_AGENT" \
                -H "Content-Type: application/x-www-form-urlencoded" \
                --data-urlencode "keyword=${query}" \
                "${BASE_URL}/ajax/search")

    clear_loading

    # Parse JSON und extrahiere nur Anime-Links
    # Format: Titel|Slug
    if command -v jq &>/dev/null; then
        # Mit jq (bevorzugt)
        echo "$json" | \
            jq -r '.[] | select(.link | startswith("/anime/stream/")) | .title + "|" + (.link | sub("/anime/stream/"; ""))' | \
            sed 's/<em>//g; s/<\/em>//g'
    else
        # Fallback ohne jq
        echo "$json" | \
            tr ',' '\n' | \
            grep '/anime/stream/' | \
            sed -n 's/.*"link":"\/anime\/stream\/\([^"]*\)".*/\1/p' | \
            while read -r slug; do
                title=$(echo "$json" | sed -n "s/.*\"link\":\"\/anime\/stream\/${slug}\"[^}]*\"title\":\"\([^\"]*\)\".*/\1/p" | head -1)
                echo "${title}|${slug}"
            done | \
            sed 's/<em>//g; s/<\/em>//g'
    fi
}

# Hole Staffeln für einen Anime (gecached)
get_seasons() {
    local slug="$1"

    show_loading "Lade Staffeln"

    local html
    html=$(get_anime_html "$slug")

    clear_loading

    # Parse Staffeln (Windows-kompatibel mit sed, optimiert)
    echo "$html" | \
        sed -n 's/.*staffel-\([0-9][0-9]*\).*/\1/p' | \
        sort -nu
}

# Hole Episoden für eine Staffel mit Fallback auf die Staffelseite
get_episodes() {
    local slug="$1"
    local season="$2"

    show_loading "Lade Episoden"
    local html
    html=$(get_anime_html "$slug")
    clear_loading

    # 1. Versuche: Episoden aus Haupt-HTML extrahieren
    local episodes
    episodes=$(echo "$html" | \
        sed -n "s/.*staffel-${season}\/episode-\([0-9][0-9]*\).*/\1/p" | \
        sort -nu)

    # 2. Fallback: Wenn keine Episoden gefunden, lade dedizierte Staffelseite
    if [ -z "$episodes" ]; then
        echo "DEBUG: Keine Episoden für Staffel ${season} auf Hauptseite gefunden. Lade Staffelseite..." >&2
        show_loading "Lade Staffelseite"
        local season_html
        season_html=$(curl -sL --compressed -A "$USER_AGENT" \
            "${BASE_URL}/anime/stream/${slug}/staffel-${season}")
        clear_loading

        episodes=$(echo "$season_html" | \
            sed -n "s/.*staffel-${season}\/episode-\([0-9][0-9]*\).*/\1/p" | \
            sort -nu)
    fi

    # 3. Debug-Ausgabe, falls immer noch nichts gefunden wurde
    if [ -z "$episodes" ]; then
        echo "ERROR: Konnte keine Episoden für Staffel ${season} von ${slug} finden." >&2
    fi

    echo "$episodes"
}

# Hole Hoster-Links für eine Episode
get_hoster_links() {
    local slug="$1"
    local season="$2"
    local episode="$3"

    show_loading "Lade Hoster"

    local url="${BASE_URL}/anime/stream/${slug}/staffel-${season}/episode-${episode}"
    local html
    html=$(curl -s --compressed -A "$USER_AGENT" "$url")

    clear_loading

    # Debug: Speichere HTML für Fehleranalyse (optional)
    if [ -n "${DEBUG:-}" ]; then
        echo "$html" > "${DATA_DIR}/debug_episode.html"
        show_info "Debug: HTML gespeichert in ${DATA_DIR}/debug_episode.html"
    fi

    # Parse Redirect-IDs, Hoster-Namen und Metadaten
    # Format: redirect_id|hoster_name|language|quality
    # Windows-kompatible Version ohne grep -oP (funktioniert mit Git Bash)

    # Extrahiere alle redirect IDs, Hoster-Namen und Metadaten
    # current_lang tracks the language context across <li> elements:
    # aniworld.to may put data-lang-key on a parent <li> (language tab) while
    # data-link-target is on a child <li> (hoster row). The grep pre-filter
    # would discard the parent before we see it, so we scan ALL <li> lines and
    # track the last seen lang key, then skip non-redirect lines inside the loop.
    current_lang=""
    echo "$html" | \
        tr '\n' ' ' | \
        sed 's/<li/\n<li/g' | \
        while IFS= read -r line || [ -n "$line" ]; do
            # Always update language context when a lang-key marker is seen
            if echo "$line" | grep -q 'data-lang-key='; then
                current_lang=$(echo "$line" | sed -n 's/.*data-lang-key="\([^"]*\)".*/\1/p' | head -1)
            fi

            # Skip lines that are not hoster redirect links
            echo "$line" | grep -q 'data-link-target="/redirect/' || continue

            # Extrahiere redirect_id mit sed (POSIX-kompatibel)
            redirect_id=$(echo "$line" | sed -n 's/.*data-link-target="\/redirect\/\([0-9]*\)".*/\1/p')

            # Extrahiere Hoster-Name aus verschiedenen Patterns
            # Pattern 1: <i class="icon HOSTER">
            hoster=$(echo "$line" | sed -n 's/.*<i class="icon \([^"]*\)".*/\1/p' | head -1)

            # Pattern 2: <h4>HOSTER</h4>
            if [ -z "$hoster" ]; then
                hoster=$(echo "$line" | sed -n 's/.*<h4>\([^<]*\)<\/h4>.*/\1/p' | head -1)
            fi

            # Sprache: bevorzuge den getrackt Kontext, dann inline data-lang-key
            lang_key=$(echo "$line" | sed -n 's/.*data-lang-key="\([^"]*\)".*/\1/p' | head -1)
            [ -z "$lang_key" ] && lang_key="$current_lang"

            # Mappe language keys zu lesbaren Namen (basierend auf aniworld.to Konvention)
            case "$lang_key" in
                1) language="GerDub" ;;
                2) language="EngSub" ;;
                3) language="GerSub" ;;
                *) language="" ;;
            esac

            # Extrahiere Qualität aus verschiedenen Quellen
            # 1. Suche nach expliziten Qualitäts-Angaben (720p, 1080p, etc.)
            quality=$(echo "$line" | grep -oE '[0-9]{3,4}p' | head -1)

            # 2. Wenn nicht gefunden, suche nach Qualitäts-Keywords
            if [ -z "$quality" ]; then
                if echo "$line" | grep -qi "1080"; then
                    quality="1080p"
                elif echo "$line" | grep -qi "720"; then
                    quality="720p"
                elif echo "$line" | grep -qi "480"; then
                    quality="480p"
                elif echo "$line" | grep -qi "HD"; then
                    quality="HD"
                fi
            fi

            # Fallback: Suche nach GerDub, GerSub direkt im Text
            if [ -z "$language" ]; then
                language=$(echo "$line" | grep -oE '(GerDub|GerSub|EngSub|Ger|Eng)' | head -1)
            fi

            # Fallback: Wenn kein Hoster-Name gefunden, nutze language oder generischen Namen
            if [ -z "$hoster" ]; then
                if [ -n "$language" ]; then
                    hoster="$language"
                else
                    hoster="Hoster_${redirect_id}"
                fi
            fi

            # Debug output
            if [ -n "${DEBUG:-}" ]; then
                echo "DEBUG: redirect_id=$redirect_id hoster=$hoster language=$language quality=$quality" >&2
            fi

            # Nur ausgeben wenn redirect_id vorhanden
            if [ -n "$redirect_id" ]; then
                # Format: redirect_id|hoster|language|quality
                echo "${redirect_id}|${hoster}|${language:-N/A}|${quality:-N/A}"
            fi
        done
}

# Extrahiere Video-URL aus Hoster
extract_video_url() {
    local redirect_id="$1"

    show_info "Extrahiere Video-URL..."

    # Folge dem Redirect
    local redirect_url="${BASE_URL}/redirect/${redirect_id}"
    local embed_url
    embed_url=$(curl -sL -A "$USER_AGENT" \
                     -w '%{url_effective}' \
                     -o /dev/null \
                     "$redirect_url")

    if [ -z "$embed_url" ]; then
        show_error "Konnte Redirect nicht folgen"
        return 1
    fi

    # Versuche Video-URL zu extrahieren basierend auf Hoster
    local video_url=""

    if [[ "$embed_url" == *"streamtape"* ]]; then
        video_url=$(extract_streamtape_url "$embed_url")
    elif [[ "$embed_url" == *"vidmoly"* ]]; then
        video_url=$(extract_vidmoly_url "$embed_url")
    elif [[ "$embed_url" == *"doodstream"* ]] || [[ "$embed_url" == *"dood"* ]]; then
        video_url=$(extract_doodstream_url "$embed_url")
    elif [[ "$embed_url" == *"voe.sx"* ]] || [[ "$embed_url" == *"voe"* ]]; then
        video_url=$(extract_voe_url "$embed_url")
    elif [[ "$embed_url" == *"filemoon"* ]]; then
        video_url=$(extract_filemoon_url "$embed_url")
    fi

    # Validate: must be non-empty and look like an actual video URL (not just an embed page)
    if [ -n "$video_url" ] && [[ "$video_url" =~ \.(m3u8|mp4|ts)([\?#]|$) || "$video_url" == *"/hls/"* || "$video_url" == *"/playlist"* ]]; then
        echo "$video_url"
    elif [ -n "$video_url" ] && [ -n "${DEBUG:-}" ]; then
        echo "WARN: Extracted URL doesn't look like a video: $video_url" >&2
        echo ""
    else
        echo ""
    fi
}

# Extrahiere VOE Video-URL
extract_voe_url() {
    local embed_url="$1"

    if command -v node &>/dev/null; then
        local video_url
        video_url=$(node "${LIB_DIR}/extract_voe.js" "$embed_url" 2>/dev/null)
        if [ -n "$video_url" ]; then
            echo "$video_url"
            return 0
        fi
    fi

    if [ -n "${DEBUG:-}" ]; then
        echo "WARN: VOE extraction failed (node.js required)" >&2
    fi
    echo ""
}

# Extrahiere Vidmoly Video-URL
extract_vidmoly_url() {
    local embed_url="$1"

    local html
    html=$(curl -s -A "$USER_AGENT" "$embed_url")

    # Vidmoly verwendet oft "sources" in JavaScript (Windows-kompatibel)
    local video_url
    video_url=$(echo "$html" | sed -n 's/.*\(sources\|file\):\s*["\x27]\(https\?:\/\/[^"'\'']*\.\(m3u8\|mp4\)[^"'\'']*\).*/\2/p' | head -1)

    # Fallback: Generisches Pattern
    if [ -z "$video_url" ]; then
        video_url=$(echo "$html" | grep -o 'https\?://[^"'\'']*\.\(m3u8\|mp4\)[^"'\'']*' | head -1)
    fi

    if [ -n "$video_url" ]; then
        echo "$video_url"
    else
        if [ -n "${DEBUG:-}" ]; then
            echo "WARN: Vidmoly m3u8 extraction failed for $embed_url" >&2
        fi
        echo ""
    fi
}

# Extrahiere Streamtape Video-URL
extract_streamtape_url() {
    local embed_url="$1"

    local html
    html=$(curl -s -A "$USER_AGENT" "$embed_url")

    # Streamtape verschleiert die URL, suche nach typischen Patterns (Windows-kompatibel)
    local video_url
    video_url=$(echo "$html" | sed -n "s/.*document\.getElementById('videolink')\.innerHTML = '\/\/\([^']*\)'.*/\1/p" | head -1)

    if [ -n "$video_url" ]; then
        echo "https://${video_url}"
    else
        echo ""
    fi
}

# Extrahiere Doodstream Video-URL
extract_doodstream_url() {
    local embed_url="$1"

    local html
    html=$(curl -s -A "$USER_AGENT" "$embed_url")

    # Doodstream verwendet ein spezielles Pattern
    local video_url
    video_url=$(echo "$html" | sed -n "s/.*\\\$\.get([\"']\(\/pass_md5\/[^\"']*\)[\"'].*/\1/p" | head -1 | sed 's|/pass_md5/||')

    if [ -n "$video_url" ]; then
        local base_url
        base_url=$(echo "$embed_url" | sed -n 's|\(https\?://[^/]*\).*|\1|p')
        video_url=$(curl -s -A "$USER_AGENT" "${base_url}/pass_md5/${video_url}")
        echo "$video_url"
    else
        echo ""
    fi
}

# Extrahiere Filemoon Video-URL (broken - SPA migration, needs headless browser)
extract_filemoon_url() {
    local embed_url="$1"

    if [ -n "${DEBUG:-}" ]; then
        echo "WARN: Filemoon is broken (SPA/Vite migration), skipping" >&2
    fi
    echo ""
}

# Hole Anime-Titel (gecached)
get_anime_title() {
    local slug="$1"

    local html
    html=$(get_anime_html "$slug")

    # Titel ist in <h1 itemprop="name"><span>TITEL</span></h1> Format
    # Wichtig: Nur das erste <span> innerhalb von <h1>, nicht greedy matchen
    echo "$html" | \
        grep 'itemprop="name"' | \
        sed -n 's/.*<h1[^>]*>.*<span>\([^<]*\)<\/span>.*/\1/p' | \
        head -1
}
# Hole Gesamt-Episodenanzahl über alle Staffeln (mit Cache und Fallback)
get_total_episode_count() {
    local slug="$1"

    # Prüfe Cache
    if [ -f "$EPISODE_COUNT_CACHE" ]; then
        local cached
        cached=$(grep "^${slug}|" "$EPISODE_COUNT_CACHE" 2>/dev/null | cut -d'|' -f2)
        if [ -n "$cached" ]; then
            echo "$cached"
            return 0
        fi
    fi

    # Hole HTML aus Cache
    local html
    html=$(get_anime_html "$slug")

    # Extrahiere alle Staffeln aus dem HTML
    local seasons
    seasons=$(echo "$html" | sed -n 's/.*staffel-\([0-9][0-9]*\).*/\1/p' | sort -nu)

    # Zähle Episoden pro Staffel
    local total=0
    while read -r season; do
        local count
        count=$(echo "$html" | sed -n "s/.*staffel-${season}\/episode-\([0-9][0-9]*\).*/\1/p" | sort -nu | tail -1)

        # Fallback: Wenn keine Episoden im Haupt-HTML für diese Staffel, lade Staffelseite
        if [ -z "$count" ]; then
            local season_html
            season_html=$(curl -sL --compressed -A "$USER_AGENT" "${BASE_URL}/anime/stream/${slug}/staffel-${season}")
            count=$(echo "$season_html" | sed -n "s/.*staffel-${season}\/episode-\([0-9][0-9]*\).*/\1/p" | sort -nu | tail -1)
        fi

        if [ -n "$count" ]; then
            total=$((total + count))
        fi
    done <<< "$seasons"

    # Speichere im Cache
    mkdir -p "$CACHE_DIR"
    echo "${slug}|${total}" >> "$EPISODE_COUNT_CACHE"

    echo "$total"
}

# Extrahiere Video-URL mit automatischem Hoster-Fallback
# Output: Zeile 1 = Video-URL, Zeile 2 = Hoster-Name (fuer CURRENT_HOSTER_NAME)
extract_video_with_fallback() {
    local slug="$1"
    local season="$2"
    local episode="$3"

    local hosters
    hosters=$(get_hoster_links "$slug" "$season" "$episode")

    if [ -z "$hosters" ]; then
        return 1
    fi

    # Sortiere Hoster nach Score (gleiche Logik wie select_and_save_hoster)
    local sorted_hosters
    sorted_hosters=$(echo "$hosters" | awk -v pref="$LANG_PREFERENCE" -F'|' '
        function language_score(lang) {
            if (pref == "GerSub") {
                if (lang == "GerSub") return 300
                if (lang == "GerDub") return 200
                if (lang == "EngSub") return 100
            } else if (pref == "EngSub") {
                if (lang == "EngSub") return 300
                if (lang == "GerSub") return 200
                if (lang == "GerDub") return 100
            } else {
                if (lang == "GerDub") return 300
                if (lang == "GerSub") return 200
                if (lang == "EngSub") return 100
            }
            return 0
        }
        function quality_score(qual) {
            if (qual == "1080p") return 5
            if (qual == "720p") return 4
            if (qual == "480p") return 3
            if (qual == "HD") return 2
            return 1
        }
        function hoster_score(hoster) {
            if (tolower(hoster) ~ /vidmoly/) return 50
            if (tolower(hoster) ~ /voe/) return 40
            if (tolower(hoster) ~ /filemoon/) return 5
            if (tolower(hoster) ~ /streamtape/) return 5
            if (tolower(hoster) ~ /doodstream/) return 5
            return 1
        }
        {
            lang_score = language_score($3)
            qual_score = quality_score($4)
            host_score = hoster_score($2)
            total = (lang_score * 10000) + (qual_score * 100) + host_score
            print total "|" $0
        }
    ' | sort -t'|' -k1 -nr | cut -d'|' -f2-)

    # Probiere jeden Hoster der Reihe nach
    while IFS='|' read -r hoster_id hoster_name language quality; do
        [ -z "$hoster_id" ] && continue

        if [ -n "${DEBUG:-}" ]; then
            echo "DEBUG: Trying hoster $hoster_name (ID: $hoster_id)" >&2
        fi

        show_info "Versuche ${hoster_name}..."

        local video_url
        video_url=$(extract_video_url "$hoster_id")

        if [ -n "$video_url" ]; then
            # Baue Hoster-Anzeigename
            local display_name="$hoster_name"
            if [ "$language" != "N/A" ] && [ -n "$language" ]; then
                display_name="${display_name} [${language}]"
            fi
            if [ "$quality" != "N/A" ] && [ -n "$quality" ]; then
                display_name="${display_name} [${quality}]"
            fi

            echo "$video_url"
            echo "$display_name"
            return 0
        fi

        if [ -n "${DEBUG:-}" ]; then
            echo "DEBUG: Hoster $hoster_name failed, trying next..." >&2
        fi
    done <<< "$sorted_hosters"

    show_error "Kein funktionierender Hoster gefunden"
    return 1
}

# Hole Video-URL für Episode (zentralisiert mit Loading-Nachrichten)
get_video_for_episode() {
    local slug="$1"
    local season="$2"
    local episode="$3"

    show_loading "Suche verfügbare Hoster für Episode ${episode}"

    # Automatische Auswahl & Fallback (GerDub → GerSub → EngSub)
    local result
    result=$(extract_video_with_fallback "$slug" "$season" "$episode")
    local video_url
    video_url=$(echo "$result" | sed -n '1p')
    local used_hoster
    used_hoster=$(echo "$result" | sed -n '2p')

    clear_loading

    if [ -z "$video_url" ]; then
        show_error "Keine funktionierende Quelle für Episode ${episode} gefunden."
        return 1
    fi

    # Zeige an, welcher Hoster & welche Sprache verwendet wird
    show_info "▶️  Verwende: ${used_hoster}"
    echo "$video_url"
    return 0
}
