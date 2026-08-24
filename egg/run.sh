#!/usr/bin/env bash
# ==============================================================================
#  REMPY HOSTING — MULTI-EGG MINECRAFT LOADER (v2.1 — FIXED)
#  Java / Bedrock / Proxy installer with fully dynamic, always-current version
#  menus. No hardcoded builds — everything is pulled live from the official
#  download APIs at install time, so the egg never goes stale.
#
#  FIXES IN v2.1:
#  - Proper jq error handling (validate JSON before parsing)
#  - curl -f removed (was silently failing on HTTP errors)
#  - API response validation and diagnostic output
#  - Graceful fallbacks when APIs are unavailable
#  - Better timeout handling
# ==============================================================================

if [ -z "${BASH_VERSION:-}" ]; then
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    else
        echo "This script requires bash, which was not found in this container." >&2
        exit 1
    fi
fi

set -u

SERVER_DIR="$(pwd)"
FLAG_FILE="${SERVER_DIR}/.rempy_installed"
CONFIG_FILE="${SERVER_DIR}/.rempy_config"
DEBUG="${DEBUG:-0}"

UA="RempyHosting-Installer/2.1 (+https://rempy.hosting; admin@rempy.hosting)"

# ==============================================================================
# COLOR PALETTE
# ==============================================================================
B1="\033[38;5;25m"
B2="\033[38;5;27m"
B3="\033[38;5;33m"
B4="\033[38;5;39m"
CY="\033[38;5;51m"
WH="\033[97m"
GY="\033[38;5;245m"
GN="\033[38;5;46m"
YL="\033[38;5;220m"
RD="\033[38;5;203m"
BD="\033[1m"
RS="\033[0m"

# ==============================================================================
# LOW-LEVEL HELPERS
# ==============================================================================

hr()   { echo -e "${B1}  ────────────────────────────────────────────────────────────${RS}"; }
pause(){ printf "\n%b  Press [Enter] to continue...%b" "$GY" "$RS"; read -r _; }

show_banner() {
    clear
    echo -e "${B1}"
    cat << "BANNER"
  ██████╗ ███████╗███╗   ███╗██████╗ ██╗   ██╗
  ██╔══██╗██╔════╝████╗ ████║██╔══██╗╚██╗ ██╔╝
  ██████╔╝█████╗  ██╔████╔██║██████╔╝ ╚████╔╝
  ██╔══██╗██╔══╝  ██║╚██╔╝██║██╔═══╝   ╚██╔╝
  ██║  ██║███████╗██║ ╚═╝ ██║██║        ██║
  ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚═╝        ╚═╝
BANNER
    echo -e "${RS}${CY}${BD}       High Performance Cloud Infrastructure${RS}"
    echo -e "${B4}              ✦ Powered by Rempy Hosting ✦${RS}"
    echo -e "${B2}  ────────────────────────────────────────────────────────────${RS}\n"
}

spinner() {
    local pid=$1 msg=$2
    local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    tput civis 2>/dev/null
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i + 1) % ${#frames} ))
        printf "\r%b  %s %b%s%b   " "$B4" "${frames:$i:1}" "$CY" "$msg" "$RS" >&2
        sleep 0.08
    done
    tput cnorm 2>/dev/null
    printf "\r\033[K" >&2
}

run_with_spinner() {
    local msg="$1"; shift
    local tmp
    tmp="$(mktemp)"
    ("$@" > "$tmp" 2>/dev/null) &
    local pid=$!
    spinner "$pid" "$msg"
    wait "$pid"
    local rc=$?
    cat "$tmp"
    rm -f "$tmp"
    return $rc
}

boot_animation() {
    echo -e "${B3}[i] Initializing Rempy Virtual Environment...${RS}"
    printf "%b Booting: %b[%b" "$GY" "$B2" "$RS"
    local i=1
    while [ $i -le 30 ]; do
        printf "%b█%b" "$CY" "$RS"
        sleep 0.025
        i=$((i + 1))
    done
    echo -e "${B2}]${RS} ${GN}100%${RS}"
    echo -e "${GN}[✓] System Ready. Handing over to Game Engine...${RS}\n"
    sleep 0.3
}

install_progress_banner() {
    echo -e "\n${B2}  ╔═══════════════════════════════════════════════════════════╗${RS}"
    echo -e "${B2}  ║${RS}  ${CY}${BD}$1${RS}"
    echo -e "${B2}  ╚═══════════════════════════════════════════════════════════╝${RS}\n"
}

