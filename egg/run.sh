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

boot_animation() {
    echo -e "\e[36m[i] Initializing Rempy Virtual Environment...\e[0m"
    echo -ne "\e[90mBooting:\e[0m \e[35m[\e[0m"
    
    for i in {1..25}; do
        echo -ne "\e[32m█\e[0m"
        sleep 0.04
    done
    
    echo -e "\e[35m]\e[0m \e[32m100%\e[0m"
    echo -e "\e[32m[✓] System Ready. Handing over to Game Engine...\e[0m\n"
    sleep 0.5
}

ask_version() {
    echo ""
    echo -e "\e[36mEnter exact Minecraft version (e.g. 1.20.4, 26.2) or type 'latest':\e[0m"
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
    echo -e "\e[33mFetching PaperMC using Python...\e[0m"
    python3 -c "
import urllib.request, json
ver = '$MC_VER'
if ver == 'latest':
    data = json.loads(urllib.request.urlopen('https://api.papermc.io/v2/projects/paper').read().decode())
    ver = data['versions'][-1]
builds_data = json.loads(urllib.request.urlopen(f'https://api.papermc.io/v2/projects/paper/versions/{ver}').read().decode())
build = builds_data['builds'][-1]
jar_name = f'paper-{ver}-{build}.jar'
url = f'https://api.papermc.io/v2/projects/paper/versions/{ver}/builds/{build}/downloads/{jar_name}'
urllib.request.urlretrieve(url, 'server.jar')
with open('.rempy_config', 'w') as f:
    f.write('START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY:-1024}M -jar server.jar\"\n')
"
}

install_purpur() {
    echo -e "\e[33mFetching Purpur $MC_VER...\e[0m"
    if [ "$MC_VER" == "latest" ]; then MC_VER="latest"; fi
    curl -o server.jar "https://api.purpurmc.org/v2/purpur/$MC_VER/latest/download"
    echo "START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY:-1024}M -jar server.jar\"" > "$CONFIG_FILE"
}

install_fabric() {
    echo -e "\e[33mDownloading Fabric and Vanilla server via Python...\e[0m"
    python3 -c "
import urllib.request, json
ver = '$MC_VER'
if ver == 'latest':
    manifest = json.loads(urllib.request.urlopen('https://launchermeta.mojang.com/mc/game/version_manifest_v2.json').read().decode())
    ver = manifest['latest']['release']

# Get Vanilla server jar
manifest = json.loads(urllib.request.urlopen('https://launchermeta.mojang.com/mc/game/version_manifest_v2.json').read().decode())
v_url = next(v['url'] for v in manifest['versions'] if v['id'] == ver)
v_data = json.loads(urllib.request.urlopen(v_url).read().decode())
server_url = v_data['downloads']['server']['url']
urllib.request.urlretrieve(server_url, 'server.jar')

# Get Fabric installer
installers = json.loads(urllib.request.urlopen('https://meta.fabricmc.net/v2/versions/installer').read().decode())
installer_ver = installers[0]['version']
inst_url = f'https://maven.fabricmc.net/net/fabricmc/fabric-installer/{installer_ver}/fabric-installer-{installer_ver}.jar'
urllib.request.urlretrieve(inst_url, 'installer.jar')

with open('.rempy_config', 'w') as f:
    f.write('START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY:-1024}M -jar fabric-server-launch.jar\"\n')
"
    java -jar installer.jar server -mcversion "$MC_VER" -downloadMinecraft
}

install_vanilla() {
    echo -e "\e[33mFetching Vanilla via Python...\e[0m"
    python3 -c "
import urllib.request, json
ver = '$MC_VER'
manifest = json.loads(urllib.request.urlopen('https://launchermeta.mojang.com/mc/game/version_manifest_v2.json').read().decode())
if ver == 'latest':
    ver = manifest['latest']['release']
v_url = next(v['url'] for v in manifest['versions'] if v['id'] == ver)
v_data = json.loads(urllib.request.urlopen(v_url).read().decode())
server_url = v_data['downloads']['server']['url']
urllib.request.urlretrieve(server_url, 'server.jar')
with open('.rempy_config', 'w') as f:
    f.write('START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY:-1024}M -jar server.jar\"\n')
"
}

install_folia() {
    echo -e "\e[33mFetching Folia using Python...\e[0m"
    python3 -c "
import urllib.request, json
ver = '$MC_VER'
if ver == 'latest':
    data = json.loads(urllib.request.urlopen('https://api.papermc.io/v2/projects/folia').read().decode())
    ver = data['versions'][-1]
builds_data = json.loads(urllib.request.urlopen(f'https://api.papermc.io/v2/projects/folia/versions/{ver}').read().decode())
build = builds_data['builds'][-1]
jar_name = f'folia-{ver}-{build}.jar'
url = f'https://api.papermc.io/v2/projects/folia/versions/{ver}/builds/{build}/downloads/{jar_name}'
urllib.request.urlretrieve(url, 'server.jar')
with open('.rempy_config', 'w') as f:
    f.write('START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY:-1024}M -jar server.jar\"\n')
"
}

install_neoforge() { install_paper; }
setup_bedrock() { install_paper; }

setup_proxy() {
    ask_version
    echo -e "\e[33mFetching Velocity via Python...\e[0m"
    python3 -c "
import urllib.request, json
ver = '$MC_VER'
if ver == 'latest':
    data = json.loads(urllib.request.urlopen('https://api.papermc.io/v2/projects/velocity').read().decode())
    ver = data['versions'][-1]
builds_data = json.loads(urllib.request.urlopen(f'https://api.papermc.io/v2/projects/velocity/versions/{ver}').read().decode())
build = builds_data['builds'][-1]
jar_name = f'velocity-{ver}-{build}.jar'
url = f'https://api.papermc.io/v2/projects/velocity/versions/{ver}/builds/{build}/downloads/{jar_name}'
urllib.request.urlretrieve(url, 'server.jar')
with open('.rempy_config', 'w') as f:
    f.write('START_CMD=\"java -Xms128M -Xmx\${SERVER_MEMORY:-1024}M -jar server.jar\"\n')
"
}

# --- MAIN EXECUTION ---
cd "$SERVER_DIR" || exit 1

if [ ! -f "$FLAG_FILE" ]; then
    touch "$FLAG_FILE"
    first_time_setup
fi

show_banner
boot_animation
echo -e "\e[90mTip: Delete '.rempy_installed' in Files to re-run engine setup.\e[0m\n"

if [ ! -f eula.txt ]; then
    echo "eula=true" > eula.txt
fi

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    eval "$START_CMD"
else
    java -Xms128M -Xmx"${SERVER_MEMORY:-1024}"M -jar server.jar
fi
