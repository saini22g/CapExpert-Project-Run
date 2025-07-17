#!/bin/bash

# capClone Project Launcher with Enhanced Service Management
# Starts backends in parallel, frontend only after both backends are ready

set -e

wait_time=30

echo "🚀 Starting CapExpert Project..."

# Function to display folder selection menu with timer
select_project_folder() {
    echo ""
    echo "📁 Please select the project folder to run:"
    echo "1) capClone"
    echo "2) capClone1" 
    echo "3) capClone2"
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
        echo -ne "\rEnter your choice (1-3) [Auto-selects 1 in ${remaining}s]: "
        
        # Read input with 1-second timeout
        if read -t 1 input; then
            if [[ "$input" =~ ^[1-3]$ ]]; then
                choice=$input
                echo ""
                break
            elif [ -n "$input" ]; then
                echo ""
                echo "❌ Invalid choice. Please enter 1, 2, or 3."
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
MAX_WAIT_SECONDS=300  # 5 minutes max wait time
CHECK_INTERVAL=5     # Check every 5 seconds

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
        gnome-terminal --tab --title="$service_name ($PROJECT_FOLDER)" -- bash -c "
            # Setup Node.js environment for this session
            $(declare -f setup_node_env)
            setup_node_env
            
            # Change to project directory
            cd \"$path\" || { echo '❌ Failed to change directory to $path'; exit 1; }
            
            echo ''
            echo '🚀 Starting $service_name...'
            echo '💡 Press Ctrl+C to stop this service'
            echo '----------------------------------------'
            
            # Execute the command
            $command
            
            # Keep terminal open
            echo ''
            echo '⏹️  Service stopped. Terminal will stay open...'
            exec bash
        " &
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

# Main execution
cleanup() {
    echo ""
    echo "🛑 Script interrupted by Ctrl+C"
    echo "🏁 Script exiting..."
    exit 0
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

check_service $PRIMARY_API_PORT "Primary API" || {
    echo "❌ Primary API failed to start. Frontend will not start."
    exit 1
}

check_service $IMPORT_API_PORT "Import API" || {
    echo "❌ Import API failed to start. Frontend will not start."
    exit 1
}

# Now that both backends are ready, start frontend
echo ""
echo "⚡ Both backend services are running! Starting frontend..."
start_service_tab "$FRONTEND_DIR" "npm run start:dev" "Frontend"

# Verify frontend started (non-blocking)
check_service $FRONTEND_PORT "Frontend" || true

echo ""
echo "🎉 All services started successfully!"
echo "🌐 Frontend should be available at: http://localhost:$FRONTEND_PORT"
echo "💡 Services are running in separate tabs/windows"
echo ""
exit 0