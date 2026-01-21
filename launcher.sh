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
        --width=400 \
        --height=300 \
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
        1)
            PROJECT_FOLDER="capClone"
            echo "✅ Selected: capClone"
            ;;
        2)
            PROJECT_FOLDER="capClone1"
            echo "✅ Selected: capClone1"
            ;;
        3)
            PROJECT_FOLDER="capClone2"
            echo "✅ Selected: capClone2"
            ;;
        4)
            PROJECT_FOLDER="capCloneDev"
            echo "✅ Selected: capCloneDev"
            ;;
    esac
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
# Ngrok configuration
NGROK_PORT=8081
NGROK_SERVICE_NAME="Ngrok (Import API tunnel)"

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
        nvm use 20.11.1 2>/dev/null
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

# Function to start ngrok tunnel
start_ngrok_tab() {
    local port=$1
    local service_name=$2
    
    echo "🌐 Starting ngrok tunnel for port $port in new tab..."
    
    if command -v gnome-terminal >/dev/null 2>&1; then
        local script_path="/tmp/${PROJECT_FOLDER}_${service_name// /_}_launcher.sh"
        cat > "$script_path" << EOF
#!/bin/bash
# Minimal environment for ngrok (usually doesn't need nvm)

cd "$HOME" || cd /tmp  # ngrok doesn't care about directory

echo ''
echo '🌐 Starting ngrok tunnel for http://localhost:$port'
echo '💡 Press Ctrl+C to stop ngrok'
echo '----------------------------------------'

# Handle Ctrl+C
trap 'echo -e "\n\n⏹️  ngrok stopped. Terminal will stay open..."; exec bash' SIGINT

# Run ngrok (add --log=stdout if you want cleaner output)
ngrok http --domain=finch-superb-especially.ngrok-free.app $port

# If ngrok ends
echo -e '\n⏹️  ngrok ended. Terminal will stay open...'
exec bash
EOF
        
        chmod +x "$script_path"
        gnome-terminal --tab --title="$service_name ($PROJECT_FOLDER)" -- "$script_path" &
    else
        echo "❌ gnome-terminal not found. Skipping ngrok in background."
        nohup ngrok http $port > "/tmp/${PROJECT_FOLDER}_ngrok.log" 2>&1 &
        echo "📋 ngrok logs: /tmp/${PROJECT_FOLDER}_ngrok.log"
    fi
    
    echo "✅ ngrok tunnel started"
    sleep 1
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

# Start both backends in parallel
echo "⚡ Starting backend services in parallel..."
start_service_tab "$PRIMARY_API_DIR" "npm run start:dev" "Primary API" &
start_service_tab "$IMPORT_API_DIR" "npm run start:dev" "Import API" &

# Wait for both backends to start
echo ""
echo "⏳ Waiting for both backend services to start..."
echo "   (This may take a few minutes)"

# ──────────────── Add here ────────────────
echo ""
echo "🌐 Starting public tunnel for Import API (port $NGROK_PORT)..."
start_ngrok_tab "$NGROK_PORT" "$NGROK_SERVICE_NAME" || true
# ──────────────────────────────────────────

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
echo "🌐 Import API public URL:                    https://finch-superb-especially.ngrok-free.app  ← check ngrok tab"
echo "   (Primary API usually stays internal only)"

# Clean up temporary launcher scripts after a short delay
(sleep 5 && rm -f /tmp/${PROJECT_FOLDER}_*_launcher.sh 2>/dev/null) &

echo ""
exec bash