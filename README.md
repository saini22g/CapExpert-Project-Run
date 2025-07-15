# CapExpet Ubuntu Launcher System

This system provides Ubuntu launchers for **capClone** and **capClone1** projects with proper service sequencing and port management.

## 📁 Directory Structure

```
CapExpet/
├── capClone/
│   ├── capClone-launcher.sh          # Main launcher script
│   ├── capClone-launcher.desktop     # Ubuntu desktop entry
│   └── setup-capClone-launcher.sh    # Installation script
├── capClone1/
│   ├── capClone1-launcher.sh         # Main launcher script
│   ├── capClone1-launcher.desktop    # Ubuntu desktop entry
│   └── setup-capClone1-launcher.sh   # Installation script
├── setup-all-launchers.sh            # Master installation script
└── README.md                         # This file
```

## ✨ Features

- 🚀 **Smart Startup Sequencing**: APIs start first, frontend waits until ready
- 🔍 **Port Monitoring**: Checks actual port availability before proceeding
- 🎨 **Single Terminal Operation**: All services run in one terminal window
- 📱 **Ubuntu Integration**: Launchers appear in Applications menu
- 🖥️ **Desktop Shortcuts**: Icons created directly on your desktop
- ⚡ **Dual Project Support**: Run both capClone and capClone1 simultaneously
- 🔄 **Port Conflict Prevention**: Uses different ports for each project

## 🏗️ Project Configuration

### capClone Project
- **Location**: `/var/www/html/capClone/`
- **Primary API Port**: 8080
- **Import API Port**: 8081
- **Components**:
  - `primaryAPI/` - Backend primary service
  - `importAPI/` - Backend import service
  - `capExpertApp/` - Frontend application

### capClone1 Project
- **Location**: `/var/www/html/capClone1/`
- **Primary API Port**: 8080
- **Import API Port**: 8081
- **Components**:
  - `primaryAPI/` - Backend primary service
  - `importAPI/` - Backend import service
  - `capExpertApp/` - Frontend application

## 🚀 Quick Setup

### Install All Launchers
```bash
cd CapExpet
chmod +x setup-all-launchers.sh
./setup-all-launchers.sh
```

### Install Individual Launchers
```bash
# For capClone only
cd CapExpet/capClone
chmod +x setup-capClone-launcher.sh
./setup-capClone-launcher.sh

# For capClone1 only
cd CapExpet/capClone1
chmod +x setup-capClone1-launcher.sh
./setup-capClone1-launcher.sh
```

## 📱 Usage

### Method 1: Applications Menu
1. Open Activities (Super key)
2. Search for "capClone Project" or "capClone1 Project"
3. Click to launch

### Method 2: Direct Script Execution
```bash
# Launch capClone
./CapExpet/capClone/capClone-launcher.sh

# Launch capClone1
./CapExpet/capClone1/capClone1-launcher.sh
```

## 🔧 How It Works

1. **Backend Services Start**: 
   - Primary API and Import API launch in separate terminal tabs
   - Scripts wait for services to be ready

2. **Port Monitoring**:
   - Checks if services are running on expected ports
   - Waits up to 60 seconds for each service

3. **Frontend Launch**:
   - Once both APIs are confirmed running, frontend starts
   - All services run simultaneously in separate terminals

4. **User Feedback**:
   - Clear status messages throughout the process
   - Success/failure notifications

## ⚙️ Configuration

### Port Customization
Edit the respective launcher scripts to change ports:

**capClone** (`capClone/capClone-launcher.sh`):
```bash
# Line ~58-63: Change these port numbers
if ! check_service 3000 "Primary API"; then
if ! check_service 3001 "Import API"; then
```

**capClone1** (`capClone1/capClone1-launcher.sh`):
```bash
# Line ~58-63: Change these port numbers
if ! check_service 8080 "Primary API"; then
if ! check_service 8081 "Import API"; then
```

### Path Customization
Update the project paths in the launcher scripts:

```bash
# Change these paths if your projects are located elsewhere
start_service "/var/www/html/capClone/primaryAPI" "npm run start:dev" "Primary API"
start_service "/var/www/html/capClone/importAPI" "npm run start:dev" "Import API"
start_service "/var/www/html/capClone/capExpertApp" "npm run start:dev" "Frontend"
```

## 🛠️ Troubleshooting

### Services Not Starting
- Verify Node.js and Yarn are installed
- Check project paths exist and are accessible
- Ensure dependencies are installed: `yarn install` in each project directory

### Port Conflicts
```bash
# Check if ports are in use
netstat -tuln | grep :8080
netstat -tuln | grep :8081
```

### Desktop Entry Issues
- Log out and back in to refresh applications menu
- Manual refresh: `update-desktop-database ~/.local/share/applications`
- Check file permissions: `ls -la ~/.local/share/applications/*capClone*`

### Running Both Projects Simultaneously
The system is designed to run both projects at the same time:
- **capClone** uses ports 8080, 8081
- **capClone1** uses ports 8080, 8081
- No port conflicts should occur

## 📊 Project Status Monitoring

### Check Running Services
```bash
# Check all relevant ports
netstat -tuln | grep -E ":(8080|8081)"

# Check specific project
ps aux | grep "capClone\|capClone1"
```

### Stop All Services
```bash
# Kill all Node.js processes (use with caution)
pkill -f "node.*capClone"

# Or close the terminal tabs individually
```

## 🔄 Updates and Maintenance

### Updating Launchers
1. Edit the launcher scripts as needed
2. Re-run the setup scripts to update desktop entries
3. Changes take effect immediately

### Removing Launchers
```bash
# Remove desktop entries
rm ~/.local/share/applications/capClone-launcher.desktop
rm ~/.local/share/applications/capClone1-launcher.desktop

# Update desktop database
update-desktop-database ~/.local/share/applications
```

## 📋 Prerequisites

- **Ubuntu 22.04 LTS** (or compatible)
- **gnome-terminal** (default Ubuntu terminal)
- **Node.js** and **npm** installed
- **netstat** command (usually pre-installed)
- Project directories properly set up with dependencies

## 🎯 Tips

1. **Sequential Launch**: Wait for one project to fully load before starting the other
2. **Port Monitoring**: Check the terminal output for port status messages
3. **Error Handling**: If a service fails, check the specific terminal tab for error details
4. **Resource Management**: Both projects can be resource-intensive; monitor system performance

---

## 🆘 Support

If you encounter issues:
1. Check terminal output for specific error messages
2. Verify all paths and ports are correctly configured
3. Test individual services manually before using the launchers
4. Ensure all project dependencies are properly installed

## 🎉 Success!

Once configured, you'll have:
- ✅ Two independent project launchers
- ✅ Proper service sequencing
- ✅ Port conflict prevention
- ✅ Ubuntu Applications menu integration
- ✅ Easy one-click project startup

**Happy Coding!** 🚀 # CapExpert-Project-Run
