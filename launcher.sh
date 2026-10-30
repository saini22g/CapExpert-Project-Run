#!/bin/bash

# capClone Project Launcher with Enhanced Service Management
# One window picks the folder, run.sh or Docker for the web stack, and the services to start. Primary
# API, Import API and the frontend start through run.sh (or docker-run.sh), the Python extraction
# services through wr.sh, all from /var/www/html/CapExpert_run; the ngrok tunnels get tabs of their own.

# Needs real bash (arrays, [[ ]], $'\n'). On Ubuntu `sh launcher.sh` runs dash,
# which breaks in obscure ways, so re-exec under bash instead.
if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi

set -e

wait_time=30

echo "🚀 Starting CapExpert Project..."

# Fallback folder pick when the start window cannot open: zenity, with a timer
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
        --width=1000 \
        --height=650 \
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

# Shared start scripts, one copy for every folder (each folder links run.sh, wr.sh and docker-run.sh).
# They start the folder they are run from, so the launcher runs them from $PROJECT_ROOT.
RUN_DIR="/var/www/html/CapExpert_run"
# The start window: folder, run.sh or Docker, the services, and Cancel / Restart / Start.
SERVICES_DIALOG="$(dirname "$(readlink -f "$0")")/services-dialog.py"
# The folders the start window offers, under /var/www/html; the first is selected.
PROJECT_FOLDERS=(capClone capClone1 capClone2 capCloneDev)
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
NGROK_IMPORT_URL="https://finch-superb-especially.ngrok-free.app"
NGROK_PRIMARY_NAME="Ngrok2 (Primary API)"
NGROK_PRIMARY_CMD="bash -ic 'ngrok2 $PRIMARY_API_PORT'"
NGROK_PRIMARY_URL="https://giraffe-balanced-panda.ngrok-free.app"

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