need_bin() {
    command -v "$1" >/dev/null 2>&1
}

# FIXED: Removed -f flag, added error checking and diagnostics
http_get() {
    local url="$1"
    local timeout="${2:-10}"
    local response
    local http_code
    
    response=$(curl -sS -w "\n%{http_code}" -A "$UA" \
        --retry 2 --retry-delay 1 --connect-timeout "$timeout" \
        "$url" 2>&1)
    
    http_code=$(echo "$response" | tail -n1)
    response=$(echo "$response" | head -n-1)
    
    if [ "$http_code" != "200" ]; then
        if [ "$DEBUG" = "1" ]; then
            echo -e "${YL}[DEBUG] HTTP $http_code from $url${RS}" >&2
            echo -e "${YL}[DEBUG] Response: ${response:0:200}${RS}" >&2
        fi
        return 1
    fi
    
    echo "$response"
    return 0
}

# FIXED: Validate JSON before piping to jq
validate_json() {
    local data="$1"
    if [ -z "$data" ]; then
        return 1
    fi
    echo "$data" | jq empty 2>/dev/null
}

LOCAL_BIN="${SERVER_DIR}/.rempy_bin"
mkdir -p "$LOCAL_BIN" 2>/dev/null
case ":$PATH:" in
    *":$LOCAL_BIN:"*) ;;
    *) PATH="$LOCAL_BIN:$PATH" ;;
esac
export PATH

apt_install_if_root() {
    [ "$(id -u 2>/dev/null)" = "0" ] || return 1
    need_bin apt-get || return 1
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y -qq "$1" >/dev/null 2>&1
    need_bin "$1"
}

ensure_jq() {
    need_bin jq && return 0
    echo -e "${YL}[!] 'jq' not found, attempting install...${RS}"
    if apt_install_if_root jq; then
        echo -e "${GN}[✓] jq installed via apt.${RS}"
        return 0
    fi
    echo -e "${GY}    Fetching a static jq binary instead (no root required)...${RS}"
    local arch
    case "$(uname -m)" in
        x86_64|amd64)  arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)             arch="amd64" ;;
    esac
    curl -sS -A "$UA" -o "${LOCAL_BIN}/jq" \
        "https://github.com/jqlang/jq/releases/latest/download/jq-linux-${arch}" 2>/dev/null
    chmod +x "${LOCAL_BIN}/jq" 2>/dev/null
    if need_bin jq; then
        echo -e "${GN}[✓] jq installed to ${LOCAL_BIN}.${RS}"
        return 0
    fi
    echo -e "${RD}[✗] Required tool 'jq' is missing and could not be auto-installed.${RS}"
    echo -e "${RD}    Please add it to your egg's Docker image and re-run.${RS}"
    exit 1
}

extract_zip() {
    local zipfile="$1" destdir="$2"
    mkdir -p "$destdir"
    if need_bin unzip; then
        unzip -o -q "$zipfile" -d "$destdir"
        return $?
    fi
    apt_install_if_root unzip && { unzip -o -q "$zipfile" -d "$destdir"; return $?; }
    if need_bin jar; then
        echo -e "${GY}    'unzip' unavailable — extracting with JDK's 'jar' tool.${RS}"
        ( cd "$destdir" && jar xf "$(cd "$(dirname "$zipfile")" && pwd)/$(basename "$zipfile")" )
        return $?
    fi
    if need_bin python3; then
        echo -e "${GY}    'unzip' unavailable — extracting with python3.${RS}"
        python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$zipfile" "$destdir"
        return $?
    fi
    echo -e "${RD}[✗] No tool available to extract .zip files.${RS}"
    return 1
}

ensure_dependencies() {
    if ! need_bin curl; then
        echo -e "${RD}[✗] 'curl' is missing from this image.${RS}"
        exit 1
    fi
    ensure_jq
}

