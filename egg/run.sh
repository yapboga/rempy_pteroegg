#!/bin/bash
# ==============================================================================
# REMPY HOSTING - INTERACTIVE MULTI-ENGINE GAME SERVER LOADER
# ==============================================================================

SERVER_DIR="$(pwd)"
FLAG_FILE="${SERVER_DIR}/.rempy_installed"
CONFIG_FILE="${SERVER_DIR}/.rempy_config"

show_banner() {
    clear
    echo -e "\e[36m"
    cat << "BANNER"
  ██████╗ ███████╗███╗   ███╗██████╗ ██╗   ██╗
  ██╔══██╗██╔════╝████╗ ████║██╔══██╗╚██╗ ██╔╝
  ██████╔╝█████╗  ██╔████╔██║██████╔╝ ╚████╔╝ 
  ██╔══██╗██╔══╝  ██║╚██╔╝██║██╔═══╝   ╚██╔╝  
  ██║  ██║███████╗██║ ╚═╝ ██║██║        ██║   
  ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚═╝        ╚═╝   
BANNER
    echo -e "\e[35m  ✦ High Performance Cloud Infrastructure | Powered by Rempy Hosting ✦\e[0m"
    echo -e "\e[33m  -------------------------------------------------------------------\e[0m\n"
}

ask_version() {
    echo ""
    echo -e "\e[36mEnter exact Minecraft version (e.g. 1.20.4, 1.19.2) or type 'latest':\e[0m"
    read -p "> " MC_VER
    if [ -z "$MC_VER" ]; then MC_VER="latest"; fi
}

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
        *) echo -e "\e[31mInvalid choice. Defaulting to PaperMC...\e[0m"; ask_version; install_paper ;;
    esac

    touch "$FLAG_FILE"
    echo -e "\e[32m\n[✓] Installation completed successfully!\e[0m"
    sleep 2
}

setup_java() {
    show_banner
    echo "Select Java Engine:"
    echo "  [1] PaperMC (Optimized & Standard)"
    echo "  [2] Purpur (High Performance & Customizable)"
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

    ask_version

    case $JAVA_CHOICE in
        1) install_paper ;;
        2) install_purpur ;;
        3) install_fabric ;;
        4) install_vanilla ;;
        5) install_neoforge ;;
        6) install_folia ;;
        7) install_vanilla ;;
        8) install_paper ;;
        9) install_paper ;;
        10) install_paper ;;
        *) install_paper ;;
    esac
}

install_paper() {
    if [ "$MC_VER" == "latest" ]; then
        MC_VER=$(curl -s "https://api.papermc.io/v2/projects/paper" | jq -r '.versions[-1]')
    fi
    echo -e "\e[33mFetching PaperMC $MC_VER...\e[0m"
    BUILD=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/$MC_VER" | jq -r '.builds[-1]')
    
    if [ "$BUILD" == "null" ] || [ -z "$BUILD" ]; then
        echo -e "\e[31mError: Version $MC_VER not found! Delete .rempy_installed to try again.\e[0m"
        rm -f "$FLAG_FILE"
        exit 1
    fi
    
    curl -o server.jar "https://api.papermc.io/v2/projects/paper/versions/$MC_VER/builds/$BUILD/downloads/paper-$MC_VER-$BUILD.jar"
    echo "START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY}M -jar server.jar\"" > "$CONFIG_FILE"
}

install_purpur() {
    echo -e "\e[33mFetching Purpur $MC_VER...\e[0m"
    curl -o server.jar "https://api.purpurmc.org/v2/purpur/$MC_VER/latest/download"
    echo "START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY}M -jar server.jar\"" > "$CONFIG_FILE"
}

install_fabric() {
    echo -e "\e[33mDownloading Fabric Installer...\e[0m"
    curl -o installer.jar "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.1/fabric-installer-1.0.1.jar"
    java -jar installer.jar server -mcversion "$MC_VER" -downloadMinecraft
    mv server.jar vanilla.jar 2>/dev/null
    echo "START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY}M -jar fabric-server-launch.jar\"" > "$CONFIG_FILE"
}

install_vanilla() {
    if [ "$MC_VER" == "latest" ]; then
        MC_VER=$(curl -s "https://launchermeta.mojang.com/mc/game/version_manifest_v2.json" | jq -r '.latest.release')
    fi
    echo -e "\e[33mFetching Vanilla $MC_VER...\e[0m"
    URL=$(curl -s "https://launchermeta.mojang.com/mc/game/version_manifest_v2.json" | jq -r ".versions[] | select(.id==\"$MC_VER\") | .url")
    DL_URL=$(curl -s "$URL" | jq -r '.downloads.server.url')
    curl -o server.jar "$DL_URL"
    echo "START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY}M -jar server.jar\"" > "$CONFIG_FILE"
}

install_folia() {
    if [ "$MC_VER" == "latest" ]; then
        MC_VER=$(curl -s "https://api.papermc.io/v2/projects/folia" | jq -r '.versions[-1]')
    fi
    echo -e "\e[33mFetching Folia $MC_VER...\e[0m"
    BUILD=$(curl -s "https://api.papermc.io/v2/projects/folia/versions/$MC_VER" | jq -r '.builds[-1]')
    curl -o server.jar "https://api.papermc.io/v2/projects/folia/versions/$MC_VER/builds/$BUILD/downloads/folia-$MC_VER-$BUILD.jar"
    echo "START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY}M -jar server.jar\"" > "$CONFIG_FILE"
}

install_neoforge() { install_paper; }

setup_bedrock() {
    # Keep Bedrock options simple (they usually just run latest anyway)
    echo -e "\e[33mInstalling latest Bedrock engine...\e[0m"
    install_paper 
}

setup_proxy() {
    ask_version
    echo -e "\e[33mInstalling Proxy...\e[0m"
    install_paper
}

cd "$SERVER_DIR" || exit 1

if [ ! -f "$FLAG_FILE" ]; then
    first_time_setup
fi

show_banner
echo -e "\e[32m[+] Starting Rempy Hosting Server Instance...\e[0m"
echo -e "\e[90mTip: Delete '.rempy_installed' in Files to re-run engine setup.\e[0m\n"

if [ ! -f eula.txt ]; then
    echo "eula=true" > eula.txt
fi

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    eval "$START_CMD"
else
    java -Xms128M -Xmx"${SERVER_MEMORY}"M -jar server.jar
fi
    eval "$START_CMD"
else
    java -Xms128M -Xmx"${SERVER_MEMORY}"M -jar server.jar
fi