# Ask ONCE what to start: services-dialog.py shows one window with the folder, run.sh or Docker for the
# web stack and a check box per service, with Cancel, Restart (stop what is running for the ticked
# services first) and Start. Primary API, Import API and the frontend are ticked, but nothing starts
# until Start or Restart is clicked. When it cannot open, the zenity folder list, then zenity's
# checklist or a numbered prompt stand in, with Docker and hard reload as rows (zenity returns the
# ticked rows for its OK button only); they wait for an answer too.
# Sets PROJECT_FOLDER, SELECTED (the ticked keys, "|"-separated, plus "docker" and "hard"; test one
# with `picked`), WEB_SERVICES (run.sh / docker-run.sh names) and PY_SERVICES (wr.sh names).
select_services() {
    # "#|group|description", or key|ticked by default|title|subtitle|ports. A Python service key starts
    # its API and worker: <key>-api and <key>-worker in wr.sh.
    local services=(
        "#|Web|Primary API, Import API and frontend"
        "primary|TRUE|Primary API||$PRIMARY_API_PORT"
        "import|TRUE|Import API||$IMPORT_API_PORT"
        "fe|TRUE|Frontend|capExpertApp|$FRONTEND_PORT"
        "#|Python services|Each starts its API and worker with wr.sh, on this folder's database"
        "capture|FALSE|Capture||8087, 8088"
        "sticker|FALSE|Sticker||8083, 8084"
        "cad|FALSE|CAD||8085, 8086"
        "#|Public tunnels|ngrok, to the APIs on this machine"
        "ngrok-primary|FALSE|Primary API tunnel|${NGROK_PRIMARY_URL#https://}|$PRIMARY_API_PORT"
        "ngrok-import|FALSE|Import API tunnel|${NGROK_IMPORT_URL#https://}|$IMPORT_API_PORT"
    )

    local entry key on title sub ports default="" choice="" status=0 folders
    folders=$(IFS=,; echo "${PROJECT_FOLDERS[*]}")
    choice=$(python3 "$SERVICES_DIALOG" /var/www/html "$folders" "${services[@]}" 2>/dev/null) || status=$?

    # 0 Start / Restart (the folder, then the keys), 1 Cancel; anything else: the window did not open.
    case "$status" in
        0)
            PROJECT_FOLDER=${choice%%$'\n'*}
            if [[ "$choice" == *$'\n'* ]]; then choice=${choice#*$'\n'}; else choice=""; fi
            ;;
        1) choice="" ;;
        *)
            echo "ℹ️  Start window unavailable (exit $status) — using the folder list and checklist instead."
            select_project_folder
            local rows=() keys=()
            for entry in "${services[@]}"; do
                IFS='|' read -r key on title sub ports <<< "$entry"
                [ "$key" = "#" ] && continue
                rows+=( "$on" "$key" "$title ($ports)" )
                keys+=( "$key" )
                if [ "$on" = TRUE ]; then default="${default:+$default|}$key"; fi
            done
            rows+=( FALSE "docker" "Run Primary API, Import API and frontend in Docker (docker-run.sh)" )
            rows+=( FALSE "hard" "Restart — stop what is running first, then start it fresh" )
            keys+=( "docker" "hard" )
            status=0
            if command -v zenity >/dev/null 2>&1; then
                choice=$(zenity --list --checklist \
                    --title="CapExpert — services to run" \
                    --text="Tick the services to start" \
                    --column="Run" --column="Service" --column="Description" \
                    --width=1100 --height=800 \
                    "${rows[@]}" 2>/dev/null) || status=$?
            else
                echo ""
                echo "🧩 Services to run (default: Primary API, Import API, frontend):"
                local i
                for i in "${!keys[@]}"; do
                    echo "   $((i + 1))) ${rows[$((i * 3 + 2))]}"
                done
                local sel=""
                # Blank picks the ticked defaults; no input at all (Ctrl+D) starts nothing.
                read -r -p "Enter numbers to ENABLE (e.g. '1 2 3 4 5', blank = default): " sel || { echo ""; status=1; }
                choice=""
                for i in $sel; do
                    if [[ "$i" =~ ^[0-9]+$ ]] && [ "$i" -ge 1 ] && [ "$i" -le ${#keys[@]} ]; then
                        choice="${choice:+$choice|}${keys[$((i - 1))]}"
                    fi
                done
                [ -n "$choice" ] || choice=$default
            fi
            case "$status" in
                0) ;;
                *) choice="" ;;           # Cancel, or the window was closed → nothing
            esac
            ;;
    esac

    SELECTED=$choice
    WEB_SERVICES=()
    PY_SERVICES=()
    local ticked=()
    IFS='|' read -ra ticked <<< "$SELECTED"
    for key in "${ticked[@]}"; do
        case "$key" in
            primary | import | fe) WEB_SERVICES+=( "$key" ) ;;
            capture | sticker | cad) PY_SERVICES+=( "$key-api" "$key-worker" ) ;;
        esac
    done
    echo "🧩 Selected → ${ticked[*]:-nothing}"
}

# True when the start window ticked $1.
picked() {
    case "|$SELECTED|" in
        *"|$1|"*) return 0 ;;
    esac
    return 1
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

# ── Pick the folder, run.sh or Docker, the services and hard reload, in ONE window ──
select_services