# FIXED: Better pagination with error handling
CHOICE=""
paginate_and_select() {
    local title="$1"
    local raw="$2"
    local page_size=10
    local -a arr=()
    while IFS= read -r line; do
        [ -n "$line" ] && arr+=("$line")
    done <<< "$raw"

    local total=${#arr[@]}
    if [ "$total" -eq 0 ]; then
        echo -e "${RD}  [✗] No entries returned. Check network / API status.${RS}"
        pause
        CHOICE=""
        return 1
    fi

    local total_pages=$(( (total + page_size - 1) / page_size ))
    local page=0

    while true; do
        show_banner
        echo -e "${B4}${BD}  $title${RS}"
        echo -e "${GY}  Page $((page+1))/${total_pages}   •   ${total} total   •   [N]ext [P]rev [B]ack${RS}"
        hr
        local start=$((page * page_size))
        local end=$((start + page_size))
        [ "$end" -gt "$total" ] && end=$total

        local idx
        for (( idx=start; idx<end; idx++ )); do
            printf "  ${CY}[%2d]${RS}  ${WH}%s${RS}\n" "$((idx - start + 1))" "${arr[$idx]}"
        done
        echo ""
        printf "${B2}  ➤ Select: ${RS}"
        read -r sel

        case "$sel" in
            [Nn]|[Nn][Ee][Xx][Tt]) [ $page -lt $((total_pages - 1)) ] && page=$((page + 1)) ;;
            [Pp]|[Pp][Rr][Ee][Vv]) [ $page -gt 0 ] && page=$((page - 1)) ;;
            [Bb]|[Bb][Aa][Cc][Kk]) CHOICE=""; return 1 ;;
            ''|*[!0-9]*) continue ;;
            *)
                if [ "$sel" -ge 1 ] && [ "$sel" -le $((end - start)) ]; then
                    CHOICE="${arr[$((start + sel - 1))]}"
                    return 0
                fi
                ;;
        esac
    done
}

write_config() {
    cat > "$CONFIG_FILE" << EOF
SERVER_TYPE="$1"
ENGINE_NAME="$2"
MC_VERSION="$3"
START_CMD='$4'
EOF
}

# ==============================================================================
# JAVA EDITION — PAPER (FIXED API HANDLING)
# ==============================================================================
install_paper() {
    install_progress_banner "PaperMC — fetching live version index"
    local data
    data=$(run_with_spinner "Talking to fill.papermc.io ..." http_get "https://fill.papermc.io/v3/projects/paper")
    
    if ! validate_json "$data"; then
        echo -e "${RD}[✗] Could not reach the PaperMC Fill API or got invalid response.${RS}"
        echo -e "${RD}    The API may be down. Try again later.${RS}"
        pause; return 1
    fi

    local groups
    groups=$(echo "$data" | jq -r '.versions | keys[]' 2>/dev/null | sort -V -r)
    if [ -z "$groups" ]; then
        echo -e "${RD}[✗] Could not parse version data from PaperMC API.${RS}"
        pause; return 1
    fi
    
    paginate_and_select "PaperMC — select a major version family" "$groups" || return 1
    local GROUP="$CHOICE"

    local versions
    versions=$(echo "$data" | jq -r --arg g "$GROUP" '.versions[$g][]' 2>/dev/null | sort -V -r)
    if [ -z "$versions" ]; then
        echo -e "${RD}[✗] No versions found for $GROUP.${RS}"
        pause; return 1
    fi
    
    paginate_and_select "PaperMC $GROUP — select an exact release" "$versions" || return 1
    local VERSION="$CHOICE"

    install_progress_banner "PaperMC $VERSION — resolving latest stable build"
    local builds
    builds=$(run_with_spinner "Fetching build list..." http_get "https://fill.papermc.io/v3/projects/paper/versions/${VERSION}/builds")
    
    if ! validate_json "$builds"; then
        echo -e "${RD}[✗] Could not fetch build list for $VERSION.${RS}"
        pause; return 1
    fi
    
    local DL_URL
    DL_URL=$(echo "$builds" | jq -r '[.[] | select(.channel=="STABLE")] | sort_by(.id) | last | .downloads."server:default".url // empty' 2>/dev/null)
    if [ -z "$DL_URL" ]; then
        DL_URL=$(echo "$builds" | jq -r 'sort_by(.id) | last | .downloads."server:default".url // empty' 2>/dev/null)
        [ -n "$DL_URL" ] && echo -e "${YL}[!] No STABLE build for $VERSION yet — using latest available.${RS}"
    fi
    
    if [ -z "$DL_URL" ]; then
        echo -e "${RD}[✗] No downloadable build found for $VERSION.${RS}"
        pause; return 1
    fi

    echo -e "${CY}[i] Downloading Paper $VERSION ...${RS}"
    curl -A "$UA" -# -L -o server.jar "$DL_URL"
    write_config "java" "PaperMC" "$VERSION" 'java -Xms128M -Xmx${SERVER_MEMORY:-1024}M -jar server.jar --nogui'
}

