#!/bin/sh
# ==============================================================================
# REMPY HOSTING - MENU-DRIVEN GAME SERVER LOADER
# ==============================================================================

SERVER_DIR="$(pwd)"
FLAG_FILE="${SERVER_DIR}/.rempy_installed"
CONFIG_FILE="${SERVER_DIR}/.rempy_config"

# Self-healing check
if [ ! -f "run.sh" ]; then
    echo "Restoring missing run.sh from GitHub..."
    curl -sSL -o run.sh "https://raw.githubusercontent.com/yapboga/rempy_pteroegg/refs/heads/main/egg/run.sh?cb=$(date +%s)"
    chmod +x run.sh
fi

show_banner() {
    clear
    echo "\033[36m"
    cat << "BANNER"
  ██████╗ ███████╗███╗   ███╗██████╗ ██╗   ██╗
  ██╔══██╗██╔════╝████╗ ████║██╔══██╗╚██╗ ██╔╝
  ██████╔╝█████╗  ██╔████╔██║██████╔╝ ╚████╔╝ 
  ██╔══██╗██╔══╝  ██║╚██╔╝██║██╔═══╝   ╚██╔╝  
  ██║  ██║███████╗██║ ╚═╝ ██║██║        ██║   
  ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚═╝        ╚═╝   
BANNER
    echo "\033[35m  ✦ High Performance Cloud Infrastructure | Powered by Rempy Hosting ✦\033[0m"
    echo "\033[33m  -------------------------------------------------------------------\033[0m\n"
}

boot_animation() {
    echo "\033[36m[i] Initializing Rempy Virtual Environment...\033[0m"
    printf "\033[90mBooting:\033[0m \033[35m[\033[0m"
    
    i=1
    while [ $i -le 25 ]; do
        printf "\033[32m█\033[0m"
        sleep 0.04
        i=$((i + 1))
    done
    
    echo "\033[35m]\033[0m \033[32m100%\033[0m"
    echo "\033[32m[✓] System Ready. Handing over to Game Engine...\033[0m\n"
    sleep 0.5
}

first_time_setup() {
    show_banner
    echo "\033[32m[+] Welcome to Rempy Hosting! Let's set up your server software.\033[0m\n"
    echo "Select your server category:"
    echo "  [1] Java Edition (Minecraft Server Engines)"
    echo "  [2] Bedrock Edition (Mobile / Console / Cross-play)"
    echo "  [3] Proxy Server (Network & Bungee / Velocity)"
    echo ""
    printf "Enter choice (1-3): "
    read CAT_CHOICE

    case "$CAT_CHOICE" in
        1) setup_java ;;
        2) setup_bedrock ;;
        3) setup_proxy ;;
        *) echo "\033[31mInvalid choice. Defaulting to PaperMC...\033[0m"; install_paper_menu ;;
    esac

    touch "$FLAG_FILE"
    echo "\033[32m\n[✓] Installation completed successfully!\033[0m"
    sleep 2
}

setup_java() {
    show_banner
    echo "Select Java Engine:"
    echo "  [1] PaperMC (Optimized & Standard)"
    echo "  [2] Purpur (High Performance & Customizable)"
    echo "  [3] Fabric (Lightweight Modded Engine)"
    echo "  [4] Vanilla (Official Mojang Release)"
    echo ""
    printf "Enter choice (1-4): "
    read JAVA_CHOICE

    case "$JAVA_CHOICE" in
        1) install_paper_menu ;;
        2) install_purpur_menu ;;
        3) install_fabric_menu ;;
        4) install_vanilla_menu ;;
        *) install_paper_menu ;;
    esac
}

