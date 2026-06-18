#!/bin/bash

# capClone Project Launcher with Enhanced Service Management
# Starts backends in parallel, frontend only after both backends are ready

set -e

wait_time=30

echo "🚀 Starting CapExpert Project..."

# Function to display folder selection menu with timer
select_project_folder() {
    echo ""
    echo "📁 Opening project selection dialog..."
    
    # Check if zenity is available
    if ! command -v zenity >/dev/null 2>&1; then
        echo "⚠️  Zenity not found. Installing zenity..."
        sudo apt-get update && sudo apt-get install -y zenity || {
            echo "❌ Failed to install zenity. Using command-line selection."
            select_project_folder_cli
            return
        }
    fi
    
    # Use zenity with timeout
    choice=$(timeout ${wait_time}s zenity --list \
        --title="Select CapExpert Project" \
        --text="Choose the project folder to run:\n\nWill auto-select capClone in ${wait_time} seconds" \
        --radiolist \
        --column="Select" \
        --column="Project" \
        --column="Description" \
        --width=750 \
        --height=500 \
        TRUE "capClone" "Main project folder" \
        FALSE "capClone1" "First alternative folder" \
        FALSE "capClone2" "Second alternative folder" \
        FALSE "capCloneDev" "Development folder" 2>/dev/null) || true
    
    # Check if choice is empty (timeout or cancel)
    if [ -z "$choice" ]; then
        echo "⏰ No selection made or dialog timed out. Defaulting to capClone."
        PROJECT_FOLDER="capClone"
    else
        PROJECT_FOLDER="$choice"
    fi
    
    echo "✅ Selected: $PROJECT_FOLDER"
    echo ""
}

# Fallback CLI function if zenity is not available
select_project_folder_cli() {
    echo ""
    echo "📁 Please select the project folder to run:"
    echo "1) capClone"
    echo "2) capClone1" 
    echo "3) capClone2"
    echo "4) capCloneDev"
    echo ""
    
    echo "⏰ You have ${wait_time} seconds to make a selection, or it will default to capClone"
    echo ""
    
    # Countdown timer with real-time display
    start_time=$(date +%s)
    choice=""
    
    while [ -z "$choice" ]; do
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        remaining=$((wait_time - elapsed))
        
        if [ $remaining -le 0 ]; then
            echo ""
            echo "⏰ No input detected in ${wait_time} seconds. Defaulting to 1 (capClone)."
            choice=1
            break
        fi
        
        # Clear the line and show countdown
        echo -ne "\rEnter your choice (1-4) [Auto-selects 1 in ${remaining}s]: "
        
        # Read input with 1-second timeout
        if read -t 1 input; then
            if [[ "$input" =~ ^[1-4]$ ]]; then
                choice=$input
                echo ""
                break
            elif [ -n "$input" ]; then
                echo ""
                echo "❌ Invalid choice. Please enter 1, 2, 3 or 4."
                echo ""
            fi
        fi
    done
    
    case $choice in
        1) PROJECT_FOLDER="capClone" ;;
        2) PROJECT_FOLDER="capClone1" ;;
        3) PROJECT_FOLDER="capClone2" ;;
        4) PROJECT_FOLDER="capCloneDev" ;;
    esac
    echo "✅ Selected: $PROJECT_FOLDER"
    echo ""
}

# Call the selection function
select_project_folder

# Configuration - dynamically set based on selection
PRIMARY_API_DIR="/var/www/html/$PROJECT_FOLDER/primaryAPI"
IMPORT_API_DIR="/var/www/html/$PROJECT_FOLDER/importAPI"
FRONTEND_DIR="/var/www/html/$PROJECT_FOLDER/capExpertApp"
PRIMARY_API_PORT=8080
IMPORT_API_PORT=8081
FRONTEND_PORT=4200
MAX_WAIT_SECONDS=600  # 10 minutes max wait time
CHECK_INTERVAL=5     # Check every 5 seconds
# Ngrok tunnels — each maps a backend port to a reserved free domain via a per-account alias from
# ~/.bashrc (ngrok1 = Import API → finch, ngrok2 = Primary API → giraffe). Run via `bash -ic` so the
# interactive-only aliases resolve, exactly as when run by hand.
NGROK_IMPORT_NAME="Ngrok1 (Import API)"
NGROK_IMPORT_CMD="bash -ic 'ngrok1 $IMPORT_API_PORT'"
NGROK_PRIMARY_NAME="Ngrok2 (Primary API)"
NGROK_PRIMARY_CMD="bash -ic 'ngrok2 $PRIMARY_API_PORT'"
# Dummy matching service — started by this launcher via its own run.sh (not a selectable option).
MATCHING_DIR="/var/www/html/$PROJECT_FOLDER/matching-api"
MATCHING_PORT=8083
MATCHING_SERVICE_NAME="Dummy Matching"