# ==============================================================================
# JAVA EDITION — PURPUR (FIXED)
# ==============================================================================
install_purpur() {
    install_progress_banner "Purpur — fetching live version index"
    local data
    data=$(run_with_spinner "Talking to api.purpurmc.org ..." http_get "https://api.purpurmc.org/v2/purpur")
    
    if ! validate_json "$data"; then
        echo -e "${RD}[✗] Could not reach Purpur API or got invalid response.${RS}"
        echo -e "${RD}    The API may be down or rate-limiting. Try again later.${RS}"
        pause; return 1
    fi

    local versions
    versions=$(echo "$data" | jq -r '.versions[]' 2>/dev/null | sort -V -r)
    if [ -z "$versions" ]; then
        echo -e "${RD}[✗] No versions found in Purpur API response.${RS}"
        pause; return 1
    fi
    
    paginate_and_select "Purpur — select a Minecraft version" "$versions" || return 1
    local VERSION="$CHOICE"

    echo -e "${CY}[i] Downloading Purpur $VERSION (latest build) ...${RS}"
    curl -A "$UA" -# -L -o server.jar "https://api.purpurmc.org/v2/purpur/${VERSION}/latest/download"
    write_config "java" "Purpur" "$VERSION" 'java -Xms128M -Xmx${SERVER_MEMORY:-1024}M -jar server.jar --nogui'
}

# ==============================================================================
# JAVA EDITION — FABRIC (FIXED)
# ==============================================================================
install_fabric() {
    install_progress_banner "Fabric — fetching live game version index"

    show_banner
    echo -e "${B4}${BD}  Fabric — show which versions?${RS}"
    hr
    echo -e "  ${CY}[1]${RS}  Stable releases only ${GY}(recommended)${RS}"
    echo -e "  ${CY}[2]${RS}  Everything, including snapshots"
    printf "\n${B2}  ➤ Select: ${RS}"
    read -r stab_choice

    local data filter
    data=$(run_with_spinner "Talking to meta.fabricmc.net ..." http_get "https://meta.fabricmc.net/v2/versions/game")
    
    if ! validate_json "$data"; then
        echo -e "${RD}[✗] Could not reach Fabric meta API.${RS}"
        pause; return 1
    fi
    
    if [ "$stab_choice" = "2" ]; then
        filter='.[] | .version'
    else
        filter='.[] | select(.stable==true) | .version'
    fi
    
    local versions
    versions=$(echo "$data" | jq -r "$filter" 2>/dev/null)
    if [ -z "$versions" ]; then
        echo -e "${RD}[✗] No versions found in Fabric API response.${RS}"
        pause; return 1
    fi
    
    paginate_and_select "Fabric — select a Minecraft version" "$versions" || return 1
    local GAME_VERSION="$CHOICE"

    install_progress_banner "Fabric $GAME_VERSION — resolving loader + installer"
    local loader_data loader_ver installer_data installer_ver
    loader_data=$(run_with_spinner "Fetching loader versions..." http_get "https://meta.fabricmc.net/v2/versions/loader/${GAME_VERSION}")
    
    if ! validate_json "$loader_data"; then
        echo -e "${RD}[✗] Could not fetch loader versions.${RS}"
        pause; return 1
    fi
    
    loader_ver=$(echo "$loader_data" | jq -r '[.[] | select(.loader.stable==true)] | .[0].loader.version // empty' 2>/dev/null)
    [ -z "$loader_ver" ] && loader_ver=$(echo "$loader_data" | jq -r '.[0].loader.version // empty' 2>/dev/null)

    installer_data=$(run_with_spinner "Fetching installer versions..." http_get "https://meta.fabricmc.net/v2/versions/installer")
    
    if ! validate_json "$installer_data"; then
        echo -e "${RD}[✗] Could not fetch installer versions.${RS}"
        pause; return 1
    fi
    
    installer_ver=$(echo "$installer_data" | jq -r '[.[] | select(.stable==true)] | .[0].version // empty' 2>/dev/null)
    [ -z "$installer_ver" ] && installer_ver=$(echo "$installer_data" | jq -r '.[0].version // empty' 2>/dev/null)

    if [ -z "$loader_ver" ] || [ -z "$installer_ver" ]; then
        echo -e "${RD}[✗] Could not resolve loader/installer pair for $GAME_VERSION.${RS}"
        pause; return 1
    fi

    echo -e "${CY}[i] Downloading Fabric server for $GAME_VERSION ...${RS}"
    curl -A "$UA" -# -L -o server.jar \
        "https://meta.fabricmc.net/v2/versions/loader/${GAME_VERSION}/${loader_ver}/${installer_ver}/server/jar"
    write_config "java" "Fabric" "$GAME_VERSION" 'java -Xms128M -Xmx${SERVER_MEMORY:-1024}M -jar server.jar --nogui'
}