# --- PAPER VERSION MENU ---
install_paper_menu() {
    show_banner
    echo "Select PaperMC Version:"
    echo "  [1] 26.2 (Latest 2026 Release)"
    echo "  [2] 26.1.1"
    echo "  [3] 1.21.1 (Stable Classic)"
    echo "  [4] 1.20.4"
    echo ""
    printf "Enter choice (1-4): "
    read VER_CHOICE

    case "$VER_CHOICE" in
        1) MC_VER="26.2"; BUILD="1" ;;
        2) MC_VER="26.1.1"; BUILD="1" ;;
        3) MC_VER="1.21.1"; BUILD="135" ;;
        4) MC_VER="1.20.4"; BUILD="498" ;;
        *) MC_VER="1.21.1"; BUILD="135" ;;
    esac

    echo "\033[33mDownloading PaperMC $MC_VER (Build $BUILD)...\033[0m"
    curl -o server.jar "https://api.papermc.io/v2/projects/paper/versions/$MC_VER/builds/$BUILD/downloads/paper-$MC_VER-$BUILD.jar"
    
    if [ ! -f server.jar ] || [ ! -s server.jar ]; then
        curl -o server.jar "https://api.papermc.io/v2/projects/paper/versions/1.21.1/builds/135/downloads/paper-1.21.1-135.jar"
    fi

    echo "START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY:-1024}M -jar server.jar\"" > "$CONFIG_FILE"
}

# --- PURPUR VERSION MENU ---
install_purpur_menu() {
    show_banner
    echo "Select Purpur Version:"
    echo "  [1] Latest (Auto-update)"
    echo "  [2] 1.21.1"
    echo ""
    printf "Enter choice (1-2): "
    read P_CHOICE
    
    P_VER="latest"
    if [ "$P_CHOICE" = "2" ]; then P_VER="1.21.1"; fi

    echo "\033[33mDownloading Purpur ($P_VER)...\033[0m"
    curl -o server.jar "https://api.purpurmc.org/v2/purpur/$P_VER/latest/download"
    echo "START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY:-1024}M -jar server.jar\"" > "$CONFIG_FILE"
}

# --- FABRIC VERSION MENU ---
install_fabric_menu() {
    show_banner
    echo "Select Fabric Version:"
    echo "  [1] 26.2"
    echo "  [2] 1.21.1"
    echo ""
    printf "Enter choice (1-2): "
    read F_CHOICE

    F_VER="1.21.1"
    if [ "$F_CHOICE" = "1" ]; then F_VER="26.2"; fi

    echo "\033[33mDownloading Vanilla base for Fabric ($F_VER)...\033[0m"
    curl -o server.jar "https://piston-data.mojang.com/v1/objects/4553255959957245d7d13028c249a0e4479e0018/server.jar" 2>/dev/null
    
    echo "\033[33mInstalling Fabric Installer...\033[0m"
    curl -o installer.jar "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.1/fabric-installer-1.0.1.jar"
    java -jar installer.jar server -mcversion "$F_VER" -downloadMinecraft
    
    echo "START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY:-1024}M -jar fabric-server-launch.jar\"" > "$CONFIG_FILE"
}

# --- VANILLA VERSION MENU ---
install_vanilla_menu() {
    show_banner
    echo "Select Vanilla Version:"
    echo "  [1] 1.21.1"
    echo ""
    printf "Enter choice [1]: "
    read V_CHOICE

    echo "\033[33mDownloading Vanilla...\033[0m"
    curl -o server.jar "https://piston-data.mojang.com/v1/objects/4553255959957245d7d13028c249a0e4479e0018/server.jar"
    echo "START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY:-1024}M -jar server.jar\"" > "$CONFIG_FILE"
}

install_bedrock() { install_paper_menu; }
install_proxy() { install_paper_menu; }

# --- MAIN EXECUTION ---
cd "$SERVER_DIR" || exit 1

if [ ! -f "$FLAG_FILE" ]; then
    touch "$FLAG_FILE"
    first_time_setup
fi

show_banner
boot_animation
echo "\033[90mTip: Delete '.rempy_installed' in Files to re-run engine setup.\033[0m\n"

if [ ! -f eula.txt ]; then
    echo "eula=true" > eula.txt
fi

if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
    eval "$START_CMD"
else
    java -Xms128M -Xmx"${SERVER_MEMORY:-1024}"M -jar server.jar
fi