echo "🎯 Running project from: /var/www/html/$PROJECT_FOLDER"
echo "=================================================="

# Function to setup Node.js environment
setup_node_env() {
    # Source bashrc first (only for this session)
    source ~/.bashrc 2>/dev/null || true
    
    # Force load NVM and set correct Node version
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 2>/dev/null
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" 2>/dev/null
    
    # Use Node.js v20.11.1 specifically
    if command -v nvm >/dev/null 2>&1; then
        nvm use 20.19 2>/dev/null
        echo "✅ Using Node.js version: $(node --version)"
    else
        echo "⚠️  NVM not found, using system Node.js: $(node --version)"
    fi
    
    # Display current versions
    echo "🔧 Node.js version: $(node --version)"
    echo "📦 NPM version: $(npm --version)"
    echo "📂 Working directory: $(pwd)"
}

# Function to check if a service is running on a specific port
check_service() {
    local port=$1
    local service_name=$2
    local max_attempts=$(($MAX_WAIT_SECONDS / $CHECK_INTERVAL))
    local attempt=0
    
    echo "⏳ Waiting for $service_name to start on port $port..."
    
    while [ $attempt -lt $max_attempts ]; do
        if netstat -tuln | grep -q ":$port "; then
            echo "✅ $service_name is running on port $port"
            return 0
        fi
        sleep $CHECK_INTERVAL
        attempt=$((attempt + 1))
        echo "   Attempt $attempt/$max_attempts (waited $((attempt * CHECK_INTERVAL))s..."
    done
    
    echo "❌ $service_name failed to start on port $port after $MAX_WAIT_SECONDS seconds"
    return 1
}

# Function to start a service in a new tab
start_service_tab() {
    local path=$1
    local command=$2
    local service_name=$3
    
    echo "🔄 Starting $service_name in new tab..."
    
    if command -v gnome-terminal >/dev/null 2>&1; then
        # Create a wrapper script for each service to ensure proper process handling
        local script_path="/tmp/${PROJECT_FOLDER}_${service_name// /_}_launcher.sh"
        cat > "$script_path" << EOF
#!/bin/bash
# Setup Node.js environment
$(declare -f setup_node_env)
setup_node_env

# Change to project directory
cd "$path" || { echo '❌ Failed to change directory to $path'; exit 1; }

echo ''
echo '🚀 Starting $service_name...'
echo '💡 Press Ctrl+C to stop this service'
echo '----------------------------------------'

# Handle Ctrl+C
trap 'echo -e "\n\n⏹️  Service stopped. Terminal will stay open..."; exec bash' SIGINT

# Run the service
$command

# If service ends normally
echo -e '\n⏹️  Service ended normally. Terminal will stay open...'
exec bash
EOF
        
        chmod +x "$script_path"
        
        # Launch terminal with the script
        gnome-terminal --tab --title="$service_name ($PROJECT_FOLDER)" -- "$script_path" &
    else
        echo "❌ gnome-terminal not found. Using background process instead."
        cd "$path" || exit 1
        setup_node_env
        nohup $command > "/tmp/${PROJECT_FOLDER}_${service_name// /_}.log" 2>&1 &
        echo "📋 Logs available at: /tmp/${PROJECT_FOLDER}_${service_name// /_}.log"
    fi
    
    echo "✅ $service_name started in new tab"
    sleep 1
}