# ==============================================================================
# JAVA EDITION — VANILLA (FIXED)
# ==============================================================================
install_vanilla() {
    install_progress_banner "Vanilla — fetching live Mojang version manifest"

    show_banner
    echo -e "${B4}${BD}  Vanilla — show which versions?${RS}"
    hr
    echo -e "  ${CY}[1]${RS}  Official releases only ${GY}(recommended)${RS}"
    echo -e "  ${CY}[2]${RS}  Everything, including snapshots"
    printf "\n${B2}  ➤ Select: ${RS}"
    read -r stab_choice

    local manifest filter
    manifest=$(run_with_spinner "Talking to piston-meta.mojang.com ..." http_get "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json")
    
    if ! validate_json "$manifest"; then
        echo -e "${RD}[✗] Could not reach Mojang's version manifest.${RS}"
        pause; return 1
    fi
    
    if [ "$stab_choice" = "2" ]; then
        filter='.versions[] | .id'
    else
        filter='.versions[] | select(.type=="release") | .id'
    fi
    
    local versions
    versions=$(echo "$manifest" | jq -r "$filter" 2>/dev/null)
    if [ -z "$versions" ]; then
        echo -e "${RD}[✗] No versions found in Mojang manifest.${RS}"
        pause; return 1
    fi
    
    paginate_and_select "Vanilla — select a Minecraft version" "$versions" || return 1
    local VERSION="$CHOICE"

    install_progress_banner "Vanilla $VERSION — resolving server jar"
    local ver_url ver_json dl_url
    ver_url=$(echo "$manifest" | jq -r --arg v "$VERSION" '.versions[] | select(.id==$v) | .url' 2>/dev/null)
    
    if [ -z "$ver_url" ]; then
        echo -e "${RD}[✗] Could not find version URL for $VERSION.${RS}"
        pause; return 1
    fi
    
    ver_json=$(run_with_spinner "Fetching release metadata..." http_get "$ver_url")
    
    if ! validate_json "$ver_json"; then
        echo -e "${RD}[✗] Could not fetch metadata for $VERSION.${RS}"
        pause; return 1
    fi
    
    dl_url=$(echo "$ver_json" | jq -r '.downloads.server.url // empty' 2>/dev/null)
    if [ -z "$dl_url" ]; then
        echo -e "${RD}[✗] This version has no server download available.${RS}"
        pause; return 1
    fi

    echo -e "${CY}[i] Downloading Vanilla $VERSION ...${RS}"
    curl -A "$UA" -# -L -o server.jar "$dl_url"
    write_config "java" "Vanilla" "$VERSION" 'java -Xms128M -Xmx${SERVER_MEMORY:-1024}M -jar server.jar --nogui'
}

# ==============================================================================
# BEDROCK EDITION
# ==============================================================================
install_bedrock() {
    install_progress_banner "Bedrock Dedicated Server — resolving latest build"
    echo -e "${GY}[i] Mojang does not publish a public JSON API for Bedrock, so this reads${RS}"
    echo -e "${GY}    the official download page directly.${RS}\n"

    local page bedrock_url
    page=$(run_with_spinner "Talking to minecraft.net ..." curl -sS -A "Mozilla/5.0 (X11; Linux x86_64) $UA" "https://www.minecraft.net/en-us/download/server/bedrock")
    bedrock_url=$(echo "$page" | grep -oE 'https://[^"'"'"']+bin-linux/bedrock-server-[^"'"'"']+\.zip' | head -n1)

    if [ -z "$bedrock_url" ]; then
        echo -e "${RD}[✗] Could not auto-detect the current Bedrock build.${RS}"
        echo -e "${YL}[i] Grab the Linux server manually from:${RS}"
        echo -e "    ${CY}https://www.minecraft.net/en-us/download/server/bedrock${RS}"
        printf "\n${B2}  ➤ Paste the direct .zip URL here (or leave blank to cancel): ${RS}"
        read -r bedrock_url
        [ -z "$bedrock_url" ] && { pause; return 1; }
    fi

    local fname; fname=$(basename "$bedrock_url")
    local ver; ver=$(echo "$fname" | grep -oE '[0-9]+(\.[0-9]+){2,3}')

    echo -e "${CY}[i] Downloading Bedrock Dedicated Server ${ver:-$fname} ...${RS}"
    curl -A "$UA" -# -L -o bedrock-server.zip "$bedrock_url"

    echo -e "${CY}[i] Unpacking ...${RS}"
    extract_zip bedrock-server.zip "$SERVER_DIR" && rm -f bedrock-server.zip
    chmod +x bedrock_server 2>/dev/null

    write_config "bedrock" "Bedrock Dedicated Server" "${ver:-unknown}" 'LD_LIBRARY_PATH=. ./bedrock_server'
}

