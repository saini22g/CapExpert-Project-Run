# CapExpert Ubuntu Launcher System

This system provides a unified Ubuntu launcher for **CapExpert** projects with intelligent project folder selection, proper service sequencing, and port management.

## 📁 Directory Structure

```
CapExpert/
├── launcher.sh                    # Main launcher script with project selection
├── launcher.desktop               # Ubuntu desktop entry
├── setup-launcher.sh              # Installation script
├── services-dialog.py             # Start window: folder, run.sh or Docker, services (Cancel / Restart / Start)
├── logo-small.svg                 # Application icon
└── README.md                      # This file
```

## ✨ Features

- 🎯 **One Start Window**: Pick capClone, capClone1, capClone2 or capCloneDev, run.sh or Docker, and what to start — Primary API, Import API, capExpertApp, Capture / Sticker / CAD, both ngrok tunnels — with **Start**, **Restart** and **Cancel**
- 🐳 **run.sh or Docker**: The web stack runs as dev watchers through `run.sh`, or as production containers through `docker-run.sh`
- 🔗 **Shared Run Scripts**: `run.sh`, `docker-run.sh` and `wr.sh` live once in `/var/www/html/CapExpert_run` and are linked into every folder
- 🚀 **Smart Startup Sequencing**: run.sh / docker-run.sh start the APIs first; the frontend waits for them
- 🔍 **Port Monitoring**: Reports whether each ticked web service came up on its port
- 🎨 **Multi-Tab Operation**: Each service's log is followed in a tab; run.sh, docker-run.sh and wr.sh each open their own window
- 📱 **Ubuntu Integration**: Launcher appears in Applications menu
- 🖥️ **Desktop Shortcuts**: Icon created directly on your desktop
- ⚡ **Parallel Backend Startup**: Both APIs start simultaneously for faster launch
- 🔄 **Enhanced Error Handling**: Comprehensive service monitoring and feedback
- 🛠️ **Node.js Environment Management**: Automatically sets up Node.js v20.19

## 🏗️ Project Configuration

### Supported Projects
The launcher supports four project folders:
- **capClone**: `/var/www/html/capClone/`
- **capClone1**: `/var/www/html/capClone1/`
- **capClone2**: `/var/www/html/capClone2/`
- **capCloneDev**: `/var/www/html/capCloneDev/`

### Start Window
One window picks everything: the folder, how the web stack runs, and the services to start.
Primary API, Import API and the frontend are ticked, and the line above the buttons says what
**Start** will do. Nothing starts on its own: the window waits for one of its buttons:

| Button | Does |
|---|---|
| **Start** | Starts the ticked services; one that is already running is left alone (Docker: rebuilt and replaced) |
| **Restart** | Stops what is already running for the ticked services first, then starts them fresh (hard reload, `h`) |
| **Cancel** (or Esc) | Starts nothing |

Start and Restart stay greyed out while nothing is ticked, or when the folder has no `backendApi`
or `dbMigrations`.

| Service | Port | Started by |
|---|---|---|
| Primary API / Import API / Frontend | 8080 / 8081 / 4200 | `run.sh`, or `docker-run.sh` when **Runs with** is Docker |
| Capture (API + worker) | 8087 / 8088 | `wr.sh` |
| Sticker (API + worker) | 8083 / 8084 | `wr.sh` |
| CAD (API + worker) | 8085 / 8086 | `wr.sh` |
| Primary API tunnel (ngrok2) / Import API tunnel (ngrok1) | — | launcher tab |

Restart is passed to `run.sh` / `docker-run.sh` / `wr.sh` as `h`; the ngrok tunnels are not covered.

The window is `services-dialog.py` (GTK 4 / libadwaita, the same toolkit zenity 4 draws with).
When it cannot open (no display, no bindings), the launcher falls back to the zenity folder list
and a zenity checklist, or numbered prompts, with Docker and Restart as the last rows.

### Shared Run Scripts (`/var/www/html/CapExpert_run`)
`run.sh` (web / mobile stack, dev watchers), `docker-run.sh` (web stack in Docker) and `wr.sh`
(Python extraction services) exist once, in `/var/www/html/CapExpert_run`, and each folder links
them:

```
/var/www/html/capClone1/run.sh        -> /var/www/html/CapExpert_run/run.sh
/var/www/html/capClone1/docker-run.sh -> /var/www/html/CapExpert_run/docker-run.sh
/var/www/html/capClone1/wr.sh         -> /var/www/html/CapExpert_run/wr.sh
```

They always run the folder they are run from — run inside capClone1, they start capClone1:

1. **The CapExpert launcher** — runs them from the folder picked in the dialog.
2. **From the clone folder** — `cd /var/www/html/capClone2 && ./run.sh` (or `./wr.sh e`).
3. **From inside a project folder** — e.g. in `capClone2/backendApi`, `../run.sh primary` or
   `/var/www/html/CapExpert_run/run.sh primary`: the nearest folder above that has `backendApi`
   and `dbMigrations` is used.

`run.sh` takes `w` (web, default), `m` (mobile), `a` (all), single services (`primary`, `import`,
`fe`, `mobile-api`, `mobile-fe`) and `h`; logs go to `/var/www/html/.run/`, one folder shared by
every workspace. `docker-run.sh` takes `primary`, `import`, `fe`, `h`, `nb`, `stop` and `db`; its logs
are `docker-<name>.log` in the same folder. `wr.sh` takes `c`, `s`, `e`, full service names and `h`.
See the header comment of each script for details.

### run.sh or Docker
The **Runs with** switch in the Web group decides how Primary API, Import API and the frontend
run. The Python services (always `wr.sh`) and the ngrok tunnels are not affected.