# Function to start an ngrok tunnel in a new tab.
# Usage: start_ngrok_tab <service_name> <full ngrok command string>
start_ngrok_tab() {
    local service_name=$1
    local ngrok_command=$2

    echo "🌐 Starting $service_name in new tab..."

    if command -v gnome-terminal >/dev/null 2>&1; then
        local script_path="/tmp/${PROJECT_FOLDER}_${service_name// /_}_launcher.sh"
        cat > "$script_path" << EOF
#!/bin/bash
# Minimal environment for ngrok (usually doesn't need nvm)

cd "$HOME" || cd /tmp  # ngrok doesn't care about directory

echo ''
echo '🌐 Starting $service_name'
echo "   \$ $ngrok_command"
echo '💡 Press Ctrl+C to stop ngrok'
echo '----------------------------------------'

# Handle Ctrl+C
trap 'echo -e "\n\n⏹️  ngrok stopped. Terminal will stay open..."; exec bash' SIGINT

# Run ngrok
$ngrok_command

# If ngrok ends
echo -e '\n⏹️  ngrok ended. Terminal will stay open...'
exec bash
EOF

        chmod +x "$script_path"
        gnome-terminal --tab --title="$service_name ($PROJECT_FOLDER)" -- "$script_path" &
    else
        echo "❌ gnome-terminal not found. Running $service_name in background."
        nohup bash -c "$ngrok_command" > "/tmp/${PROJECT_FOLDER}_${service_name// /_}.log" 2>&1 &
        echo "📋 logs: /tmp/${PROJECT_FOLDER}_${service_name// /_}.log"
    fi

    echo "✅ $service_name started"
    sleep 1
}

# Ask ONCE (single checklist) which optional services to start. All OFF by default; auto-continues
# with NONE selected after $wait_time seconds. Sets RUN_NGROK_PRIMARY, RUN_NGROK_IMPORT, RUN_MATCHING.
select_optional_services() {
    RUN_NGROK_PRIMARY=no
    RUN_NGROK_IMPORT=no
    RUN_MATCHING=no
    local matching_available=no
    [ -f "$MATCHING_DIR/run.sh" ] && matching_available=yes

    if command -v zenity >/dev/null 2>&1; then
        local rows=(
            FALSE "primary" "Primary API ngrok (ngrok2 → giraffe, $PRIMARY_API_PORT)"
            FALSE "import"  "Import API ngrok (ngrok1 → finch, $IMPORT_API_PORT)"
        )
        [ "$matching_available" = yes ] && rows+=( FALSE "matching" "Dummy matching API (run.sh, port $MATCHING_PORT)" )
        local choice=""
        choice=$(timeout ${wait_time}s zenity --list --checklist \
            --title="CapExpert — services to run" \
            --text="Tick services to start (default: none)" \
            --column="Run" --column="Service" --column="Description" \
            --width=520 --height=340 \
            "${rows[@]}" 2>/dev/null) || true   # cancel/timeout → empty → none
        case "$choice" in *primary*)  RUN_NGROK_PRIMARY=yes;; esac
        case "$choice" in *import*)   RUN_NGROK_IMPORT=yes;;  esac
        case "$choice" in *matching*) RUN_MATCHING=yes;;      esac
    else
        echo ""
        echo "🧩 Optional services (default: NONE):"
        echo "   1) Primary API ngrok (ngrok2 $PRIMARY_API_PORT)"
        echo "   2) Import API ngrok  (ngrok1 $IMPORT_API_PORT)"
        [ "$matching_available" = yes ] && echo "   3) Dummy matching API (run.sh $MATCHING_PORT)"
        local sel=""
        read -t ${wait_time} -p "Enter numbers to ENABLE (e.g. '1 2 3', blank = none): " sel || { echo ""; sel=""; }
        case " $sel " in *" 1 "*) RUN_NGROK_PRIMARY=yes;; esac
        case " $sel " in *" 2 "*) RUN_NGROK_IMPORT=yes;;  esac
        [ "$matching_available" = yes ] && case " $sel " in *" 3 "*) RUN_MATCHING=yes;; esac
    fi

    [ "$matching_available" = no ] && echo "ℹ️  No matching-api/run.sh in $PROJECT_FOLDER — dummy matching unavailable."
    echo "🧩 Selected →  Primary ngrok: $RUN_NGROK_PRIMARY  |  Import ngrok: $RUN_NGROK_IMPORT  |  Dummy matching: $RUN_MATCHING"
}