# ==============================================================================
# PROXY — VELOCITY / BUNGEECORD
# ==============================================================================
install_velocity() {
    install_progress_banner "Velocity — fetching live version index"
    local data
    data=$(run_with_spinner "Talking to fill.papermc.io ..." http_get "https://fill.papermc.io/v3/projects/velocity")
    
    if ! validate_json "$data"; then
        echo -e "${RD}[✗] Could not reach the Velocity API.${RS}"
        pause; return 1
    fi

    local groups
    groups=$(echo "$data" | jq -r '.versions | keys[]' 2>/dev/null | sort -V -r)
    if [ -z "$groups" ]; then
        echo -e "${RD}[✗] No versions found.${RS}"
        pause; return 1
    fi
    
    paginate_and_select "Velocity — select a major version family" "$groups" || return 1
    local GROUP="$CHOICE"

    local versions
    versions=$(echo "$data" | jq -r --arg g "$GROUP" '.versions[$g][]' 2>/dev/null | sort -V -r)
    if [ -z "$versions" ]; then
        echo -e "${RD}[✗] No versions found for $GROUP.${RS}"
        pause; return 1
    fi
    
    paginate_and_select "Velocity $GROUP — select an exact release" "$versions" || return 1
    local VERSION="$CHOICE"

    local builds DL_URL
    builds=$(run_with_spinner "Fetching build list..." http_get "https://fill.papermc.io/v3/projects/velocity/versions/${VERSION}/builds")
    
    if ! validate_json "$builds"; then
        echo -e "${RD}[✗] Could not fetch build list.${RS}"
        pause; return 1
    fi
    
    DL_URL=$(echo "$builds" | jq -r '[.[] | select(.channel=="RECOMMENDED")] | sort_by(.id) | last | .downloads."server:default".url // empty' 2>/dev/null)
    [ -z "$DL_URL" ] && DL_URL=$(echo "$builds" | jq -r '[.[] | select(.channel=="STABLE")] | sort_by(.id) | last | .downloads."server:default".url // empty' 2>/dev/null)
    [ -z "$DL_URL" ] && DL_URL=$(echo "$builds" | jq -r 'sort_by(.id) | last | .downloads."server:default".url // empty' 2>/dev/null)

    if [ -z "$DL_URL" ]; then
        echo -e "${RD}[✗] No downloadable build found for Velocity $VERSION.${RS}"
        pause; return 1
    fi

    echo -e "${CY}[i] Downloading Velocity $VERSION ...${RS}"
    curl -A "$UA" -# -L -o server.jar "$DL_URL"
    write_config "proxy" "Velocity" "$VERSION" 'java -Xms128M -Xmx${SERVER_MEMORY:-1024}M -jar server.jar'
}

install_bungeecord() {
    install_progress_banner "BungeeCord — fetching latest CI build"
    echo -e "${CY}[i] Downloading latest successful BungeeCord build ...${RS}"
    curl -A "$UA" -# -L -o server.jar \
        "https://ci.md-5.net/job/BungeeCord/lastSuccessfulBuild/artifact/bootstrap/target/BungeeCord.jar"
    write_config "proxy" "BungeeCord" "latest" 'java -Xms128M -Xmx${SERVER_MEMORY:-1024}M -jar server.jar'
}

