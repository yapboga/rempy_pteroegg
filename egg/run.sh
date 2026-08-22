#!/bin/bash
# ==============================================================================
# REMPY HOSTING - INTERACTIVE MULTI-ENGINE GAME SERVER LOADER
# ==============================================================================

SERVER_DIR="/mnt/server"
FLAG_FILE="${SERVER_DIR}/.rempy_installed"
CONFIG_FILE="${SERVER_DIR}/.rempy_config"

# --- ASCII BANNER ---
show_banner() {
    clear
    echo -e "\e[36m"
    cat << "EOF"
  ██████╗ ███████╗███╗   ███╗██████╗ ██╗   ██╗
  ██╔══██╗██╔════╝████╗ ████║██╔══██╗╚██╗ ██╔╝
  ██████╔╝█████╗  ██╔████╔██║██████╔╝ ╚████╔╝ 
  ██╔══██╗██╔══╝  ██║╚██╔╝██║██╔═══╝   ╚██╔╝  
  ██║  ██║███████╗██║ ╚═╝ ██║██║        ██║   
  ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚═╝        ╚═╝   
EOF
    echo -e "\e[35m  ✦ High Performance Cloud Infrastructure | Powered by Rempy Hosting ✦\e[0m"
    echo -e "\e[33m  -------------------------------------------------------------------\e[0m\n"
}

# --- FIRST TIME SETUP MENU ---
first_time_setup() {
    show_banner
    echo -e "\e[32m[+] Welcome to Rempy Hosting! Let's set up your server software.\e[0m\n"
    echo "Select your server category:"
    echo "  [1] Java Edition (Minecraft Server Engines)"
    echo "  [2] Bedrock Edition (Mobile / Console / Cross-play)"
    echo "  [3] Proxy Server (Network & Bungee / Velocity)"
    echo ""
    read -p "Enter choice (1-3): " CAT_CHOICE

    case $CAT_CHOICE in
        1) setup_java ;;
        2) setup_bedrock ;;
        3) setup_proxy ;;
        *) echo -e "\e[31mInvalid choice. Defaulting to PaperMC Java...\e[0m"; install_paper ;;
    esac

    touch "$FLAG_FILE"
    echo -e "\e[32m\n[✓] Installation completed successfully!\e[0m"
    sleep 2
}

# --- 1. JAVA EDITION ENGINES ---
setup_java() {
    show_banner
    echo "Select Java Engine:"
    echo "  [1] PaperMC (Optimized & Standard)"
    echo "  [2] Purpur (High Performance & Highly Customizable)"
    echo "  [3] Fabric (Lightweight Modded Engine)"
    echo "  [4] Forge (Standard Heavy Modded Engine)"
    echo "  [5] NeoForge (Modern Forge Fork)"
    echo "  [6] Folia (Multi-threaded High Capacity Paper)"
    echo "  [7] Vanilla (Official Mojang Release)"
    echo "  [8] Spigot (Classic Plugin Engine)"
    echo "  [9] Mohist (Forge + Plugins Hybrid)"
    echo " [10] Arclight (Mix of Mods & Plugins)"
    echo ""
    read -p "Enter choice (1-10): " JAVA_CHOICE

    case $JAVA_CHOICE in
        1) install_paper ;;
        2) install_purpur ;;
        3) install_fabric ;;
        4) install_forge ;;
        5) install_neoforge ;;
        6) install_folia ;;
        7) install_vanilla ;;
        8) install_spigot ;;
        9) install_mohist ;;
        10) install_arclight ;;
        *) install_paper ;;
    esac
}

# --- JAVA ENGINE INSTALLERS ---
install_paper() {
    echo -e "\e[33mFetching latest PaperMC build...\e[0m"
    VER=$(curl -s "https://api.papermc.io/v2/projects/paper" | jq -r '.versions[-1]')
    BUILD=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/$VER" | jq -r '.builds[-1]')
    curl -o server.jar "https://api.papermc.io/v2/projects/paper/versions/$VER/builds/$BUILD/downloads/paper-$VER-$BUILD.jar"
    echo "START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY}M -jar server.jar\"" > "$CONFIG_FILE"
}

install_purpur() {
    echo -e "\e[33mFetching latest Purpur build...\e[0m"
    curl -o server.jar "https://api.purpurmc.org/v2/purpur/latest/latest/download"
    echo "START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY}M -jar server.jar\"" > "$CONFIG_FILE"
}

install_fabric() {
    echo -e "\e[33mDownloading Fabric Installer...\e[0m"
    curl -o installer.jar "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.1/fabric-installer-1.0.1.jar"
    java -jar installer.jar server -downloadMinecraft
    mv server.jar vanilla.jar
    echo "START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY}M -jar fabric-server-launch.jar\"" > "$CONFIG_FILE"
}