# Main execution
cleanup() {
    echo ""
    echo "🛑 Script interrupted by Ctrl+C"
    echo "🏁 Launcher stopped, but services may still be running in other tabs"
    
    # Clean up temporary launcher scripts
    rm -f /tmp/${PROJECT_FOLDER}_*_launcher.sh 2>/dev/null || true
    
    echo "💡 Terminal will stay open..."
    exec bash
}

trap cleanup SIGINT SIGTERM

echo "🚀 Starting $PROJECT_FOLDER services with Node.js v20.11.1"
echo "=================================================="

# ── Pick optional services in ONE checklist (all OFF by default) ──
select_optional_services

# Start both backends in parallel
echo "⚡ Starting backend services in parallel..."
start_service_tab "$PRIMARY_API_DIR" "npm run start:dev" "Primary API" &
start_service_tab "$IMPORT_API_DIR" "npm run start:dev" "Import API" &

# Wait for both backends to start
echo ""
echo "⏳ Waiting for both backend services to start..."
echo "   (This may take a few minutes)"

# ──────────────── ngrok tunnels (per selection) ────────────────
if [ "$RUN_NGROK_PRIMARY" = "yes" ]; then
    echo ""
    echo "🌐 Starting public tunnel for Primary API (port $PRIMARY_API_PORT)..."
    start_ngrok_tab "$NGROK_PRIMARY_NAME" "$NGROK_PRIMARY_CMD" || true
fi
if [ "$RUN_NGROK_IMPORT" = "yes" ]; then
    echo ""
    echo "🌐 Starting public tunnel for Import API (port $IMPORT_API_PORT)..."
    start_ngrok_tab "$NGROK_IMPORT_NAME" "$NGROK_IMPORT_CMD" || true
fi
# ─────────────────────────────────────────────────────────────────

# ── Dummy matching service (per selection) — started EARLY via its own run.sh, in parallel with the
#    backends. It connects to the DB directly at boot (the APIs need not be up first); its only tie to
#    importAPI is the /capture-webhook/copilot-match callback, which fires later when a match request
#    arrives. run.sh links node_modules to this folder's importAPI and loads its .env. ──
if [ "$RUN_MATCHING" = "yes" ] && [ -f "$MATCHING_DIR/run.sh" ]; then
    echo ""
    echo "🔌 Starting dummy matching service (matching-api on port $MATCHING_PORT) via run.sh..."
    start_service_tab "$MATCHING_DIR" "bash run.sh" "$MATCHING_SERVICE_NAME"
fi

check_service $PRIMARY_API_PORT "Primary API" || {
    echo "❌ Primary API failed to start. Frontend will not start."
    exec bash
}

check_service $IMPORT_API_PORT "Import API" || {
    echo "❌ Import API failed to start. Frontend will not start."
    exec bash
}

# Now that both backends are ready, start frontend
echo ""
echo "⚡ Both backend services are running! Starting frontend..."
start_service_tab "$FRONTEND_DIR" "npm run start:dev" "Frontend"

# Verify frontend started (non-blocking)
check_service $FRONTEND_PORT "Frontend" || true

echo "🌐 Frontend should be available at:           http://localhost:$FRONTEND_PORT"
if [ "$RUN_NGROK_IMPORT" = "yes" ]; then
    echo "🌐 Import API public URL:                    https://finch-superb-especially.ngrok-free.app  ← check Ngrok1 tab"
fi
if [ "$RUN_NGROK_PRIMARY" = "yes" ]; then
    echo "🌐 Primary API public URL:                   https://giraffe-balanced-panda.ngrok-free.app  ← check Ngrok2 tab"
fi
if [ "$RUN_MATCHING" = "yes" ] && [ -f "$MATCHING_DIR/run.sh" ]; then
    echo "🔌 Dummy matching service:                   http://localhost:$MATCHING_PORT/api/copilot-matching  ← check Dummy Matching tab"
    echo "   (point importAPI DENOVO_API_URL at it: DENOVO_API_URL=http://localhost:$MATCHING_PORT)"
fi

# Clean up temporary launcher scripts after a short delay
(sleep 5 && rm -f /tmp/${PROJECT_FOLDER}_*_launcher.sh 2>/dev/null) &

echo ""
exec bash