# ==============================================================================
# MENUS
# ==============================================================================
java_menu() {
    while true; do
        show_banner
        echo -e "${B4}${BD}  Java Edition — choose a server engine${RS}"
        hr
        echo -e "  ${CY}[1]${RS} ${WH}PaperMC${RS}   ${GY}— optimized, most plugin-compatible, best default${RS}"
        echo -e "  ${CY}[2]${RS} ${WH}Purpur${RS}    ${GY}— Paper fork with extra gameplay/config options${RS}"
        echo -e "  ${CY}[3]${RS} ${WH}Fabric${RS}    ${GY}— lightweight modding platform${RS}"
        echo -e "  ${CY}[4]${RS} ${WH}Vanilla${RS}   ${GY}— official unmodified Mojang server${RS}"
        echo -e "  ${CY}[B]${RS} ${GY}Back${RS}"
        printf "\n${B2}  ➤ Select: ${RS}"
        read -r c
        case "$c" in
            1) install_paper && return 0 ;;
            2) install_purpur && return 0 ;;
            3) install_fabric && return 0 ;;
            4) install_vanilla && return 0 ;;
            [Bb]) return 1 ;;
        esac
    done
}

proxy_menu() {
    while true; do
        show_banner
        echo -e "${B4}${BD}  Proxy Server — choose software${RS}"
        hr
        echo -e "  ${CY}[1]${RS} ${WH}Velocity${RS}    ${GY}— modern, fast, actively maintained (recommended)${RS}"
        echo -e "  ${CY}[2]${RS} ${WH}BungeeCord${RS}  ${GY}— legacy, widest plugin support${RS}"
        echo -e "  ${CY}[B]${RS} ${GY}Back${RS}"
        printf "\n${B2}  ➤ Select: ${RS}"
        read -r c
        case "$c" in
            1) install_velocity && return 0 ;;
            2) install_bungeecord && return 0 ;;
            [Bb]) return 1 ;;
        esac
    done
}

first_time_setup() {
    while true; do
        show_banner
        echo -e "${GN}${BD}  Welcome to Rempy Hosting!${RS} ${WH}Let's set up your server.${RS}"
        hr
        echo -e "  ${CY}[1]${RS} ${WH}Java Edition${RS}     ${GY}— PaperMC / Purpur / Fabric / Vanilla${RS}"
        echo -e "  ${CY}[2]${RS} ${WH}Bedrock Edition${RS}  ${GY}— mobile / console / cross-play${RS}"
        echo -e "  ${CY}[3]${RS} ${WH}Proxy Server${RS}     ${GY}— Velocity / BungeeCord${RS}"
        printf "\n${B2}  ➤ Select: ${RS}"
        read -r c

        case "$c" in
            1) java_menu && break ;;
            2) install_bedrock && break ;;
            3) proxy_menu && break ;;
            *) ;;
        esac
    done

    touch "$FLAG_FILE"
    echo -e "\n${GN}${BD}[✓] Installation completed successfully!${RS}"
    if [ -f "$CONFIG_FILE" ]; then
        . "$CONFIG_FILE"
        echo -e "${GY}    Engine:  ${WH}${ENGINE_NAME:-unknown}${RS}"
        echo -e "${GY}    Version: ${WH}${MC_VERSION:-unknown}${RS}"
    fi
    sleep 2
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================
cd "$SERVER_DIR" || exit 1
ensure_dependencies

if [ ! -f "$FLAG_FILE" ]; then
    first_time_setup
fi

show_banner
boot_animation

if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
    [ -n "${ENGINE_NAME:-}" ] && echo -e "${B4}  Engine   ${WH}${ENGINE_NAME}${RS}"
    [ -n "${MC_VERSION:-}" ] && echo -e "${B4}  Version  ${WH}${MC_VERSION}${RS}\n"
fi

echo -e "${GY}Tip: delete '.rempy_installed' in Files to re-run engine setup.${RS}\n"

if [ "${SERVER_TYPE:-java}" = "java" ] || [ "${SERVER_TYPE:-}" = "proxy" ]; then
    [ -f eula.txt ] || echo "eula=true" > eula.txt
fi

if [ -f "$CONFIG_FILE" ] && [ -n "${START_CMD:-}" ]; then
    eval "$START_CMD"
else
    echo -e "${RD}[✗] No start command found — installation may have failed.${RS}"
    echo -e "${RD}    Delete '.rempy_installed' in Files and re-run to try again.${RS}"
    exit 1
fi