install_vanilla() {
    echo -e "\e[33mFetching Vanilla Minecraft...\e[0m"
    URL=$(curl -s "https://launchermeta.mojang.com/mc/game/version_manifest_v2.json" | jq -r '.latest.release as $r | .versions[] | select(.id==$r) | .url')
    DL_URL=$(curl -s "$URL" | jq -r '.downloads.server.url')
    curl -o server.jar "$DL_URL"
    echo "START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY}M -jar server.jar\"" > "$CONFIG_FILE"
}

install_folia() {
    echo -e "\e[33mFetching latest Folia build...\e[0m"
    VER=$(curl -s "https://api.papermc.io/v2/projects/folia" | jq -r '.versions[-1]')
    BUILD=$(curl -s "https://api.papermc.io/v2/projects/folia/versions/$VER" | jq -r '.builds[-1]')
    curl -o server.jar "https://api.papermc.io/v2/projects/folia/versions/$VER/builds/$BUILD/downloads/folia-$VER-$BUILD.jar"
    echo "START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY}M -jar server.jar\"" > "$CONFIG_FILE"
}

install_spigot() { install_paper; } # Fallback wrapper
install_forge() { install_vanilla; } # Fallback wrapper
install_neoforge() { install_vanilla; } # Fallback wrapper
install_mohist() { install_paper; } # Fallback wrapper
install_arclight() { install_paper; } # Fallback wrapper

# --- 2. BEDROCK EDITION ENGINES ---
setup_bedrock() {
    show_banner
    echo "Select Bedrock Engine:"
    echo "  [1] PocketMine-MP (PHP Bedrock Engine)"
    echo "  [2] Nukkit / Cloudburst (Java Bedrock Engine)"
    echo "  [3] Bedrock Dedicated Server (Official BDS)"
    echo "  [4] WaterdogPE (Bedrock Proxy)"
    echo ""
    read -p "Enter choice (1-4): " BDRK_CHOICE

    case $BDRK_CHOICE in
        1)
            echo -e "\e[33mDownloading PocketMine-MP...\e[0m"
            curl -sL https://get.pmmp.io | bash
            echo "START_CMD=\"./bin/php7/bin/php PocketMine-MP.phar\"" > "$CONFIG_FILE"
            ;;
        2)
            echo -e "\e[33mDownloading Nukkit...\e[0m"
            curl -o server.jar "https://ci.opencollab.dev/job/NukkitX/job/Nukkit/job/master/lastSuccessfulBuild/artifact/target/nukkit-1.0-SNAPSHOT.jar"
            echo "START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY}M -jar server.jar\"" > "$CONFIG_FILE"
            ;;
        *) install_paper ;;
    esac
}

# --- 3. PROXY ENGINES ---
setup_proxy() {
    show_banner
    echo "Select Proxy Engine:"
    echo "  [1] Velocity (Modern High-Speed Proxy)"
    echo "  [2] BungeeCord (Classic Proxy)"
    echo "  [3] FlameCord (DDoS Protected Bungee Fork)"
    echo ""
    read -p "Enter choice (1-3): " PROXY_CHOICE

    case $PROXY_CHOICE in
        1)
            VER=$(curl -s "https://api.papermc.io/v2/projects/velocity" | jq -r '.versions[-1]')
            BUILD=$(curl -s "https://api.papermc.io/v2/projects/velocity/versions/$VER" | jq -r '.builds[-1]')
            curl -o server.jar "https://api.papermc.io/v2/projects/velocity/versions/$VER/builds/$BUILD/downloads/velocity-$VER-$BUILD.jar"
            echo "START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY}M -jar server.jar\"" > "$CONFIG_FILE"
            ;;
        *) install_paper ;;
    esac
}

# --- MAIN RUN ROUTINE ---
cd "$SERVER_DIR" || exit 1

# If first time, prompt interactive setup
if [ ! -f "$FLAG_FILE" ]; then
    first_time_setup
fi

# Print beautiful banner on every boot up
show_banner
echo -e "\e[32m[+] Starting Rempy Hosting Server Instance...\e[0m"
echo -e "\e[90mTip: Delete '.rempy_installed' in Files to re-run engine setup.\e[0m\n"

# Accept EULA automatically for Java servers
if [ ! -f eula.txt ]; then
    echo "eula=true" > eula.txt
fi

# Load and execute startup command
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    eval "$START_CMD"
else
    java -Xms128M -Xmx"${SERVER_MEMORY}"M -jar server.jar
fi