| | run.sh (default) | Docker |
|---|---|---|
| What runs | `nest start --watch` and `ng serve`, live reload | Production images under pm2, and the frontend's production build behind nginx, built from a snapshot of the folder |
| Node | nvm 20.19 | 24.22.1, inside the images |
| sudo | No | Asks for the password once, in the launcher's terminal |
| **Start** when already running | Leaves it alone | Rebuilds and replaces its containers; stops with "port in use" when `run.sh` holds the port |
| **Restart** | Stops the ticked services, then starts them | Stops the `run.sh` services on those ports, then builds and starts |
| Logs, in `/var/www/html/.run/` | `<name>.log` | `docker-<name>.log`, plus `docker-fe-build.log` |
| Code edits | Picked up live | Need another Start |
| Frontend | http://localhost:4200 | http://localhost:4200 only (nginx answers `localhost` alone) |

`run.sh` cannot see or stop the Docker containers (they run as root). To go back from Docker to
run.sh, pick run.sh and **Restart**: a ticked port held that way is freed with
`docker-run.sh stop` first, which asks for sudo (and, for the frontend, to reload the page in each
open browser).

All four folders share these ports, so switching folders also needs **Restart**: a plain Start
sees the port in use and leaves the other folder's service running.

### Service Ports
- **Primary API Port**: 8080
- **Import API Port**: 8081
- **Frontend Port**: 4200

### Required Directory Structure (for each project)
```
/var/www/html/[PROJECT_FOLDER]/
├── backendApi/                    # Primary API + Import API (one project, two roles)
├── dbMigrations/                  # Sequelize migrations, not started by the launcher
└── capExpertApp/                  # Frontend application
```

`run.sh`, `docker-run.sh` and `wr.sh` start only a folder that has both `backendApi` and
`dbMigrations`.

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
4. Pick the folder and services in the start window

### Method 2: Desktop Shortcut
1. Double-click the "CapExpert" icon on your desktop
2. Pick the folder and services in the start window

### Method 3: Direct Script Execution
```bash
./CapExpert/launcher.sh
```

## 🔧 How It Works

1. **Start Window**:
   - One window: folder, run.sh or Docker for the web stack, the services, and Start / Restart / Cancel
     (see *Start Window*)
   - Waits for Start, Restart or Cancel; nothing starts on its own

2. **Workspace Check**:
   - The folder must have `backendApi` and `dbMigrations`; otherwise the launcher stops with an error

3. **Services Start** (the web stack last, as a Docker build takes a while):
   - The ticked Python services start through `/var/www/html/CapExpert_run/wr.sh` on the
     selected folder's database
   - The ticked ngrok tunnels start in tabs of their own
   - The ticked Primary API / Import API / frontend start through `/var/www/html/CapExpert_run/run.sh`
     (with nvm's Node loaded), or `docker-run.sh` with Docker, run from the selected folder, in their
     own window

4. **Port Monitoring**:
   - Checks that the ticked web services come up on their ports (8080, 8081, 4200)
   - Waits up to 10 minutes for each service with 5-second intervals
   - Provides real-time feedback on startup progress

5. **Service Management**:
   - Each service's log is followed in a named tab of the run.sh / docker-run.sh / wr.sh window
   - Closing a tab or Ctrl+C in it stops following the log, not the service: use **Restart** to stop
     and start again

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
MAX_WAIT_SECONDS=600  # 10 minutes max wait time
CHECK_INTERVAL=5     # Check every 5 seconds
```

### Project Folders
The folders the start window offers are `PROJECT_FOLDERS` in `launcher.sh`; the first is selected
(the zenity fallback keeps its own list in `select_project_folder`):

```bash
PROJECT_FOLDERS=(capClone capClone1 capClone2 capCloneDev)
```

`PROJECT_ROOT` is `/var/www/html/$PROJECT_FOLDER`; the shared scripts are in `RUN_DIR`.

### Node.js Version
Change the required Node.js version:

```bash
# Around line 64
nvm use 20.19 2>/dev/null
```

## 🛠️ Troubleshooting

### Services Not Starting
- Verify Node.js v20.19 is installed via NVM
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

A port held by Docker belongs to root and pm2 restarts the app, so killing it does not stick: run
`./docker-run.sh stop` from a workspace folder, or **Restart** with run.sh in the start window.

### Desktop Entry Issues
- Log out and back in to refresh applications menu
- Manual refresh: `update-desktop-database ~/.local/share/applications`
- Check file permissions: `ls -la ~/.local/share/applications/CapExpert-launcher.desktop`

### NVM/Node.js Issues
```bash
# Install NVM if not present
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Install Node.js v20.19
nvm install 20.19
nvm use 20.19
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
- Each service's log is followed in its own terminal tab
- Logs stay in `/var/www/html/.run/<service>.log` (Docker: `docker-<service>.log`), one folder shared
  by every workspace

### Stop Services
- **Restart** in the start window stops and starts the ticked services
- A `run.sh` service: `kill -TERM -- -$(cat /var/www/html/.run/primary.pid)` (`import`, `fe`), which ends
  its whole process group; killing just the port holder leaves the watcher to start it again
- Docker: `cd /var/www/html/capClone && ./docker-run.sh stop` (from any workspace folder; with the
  frontend running it asks you to reload the page, then press Enter)
- ngrok: Ctrl+C in its tab

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
- **Node.js v20.19** (automatically managed via NVM)
- **netstat** command (usually pre-installed)
- **python3 with GTK 4 / libadwaita 1.4+ bindings** for the start window (Ubuntu 24.04+; older
  systems get the zenity fallback)
- **Docker**, only for Docker mode (`docker-run.sh` runs it with sudo)
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
5. **Node.js Version**: Confirm Node.js v20.19 is available via NVM

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