if [ ${#WEB_SERVICES[@]} -eq 0 ] && [ ${#PY_SERVICES[@]} -eq 0 ] && ! picked ngrok-primary && ! picked ngrok-import; then
    echo "ℹ️  No service selected — nothing to start."
    exec bash
fi

PROJECT_ROOT="/var/www/html/$PROJECT_FOLDER"
# run.sh, docker-run.sh and wr.sh start only a workspace: a folder with backendApi and dbMigrations.
if [ ! -d "$PROJECT_ROOT/backendApi" ] || [ ! -d "$PROJECT_ROOT/dbMigrations" ]; then
    echo "❌ $PROJECT_ROOT is not a workspace (needs backendApi and dbMigrations)"
    exec bash
fi
echo "🎯 Running project from: $PROJECT_ROOT"
echo "=================================================="

HARD_ARG=()
if picked hard; then
    HARD_ARG=(h)
fi

# ── Python extraction services (per selection) — wr.sh runs them on this folder's database ──
if [ ${#PY_SERVICES[@]} -gt 0 ]; then
    echo ""
    echo "🐍 Starting ${PY_SERVICES[*]} via $RUN_DIR/wr.sh..."
    ( cd "$PROJECT_ROOT" && "$RUN_DIR/wr.sh" "${PY_SERVICES[@]}" "${HARD_ARG[@]}" ) ||
        echo "⚠️  wr.sh reported a problem — see above"
fi

# ──────────────── ngrok tunnels (per selection) ────────────────
if picked ngrok-primary; then
    echo ""
    echo "🌐 Starting public tunnel for Primary API (port $PRIMARY_API_PORT)..."
    start_ngrok_tab "$NGROK_PRIMARY_NAME" "$NGROK_PRIMARY_CMD" || true
fi
if picked ngrok-import; then
    echo ""
    echo "🌐 Starting public tunnel for Import API (port $IMPORT_API_PORT)..."
    start_ngrok_tab "$NGROK_IMPORT_NAME" "$NGROK_IMPORT_CMD" || true
fi
# ─────────────────────────────────────────────────────────────────

# ── Primary API, Import API, frontend (per selection) — last, as docker-run.sh builds in the foreground ──
if [ ${#WEB_SERVICES[@]} -gt 0 ] && picked docker; then
    # docker-run.sh asks for the sudo password once, builds the images from a snapshot of the folder,
    # starts the containers and opens its own window with a tab per log (logs in /var/www/html/.run).
    # With h it first stops the run.sh services holding those ports. Node runs inside the images.
    echo ""
    echo "🐳 Starting ${WEB_SERVICES[*]} via $RUN_DIR/docker-run.sh..."
    ( cd "$PROJECT_ROOT" && "$RUN_DIR/docker-run.sh" "${WEB_SERVICES[@]}" "${HARD_ARG[@]}" ) ||
        echo "⚠️  docker-run.sh reported a problem — see above"
elif [ ${#WEB_SERVICES[@]} -gt 0 ]; then
    # run.sh cannot see or stop docker-run.sh's containers: they run as root, so no pid shows for their
    # ports. On hard reload, a ticked port held that way is freed through docker-run.sh stop first.
    if picked hard; then
        held=()
        for web in "${WEB_SERVICES[@]}"; do
            case "$web" in
                primary) port=$PRIMARY_API_PORT ;;
                import) port=$IMPORT_API_PORT ;;
                fe) port=$FRONTEND_PORT ;;
            esac
            if ss -ltnH "sport = :$port" | grep -q . && ! ss -ltnpH "sport = :$port" | grep -q 'pid='; then
                held+=( "$web" )
            fi
        done
        if [ ${#held[@]} -gt 0 ]; then
            echo "🐳 ${held[*]} held by Docker — stopping via $RUN_DIR/docker-run.sh stop (asks for sudo;"
            echo "   for the frontend it also asks you to reload http://localhost:$FRONTEND_PORT, then press Enter)..."
            ( cd "$PROJECT_ROOT" && "$RUN_DIR/docker-run.sh" stop "${held[@]}" ) ||
                echo "⚠️  docker-run.sh stop reported a problem — see above"
        fi
    fi
    # run.sh starts them detached (logs in /var/www/html/.run) in its own window, a tab per log, and
    # its frontend waits for both API ports itself. The subshell keeps the cd and nvm out of the
    # launcher; set +e because nvm.sh is not safe under set -e.
    echo ""
    echo "⚡ Starting ${WEB_SERVICES[*]} via $RUN_DIR/run.sh..."
    ( set +e; cd "$PROJECT_ROOT" && setup_node_env && "$RUN_DIR/run.sh" "${WEB_SERVICES[@]}" "${HARD_ARG[@]}" ) ||
        echo "⚠️  run.sh reported a problem — see above"
fi

# Verify the picked web services came up (a failure does not stop the launcher)
for web in "${WEB_SERVICES[@]}"; do
    case "$web" in
        primary) check_service $PRIMARY_API_PORT "Primary API" ;;
        import) check_service $IMPORT_API_PORT "Import API" ;;
        fe) check_service $FRONTEND_PORT "Frontend" ;;
    esac || true
done

if picked fe; then
    echo "🌐 Frontend should be available at:           http://localhost:$FRONTEND_PORT"
fi
if picked ngrok-import; then
    echo "🌐 Import API public URL:                    $NGROK_IMPORT_URL  ← check Ngrok1 tab"
fi
if picked ngrok-primary; then
    echo "🌐 Primary API public URL:                   $NGROK_PRIMARY_URL  ← check Ngrok2 tab"
fi

# Clean up temporary launcher scripts after a short delay
(sleep 5 && rm -f /tmp/${PROJECT_FOLDER}_*_launcher.sh 2>/dev/null) &

echo ""
exec bash