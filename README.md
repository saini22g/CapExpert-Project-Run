# CapExpert Ubuntu Launcher System

This system provides a unified Ubuntu launcher for **CapExpert** projects with intelligent project folder selection, proper service sequencing, and port management.

## 📁 Directory Structure

```
CapExpert/
├── launcher.sh                    # Main launcher script with project selection
├── launcher.desktop               # Ubuntu desktop entry
├── setup-launcher.sh              # Installation script
├── logo-small.svg                 # Application icon
└── README.md                      # This file
```

## ✨ Features

- 🎯 **Project Selection**: Choose between capClone, capClone1, capClone2 or capCloneDev at runtime
- 🔀 **Backend Layout Detection**: Detects whether the folder ships the split `primaryAPI` + `importAPI` pair, the merged `backendApi`, or both — and only asks when there is a real choice
- 🚀 **Smart Startup Sequencing**: APIs start first, frontend waits until ready
- 🔍 **Port Monitoring**: Checks actual port availability before proceeding
- 🎨 **Multi-Tab Operation**: Each service runs in its own terminal tab
- 📱 **Ubuntu Integration**: Launcher appears in Applications menu
- 🖥️ **Desktop Shortcuts**: Icon created directly on your desktop
- ⚡ **Parallel Backend Startup**: Both APIs start simultaneously for faster launch
- 🔄 **Enhanced Error Handling**: Comprehensive service monitoring and feedback
- 🛠️ **Node.js Environment Management**: Automatically sets up Node.js v20.11.1

## 🏗️ Project Configuration

### Supported Projects
The launcher supports four project folders:
- **capClone**: `/var/www/html/capClone/`
- **capClone1**: `/var/www/html/capClone1/`
- **capClone2**: `/var/www/html/capClone2/`
- **capCloneDev**: `/var/www/html/capCloneDev/`

### Backend Modes
Parent project folders come in two shapes, so after the folder is picked the launcher
inspects it and decides how the backends should run:

| Mode | Folder | Primary API (8080) | Import API (8081) |
|---|---|---|---|
| **Normal** (split) | `primaryAPI` + `importAPI` | `npm run start:dev` | `npm run start:dev` |
| **Merged** | `backendApi` | `npm run start:dev:primary` | `npm run start:dev:import` |

In Merged mode both watchers live in one folder but use separate build outputs
(`dist-primary` / `dist-import`) and debug ports (9229 / 9230), so they run side
by side without clashing.

**The mode is only asked when the folder ships both layouts.** With a single layout
there is nothing to choose, so it is selected silently:

| Folder contains | Result |
|---|---|
| `primaryAPI` + `importAPI` only | Normal — no prompt |
| `backendApi` only | Merged — no prompt |
| Both | Prompt, defaulting to Normal |
| Neither | Error, launcher stops |

`capExpertAPI` is still accepted as a merged-folder name for checkouts that predate
the rename to `backendApi`. When the prompt does appear, cancelling it or letting it
time out falls back to Normal. Everything downstream (ngrok tunnels, the dummy
matching service, the frontend) is unaffected by the choice.

### Service Ports
- **Primary API Port**: 8080
- **Import API Port**: 8081
- **Frontend Port**: 4200

### Required Directory Structure (for each project)
```
/var/www/html/[PROJECT_FOLDER]/
├── primaryAPI/                    # Backend primary service   (Normal mode)
├── importAPI/                     # Backend import service    (Normal mode)
├── backendApi/                    # Merged backend            (Merged mode)
├── matching-api/                  # Dummy matching service, optional
├── dbMigrations/                  # Sequelize migrations, not started by the launcher
└── capExpertApp/                  # Frontend application
```

At least one backend layout must be present: either `primaryAPI` + `importAPI`, or
`backendApi`. Folders may ship both.
```
```

## 🚀 Quick Setup

### Install the Launcher
```bash
cd CapExpert
chmod +x setup-launcher.sh
./setup-launcher.sh
```

The setup script will:
- Make the launcher executable
- Install to Ubuntu Applications menu
- Create desktop shortcut
- Set up proper file permissions

## 📱 Usage

### Method 1: Applications Menu
1. Open Activities (Super key)
2. Search for "CapExpert"
3. Click to launch
4. Select your project folder (1-3) when prompted

### Method 2: Desktop Shortcut
1. Double-click the "CapExpert" icon on your desktop
2. Select your project folder when prompted

### Method 3: Direct Script Execution
```bash
./CapExpert/launcher.sh
```

## 🔧 How It Works

1. **Project Selection**:
   - Interactive menu to choose between capClone, capClone1, capClone2 or capCloneDev
   - Dynamic path configuration based on selection

2. **Backend Layout Detection**:
   - Detects which backends the folder ships: `primaryAPI` + `importAPI`, `backendApi`, or both
   - Asks Normal vs Merged only when both are present; otherwise picks the available one silently
   - Stops with an error if the folder has no backend at all

3. **Node.js Environment Setup**:
   - Automatically loads NVM and sets Node.js v20.11.1
   - Sources environment variables for proper operation

4. **Backend Services Start**:
   - Primary API and Import API launch in parallel in separate tabs
   - Each service runs with proper Node.js environment

5. **Port Monitoring**:
   - Checks if services are running on expected ports (8080, 8081)
   - Waits up to 5 minutes for each service with 5-second intervals
   - Provides real-time feedback on startup progress

6. **Frontend Launch**:
   - Only starts after both backend APIs are confirmed running
   - Launches in its own terminal tab on port 4200

