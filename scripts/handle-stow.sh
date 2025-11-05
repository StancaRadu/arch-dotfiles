#!/bin/bash

# handle-stow.sh - Manage dotfiles with GNU Stow

STOW_DIR="$HOME/Projects/arch-dotfiles/stow"
TARGET_DIR="$HOME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get all available packages
get_packages() {
    cd "$STOW_DIR" && find . -maxdepth 1 -type d ! -name ".*" -printf "%f\n" | sort
}

# Print colored message
print_msg() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Show menu
show_menu() {
    echo ""
    print_msg "$BLUE" "==================================="
    print_msg "$BLUE" "     Dotfiles Stow Manager"
    print_msg "$BLUE" "==================================="
    echo ""
    echo "1) Stow all packages"
    echo "2) Unstow all packages"
    echo "3) Restow all packages (unstow + stow)"
    echo "4) Stow specific package"
    echo "5) Unstow specific package"
    echo "6) Restow specific package"
    echo "7) Show stow status"
    echo "8) Adopt existing configs"
    echo "9) Dry run (simulate stow)"
    echo "0) Exit"
    echo ""
}

# Stow all packages
stow_all() {
    print_msg "$GREEN" "Stowing all packages..."
    cd "$STOW_DIR"
    for package in $(get_packages); do
        print_msg "$YELLOW" "  → Stowing $package..."
        stow -t "$TARGET_DIR" "$package" 2>&1 | grep -v "BUG in find_stowed_path"
    done
    print_msg "$GREEN" "✓ All packages stowed!"
}

# Unstow all packages
unstow_all() {
    print_msg "$RED" "Unstowing all packages..."
    cd "$STOW_DIR"
    for package in $(get_packages); do
        print_msg "$YELLOW" "  → Unstowing $package..."
        stow -D -t "$TARGET_DIR" "$package" 2>&1 | grep -v "BUG in find_stowed_path"
    done
    print_msg "$GREEN" "✓ All packages unstowed!"
}

# Restow all packages
restow_all() {
    print_msg "$BLUE" "Restowing all packages..."
    cd "$STOW_DIR"
    for package in $(get_packages); do
        print_msg "$YELLOW" "  → Restowing $package..."
        stow -R -t "$TARGET_DIR" "$package" 2>&1 | grep -v "BUG in find_stowed_path"
    done
    print_msg "$GREEN" "✓ All packages restowed!"
}

# Stow specific package
stow_package() {
    echo ""
    print_msg "$BLUE" "Available packages:"
    local i=1
    local packages=($(get_packages))
    for pkg in "${packages[@]}"; do
        echo "  $i) $pkg"
        ((i++))
    done
    echo ""
    read -p "Enter package number or name: " choice
    
    local package=""
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        package="${packages[$((choice-1))]}"
    else
        package="$choice"
    fi
    
    if [[ -d "$STOW_DIR/$package" ]]; then
        print_msg "$GREEN" "Stowing $package..."
        cd "$STOW_DIR"
        stow -t "$TARGET_DIR" "$package"
        print_msg "$GREEN" "✓ $package stowed!"
    else
        print_msg "$RED" "✗ Package '$package' not found!"
    fi
}

# Unstow specific package
unstow_package() {
    echo ""
    print_msg "$BLUE" "Available packages:"
    local i=1
    local packages=($(get_packages))
    for pkg in "${packages[@]}"; do
        echo "  $i) $pkg"
        ((i++))
    done
    echo ""
    read -p "Enter package number or name: " choice
    
    local package=""
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        package="${packages[$((choice-1))]}"
    else
        package="$choice"
    fi
    
    if [[ -d "$STOW_DIR/$package" ]]; then
        print_msg "$RED" "Unstowing $package..."
        cd "$STOW_DIR"
        stow -D -t "$TARGET_DIR" "$package"
        print_msg "$GREEN" "✓ $package unstowed!"
    else
        print_msg "$RED" "✗ Package '$package' not found!"
    fi
}

# Restow specific package
restow_package() {
    echo ""
    print_msg "$BLUE" "Available packages:"
    local i=1
    local packages=($(get_packages))
    for pkg in "${packages[@]}"; do
        echo "  $i) $pkg"
        ((i++))
    done
    echo ""
    read -p "Enter package number or name: " choice
    
    local package=""
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        package="${packages[$((choice-1))]}"
    else
        package="$choice"
    fi
    
    if [[ -d "$STOW_DIR/$package" ]]; then
        print_msg "$BLUE" "Restowing $package..."
        cd "$STOW_DIR"
        stow -R -t "$TARGET_DIR" "$package"
        print_msg "$GREEN" "✓ $package restowed!"
    else
        print_msg "$RED" "✗ Package '$package' not found!"
    fi
}

# Show stow status
show_status() {
    print_msg "$BLUE" "Checking stow status..."
    echo ""
    cd "$STOW_DIR"
    for package in $(get_packages); do
        echo -n "  $package: "
        # Check if any files from this package are symlinked
        local stowed=false
        while IFS= read -r -d '' file; do
            local rel_path="${file#$STOW_DIR/$package/}"
            local target_file="$TARGET_DIR/$rel_path"
            if [[ -L "$target_file" ]]; then
                stowed=true
                break
            fi
        done < <(find "$STOW_DIR/$package" -type f -print0)
        
        if $stowed; then
            print_msg "$GREEN" "✓ stowed"
        else
            print_msg "$RED" "✗ not stowed"
        fi
    done
}

# Adopt existing configs
adopt_configs() {
    print_msg "$YELLOW" "⚠ WARNING: This will overwrite files in your repo with existing configs!"
    read -p "Continue? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        print_msg "$BLUE" "Adopting existing configs..."
        cd "$STOW_DIR"
        for package in $(get_packages); do
            print_msg "$YELLOW" "  → Adopting $package..."
            stow --adopt -t "$TARGET_DIR" "$package" 2>&1 | grep -v "BUG in find_stowed_path"
        done
        print_msg "$GREEN" "✓ Configs adopted!"
        print_msg "$YELLOW" "→ Don't forget to review changes with 'git diff'"
    else
        print_msg "$RED" "Cancelled."
    fi
}

# Dry run
dry_run() {
    print_msg "$BLUE" "Simulating stow (no changes will be made)..."
    echo ""
    cd "$STOW_DIR"
    for package in $(get_packages); do
        print_msg "$YELLOW" "  → Simulating $package..."
        stow -n -v -t "$TARGET_DIR" "$package" 2>&1 | grep -v "BUG in find_stowed_path"
    done
    print_msg "$GREEN" "✓ Simulation complete!"
}

# Main loop
main() {
    while true; do
        show_menu
        read -p "Enter choice [0-9]: " choice
        
        case $choice in
            1) stow_all ;;
            2) unstow_all ;;
            3) restow_all ;;
            4) stow_package ;;
            5) unstow_package ;;
            6) restow_package ;;
            7) show_status ;;
            8) adopt_configs ;;
            9) dry_run ;;
            0) print_msg "$GREEN" "Goodbye!"; exit 0 ;;
            *) print_msg "$RED" "Invalid choice. Please try again." ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Check if stow is installed
if ! command -v stow &> /dev/null; then
    print_msg "$RED" "✗ GNU Stow is not installed!"
    echo "  Install it with: sudo pacman -S stow"
    exit 1
fi

# Run main menu
main