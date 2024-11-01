#!/bin/bash

# blackdragon-installer.sh
# Automated installer for Black Dragon Viewer on Arch Linux

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${GREEN}[BlackDragon Installer]${NC} $1"
}

print_error() {
    echo -e "${RED}[Error]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[Warning]${NC} $1"
}

# Check if running on Arch Linux
if [ ! -f /etc/arch-release ]; then
    print_error "This script is designed for Arch Linux only."
    exit 1
fi

# Check if script is run as normal user (not root)
if [ "$EUID" -eq 0 ]; then
    print_error "Please run this script as a normal user, not as root."
    exit 1
fi

# Function to check if a package is installed
is_installed() {
    pacman -Qi "$1" &> /dev/null
    return $?
}

# Function to install required packages
install_dependencies() {
    print_message "Installing required packages..."
    
    local packages=("wine" "wine-mono" "wine-gecko" "winetricks" "zenity" "wget")
    local missing_packages=()

    for pkg in "${packages[@]}"; do
        if ! is_installed "$pkg"; then
            missing_packages+=("$pkg")
        fi
    done

    if [ ${#missing_packages[@]} -ne 0 ]; then
        print_message "Installing missing packages: ${missing_packages[*]}"
        sudo pacman -S --needed --noconfirm "${missing_packages[@]}" || {
            print_error "Failed to install required packages."
            exit 1
        }
    fi
}

# Function to setup Wine prefix
setup_wine_prefix() {
    print_message "Setting up Wine prefix..."
    
    export WINEPREFIX="$HOME/.wine_blackdragon"
    export WINEARCH=win64

    # Remove existing prefix if it exists
    if [ -d "$WINEPREFIX" ]; then
        print_warning "Existing Wine prefix found. Removing..."
        rm -rf "$WINEPREFIX"
    fi

    # Initialize new prefix
    wineboot -i || {
        print_error "Failed to initialize Wine prefix."
        exit 1
    }
}

# Function to install Visual C++ Redistributables
install_vcrun() {
    print_message "Installing Visual C++ Redistributables..."
    
    WINEPREFIX="$HOME/.wine_blackdragon" winetricks -q vcrun2013 || {
        print_error "Failed to install Visual C++ 2013."
        exit 1
    }
    
    WINEPREFIX="$HOME/.wine_blackdragon" winetricks -q vcrun2019 || {
        print_error "Failed to install Visual C++ 2019."
        exit 1
    }
}

# Function to download and install Black Dragon Viewer
install_blackdragon() {
    print_message "Downloading Black Dragon Viewer..."
    
    local download_dir="$HOME/Downloads"
    mkdir -p "$download_dir"
    
    # Note: URL needs to be updated when new versions are released
    #local download_url="https://drive.google.com/file/d/1i7cFVMhAhMAZqsGdOSWNtL31N2Asjszk/view?usp=drive_link"
    local installer="$download_dir/BlackDragon_64x_5.1.3.exe"

    zenity --info --text="Please download Black Dragon Viewer from:\nhttps://niranv-sl.blogspot.com/\n\nSave it to your Downloads folder and name it 'BlackDragonSetup.exe'" --width=400

    # Wait for the file to exist
    while [ ! -f "$installer" ]; do
        sleep 1
    done

    print_message "Installing Black Dragon Viewer..."
    WINEPREFIX="$HOME/.wine_blackdragon" wine "$installer" || {
        print_error "Failed to install Black Dragon Viewer."
        exit 1
    }
}

# Function to create launcher script
create_launcher() {
    print_message "Creating launcher script..."
    
    mkdir -p "$HOME/.local/bin"
    cat > "$HOME/.local/bin/blackdragon-launcher.sh" << 'EOL'
#!/bin/bash

export WINEPREFIX="$HOME/.wine_blackdragon"
export WINEARCH=win64
export DXVK_HUD=0
export DXVK_STATE_CACHE=1

# Verify DLL existence
if [ ! -f "$WINEPREFIX/drive_c/windows/system32/MSVCR120.dll" ] || \
   [ ! -f "$WINEPREFIX/drive_c/windows/system32/MSVCR140.dll" ]; then
    zenity --error --text="Required Visual C++ DLLs not found. Please verify Visual C++ Redistributables installation."
    exit 1
fi

cd "$WINEPREFIX/drive_c/Program Files/Black Dragon/"
wine "Black Dragon.exe"
EOL

    chmod +x "$HOME/.local/bin/blackdragon-launcher.sh"
}

# Function to create desktop entry
create_desktop_entry() {
    print_message "Creating desktop entry..."
    
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/blackdragon.desktop" << EOL
[Desktop Entry]
Name=Black Dragon Viewer
Comment=Second Life Viewer
Exec=$HOME/.local/bin/blackdragon-launcher.sh
Type=Application
Categories=Game;
Icon=$HOME/.wine_blackdragon/drive_c/Program Files/Black Dragon/Black Dragon.exe
Terminal=false
EOL
}

# Main installation process
main() {
    print_message "Starting Black Dragon Viewer installation..."
    
    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        print_warning "Added ~/.local/bin to PATH. Please restart your terminal after installation."
    fi

    install_dependencies
    setup_wine_prefix
    install_vcrun
    install_blackdragon
    create_launcher
    create_desktop_entry

    print_message "Installation completed successfully!"
    print_message "You can now launch Black Dragon Viewer from your application menu or by running 'blackdragon-launcher.sh'"
    print_warning "Please restart your desktop environment or computer for the changes to take effect."
}

# Run the installer
main

exit 0