7. **Service Management**:
   - Each service runs in a named terminal tab
   - Logs are displayed in real-time
   - Services can be stopped individually with Ctrl+C

## ⚙️ Configuration

### Port Customization
Edit `launcher.sh` to change default ports:

```bash
# Around line 44-46
PRIMARY_API_PORT=8080
IMPORT_API_PORT=8081
FRONTEND_PORT=4200
```

### Timeout Settings
Adjust service startup timeout:

```bash
# Around line 47-48
MAX_WAIT_SECONDS=300  # 5 minutes max wait time
CHECK_INTERVAL=5     # Check every 5 seconds
```

### Project Path Customization
Paths and start commands are set per backend mode, in the
`if [ "$BACKEND_MODE" = "merged" ]` block right after the selection functions:

```bash
if [ "$BACKEND_MODE" = "merged" ]; then
    PRIMARY_API_DIR="$MERGED_API_DIR"
    IMPORT_API_DIR="$MERGED_API_DIR"
    PRIMARY_API_CMD="npm run start:dev:primary"
    IMPORT_API_CMD="npm run start:dev:import"
else
    PRIMARY_API_DIR="$PROJECT_ROOT/primaryAPI"
    IMPORT_API_DIR="$PROJECT_ROOT/importAPI"
    PRIMARY_API_CMD="npm run start:dev"
    IMPORT_API_CMD="npm run start:dev"
fi
FRONTEND_DIR="$PROJECT_ROOT/capExpertApp"
```

`PROJECT_ROOT` is `/var/www/html/$PROJECT_FOLDER` and is also used for
`MATCHING_DIR`.

### Node.js Version
Change the required Node.js version:

```bash
# Around line 64
nvm use 20.11.1 2>/dev/null
```

## 🛠️ Troubleshooting

### Services Not Starting
- Verify Node.js v20.11.1 is installed via NVM
- Check project paths exist and are accessible
- Ensure dependencies are installed: `npm install` in each project directory
- Check terminal tabs for specific error messages

### Port Conflicts
```bash
# Check if ports are in use
netstat -tuln | grep :8080
netstat -tuln | grep :8081
netstat -tuln | grep :4200

# Kill processes using specific ports
sudo lsof -ti:8080 | xargs kill -9
sudo lsof -ti:8081 | xargs kill -9
sudo lsof -ti:4200 | xargs kill -9
```

### Desktop Entry Issues
- Log out and back in to refresh applications menu
- Manual refresh: `update-desktop-database ~/.local/share/applications`
- Check file permissions: `ls -la ~/.local/share/applications/CapExpert-launcher.desktop`

### NVM/Node.js Issues
```bash
# Install NVM if not present
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Install Node.js v20.11.1
nvm install 20.11.1
nvm use 20.11.1
```

## 📊 Project Status Monitoring

### Check Running Services
```bash
# Check all relevant ports
netstat -tuln | grep -E ":(8080|8081|4200)"

# Check specific processes
ps aux | grep -E "node.*capClone|node.*capExpert"
```

### Service Logs
- Each service runs in its own terminal tab with real-time logs
- Background logs (if gnome-terminal unavailable): `/tmp/[PROJECT]_[SERVICE].log`

### Stop Services
- Use Ctrl+C in individual terminal tabs
- Or close the terminal tabs directly
- For background processes: `pkill -f "node.*capClone"`

## 🔄 Updates and Maintenance

### Updating the Launcher
1. Edit `launcher.sh` as needed
2. Re-run `./setup-launcher.sh` to update desktop entries
3. Changes take effect immediately

### Removing the Launcher
```bash
# Remove desktop entries
rm ~/.local/share/applications/CapExpert-launcher.desktop
rm ~/Desktop/CapExpert-launcher.desktop

# Update desktop database
update-desktop-database ~/.local/share/applications
```

## 📋 Prerequisites

- **Ubuntu 22.04 LTS** (or compatible)
- **gnome-terminal** (default Ubuntu terminal)
- **NVM** (Node Version Manager)
- **Node.js v20.11.1** (automatically managed via NVM)
- **netstat** command (usually pre-installed)
- Project directories properly set up with dependencies

## 🎯 Usage Tips

1. **Project Selection**: The launcher will remember your choice during the session
2. **Service Monitoring**: Watch the terminal output for detailed startup progress
3. **Error Handling**: Each service tab shows specific error details
4. **Resource Management**: Monitor system resources when running multiple services
5. **Development Workflow**: Keep terminal tabs open for real-time log monitoring

## 📝 Installation Log

The setup script provides detailed feedback:
- ✅ Script permissions set
- ✅ Desktop file updated with correct paths
- ✅ Applications menu entry created
- ✅ Desktop shortcut created and trusted
- ✅ Desktop database updated

## 🆘 Support

If you encounter issues:

1. **Check Terminal Output**: Look for specific error messages in service tabs
2. **Verify Paths**: Ensure all project directories exist and have proper permissions
3. **Test Individual Services**: Try starting services manually before using the launcher
4. **Check Dependencies**: Verify `npm install` has been run in each project directory
5. **Node.js Version**: Confirm Node.js v20.11.1 is available via NVM

## 🎉 Success!

Once configured, you'll have:
- ✅ Unified launcher for all CapExpert projects
- ✅ Interactive project selection
- ✅ Proper service sequencing with port monitoring
- ✅ Multi-tab terminal management
- ✅ Ubuntu Applications menu integration
- ✅ Desktop shortcut with trusted permissions
- ✅ Comprehensive error handling and feedback

**Happy Coding!** 🚀

---

*Last updated: $(date)*
