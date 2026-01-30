#!/bin/bash
#
# Wazuh Multi-Vendor Integration Installer
# Version: 1.0.0
#
# Modular installation system for NAS, Network, and Security devices
# Supports: Synology, QNAP, Mikrotik, and extensible for more
#
# Usage: sudo ./install.sh
#
# Author: Riccardo Grandi (@grandir66)
# Repository: https://github.com/grandir66/wazuh-multivendor-installer
#

# Don't exit on error - we handle errors manually
set +e

# Disable bash history expansion for passwords with special characters
set +H

#==============================================================================
# CONFIGURATION
#==============================================================================

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/modules"
DASHBOARDS_DIR="${SCRIPT_DIR}/dashboards"
LOG_FILE="/var/log/wazuh-multivendor-installer.log"

# Wazuh paths
WAZUH_DIR="/var/ossec"
WAZUH_DECODERS="${WAZUH_DIR}/etc/decoders"
WAZUH_RULES="${WAZUH_DIR}/etc/rules"
WAZUH_CONF="${WAZUH_DIR}/etc/ossec.conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

#==============================================================================
# LOGGING
#==============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
}

log_info() { log "INFO" "$*"; }
log_warn() { log "WARN" "$*"; }
log_error() { log "ERROR" "$*"; }

#==============================================================================
# UI FUNCTIONS
#==============================================================================

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║     ${BOLD}Wazuh Multi-Vendor Integration Installer${NC}${CYAN}                     ║"
    echo "║                                                                  ║"
    echo "║     Version: ${VERSION}                                              ║"
    echo "║     Author: Riccardo Grandi (@grandir66)                          ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_ok() { echo -e "  ${GREEN}✓${NC} $1"; }
print_warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "  ${RED}✗${NC} $1"; }
print_info() { echo -e "  ${BLUE}ℹ${NC} $1"; }
print_install() { echo -e "  ${MAGENTA}▶${NC} $1"; }

#==============================================================================
# MODULE DISCOVERY
#==============================================================================

declare -A MODULE_INFO
declare -A MODULE_STATUS

discover_modules() {
    print_section "Discovering Available Modules"
    
    if [ ! -d "$MODULES_DIR" ]; then
        print_error "Modules directory not found: $MODULES_DIR"
        return 1
    fi
    
    local count=0
    for module_dir in "$MODULES_DIR"/*/; do
        if [ -d "$module_dir" ]; then
            local module_name=$(basename "$module_dir")
            local manifest="${module_dir}/manifest.conf"
            
            if [ -f "$manifest" ]; then
                # Read manifest
                local display_name=$(grep "^name=" "$manifest" | cut -d'=' -f2-)
                local description=$(grep "^description=" "$manifest" | cut -d'=' -f2-)
                local version=$(grep "^version=" "$manifest" | cut -d'=' -f2-)
                local category=$(grep "^category=" "$manifest" | cut -d'=' -f2-)
                local rule_id_start=$(grep "^rule_id_start=" "$manifest" | cut -d'=' -f2-)
                local rule_id_end=$(grep "^rule_id_end=" "$manifest" | cut -d'=' -f2-)
                
                MODULE_INFO["${module_name}_name"]="$display_name"
                MODULE_INFO["${module_name}_desc"]="$description"
                MODULE_INFO["${module_name}_version"]="$version"
                MODULE_INFO["${module_name}_category"]="$category"
                MODULE_INFO["${module_name}_rule_start"]="$rule_id_start"
                MODULE_INFO["${module_name}_rule_end"]="$rule_id_end"
                MODULE_INFO["${module_name}_path"]="$module_dir"
                
                # Check if installed
                check_module_installed "$module_name"
                
                count=$((count + 1))
            fi
        fi
    done
    
    print_ok "Found $count available modules"
    echo ""
}

check_module_installed() {
    local module_name="$1"
    local module_dir="${MODULE_INFO["${module_name}_path"]}"
    
    # Check for decoder file
    local decoder_file=$(find "$module_dir" -name "*decoder*.xml" -o -name "*decoders*.xml" 2>/dev/null | head -1)
    local rules_file=$(find "$module_dir" -name "*rules*.xml" 2>/dev/null | head -1)
    
    local installed="no"
    local partial="no"
    
    if [ -n "$decoder_file" ]; then
        local decoder_name=$(basename "$decoder_file")
        if [ -f "${WAZUH_DECODERS}/${decoder_name}" ]; then
            installed="yes"
        fi
    fi
    
    if [ -n "$rules_file" ]; then
        local rules_name=$(basename "$rules_file")
        if [ -f "${WAZUH_RULES}/${rules_name}" ]; then
            if [ "$installed" = "yes" ]; then
                installed="yes"
            else
                partial="yes"
            fi
        elif [ "$installed" = "yes" ]; then
            partial="yes"
            installed="no"
        fi
    fi
    
    # Check for special components (Python decoder, systemd service, etc.)
    local special_check="${module_dir}/check-installed.sh"
    if [ -f "$special_check" ]; then
        if bash "$special_check" 2>/dev/null; then
            installed="yes"
        else
            if [ "$installed" = "yes" ]; then
                partial="yes"
            fi
            installed="no"
        fi
    fi
    
    if [ "$installed" = "yes" ]; then
        MODULE_STATUS["$module_name"]="installed"
    elif [ "$partial" = "yes" ]; then
        MODULE_STATUS["$module_name"]="partial"
    else
        MODULE_STATUS["$module_name"]="not_installed"
    fi
}

#==============================================================================
# DISPLAY MODULES
#==============================================================================

display_modules() {
    print_section "Available Modules"
    
    echo ""
    echo -e "  ${BOLD}#   Module                Status      Category     Description${NC}"
    echo -e "  ─────────────────────────────────────────────────────────────────────────"
    
    local i=1
    for module_dir in "$MODULES_DIR"/*/; do
        if [ -d "$module_dir" ]; then
            local module_name=$(basename "$module_dir")
            local manifest="${module_dir}/manifest.conf"
            
            if [ -f "$manifest" ]; then
                local display_name="${MODULE_INFO["${module_name}_name"]}"
                local description="${MODULE_INFO["${module_name}_desc"]}"
                local category="${MODULE_INFO["${module_name}_category"]}"
                local status="${MODULE_STATUS["$module_name"]}"
                
                # Format status with color
                local status_display
                case "$status" in
                    "installed")
                        status_display="${GREEN}Installed${NC}"
                        ;;
                    "partial")
                        status_display="${YELLOW}Partial${NC}"
                        ;;
                    *)
                        status_display="${RED}Not Installed${NC}"
                        ;;
                esac
                
                # Truncate description
                local desc_short="${description:0:35}"
                [ ${#description} -gt 35 ] && desc_short="${desc_short}..."
                
                printf "  %-3s %-20s %-18b %-12s %s\n" "$i" "$display_name" "$status_display" "$category" "$desc_short"
                
                i=$((i + 1))
            fi
        fi
    done
    
    echo ""
}

#==============================================================================
# MODULE INSTALLATION
#==============================================================================

install_module() {
    local module_name="$1"
    local module_dir="${MODULE_INFO["${module_name}_path"]}"
    local display_name="${MODULE_INFO["${module_name}_name"]}"
    
    print_section "Installing: $display_name"
    log_info "Starting installation of module: $module_name"
    
    # Check for custom install script
    local custom_install="${module_dir}/install.sh"
    if [ -f "$custom_install" ]; then
        print_install "Running custom installer..."
        if bash "$custom_install"; then
            print_ok "Custom installation completed"
            log_info "Custom installation completed for $module_name"
        else
            print_error "Custom installation failed"
            log_error "Custom installation failed for $module_name"
            return 1
        fi
    else
        # Standard installation
        install_standard_module "$module_name" "$module_dir"
    fi
    
    MODULE_STATUS["$module_name"]="installed"
    print_ok "$display_name installed successfully"
}

install_standard_module() {
    local module_name="$1"
    local module_dir="$2"
    
    # Install decoders
    for decoder_file in "$module_dir"/*decoder*.xml "$module_dir"/*decoders*.xml; do
        if [ -f "$decoder_file" ]; then
            local filename=$(basename "$decoder_file")
            print_install "Installing decoder: $filename"
            
            cp "$decoder_file" "${WAZUH_DECODERS}/${filename}"
            chown root:wazuh "${WAZUH_DECODERS}/${filename}"
            chmod 640 "${WAZUH_DECODERS}/${filename}"
            
            print_ok "Decoder installed"
        fi
    done
    
    # Install rules
    for rules_file in "$module_dir"/*rules*.xml; do
        if [ -f "$rules_file" ]; then
            local filename=$(basename "$rules_file")
            print_install "Installing rules: $filename"
            
            cp "$rules_file" "${WAZUH_RULES}/${filename}"
            chown root:wazuh "${WAZUH_RULES}/${filename}"
            chmod 640 "${WAZUH_RULES}/${filename}"
            
            print_ok "Rules installed"
        fi
    done
    
    # Install additional files (Python scripts, configs, etc.)
    local files_dir="${module_dir}/files"
    if [ -d "$files_dir" ]; then
        local files_manifest="${files_dir}/install.manifest"
        if [ -f "$files_manifest" ]; then
            while IFS=':' read -r src dest perms owner; do
                if [ -n "$src" ] && [ -n "$dest" ]; then
                    print_install "Installing: $src → $dest"
                    cp "${files_dir}/${src}" "$dest"
                    [ -n "$perms" ] && chmod "$perms" "$dest"
                    [ -n "$owner" ] && chown "$owner" "$dest"
                fi
            done < "$files_manifest"
        fi
    fi
    
    # Install systemd services
    for service_file in "$module_dir"/*.service; do
        if [ -f "$service_file" ]; then
            local filename=$(basename "$service_file")
            local service_name="${filename%.service}"
            print_install "Installing service: $filename"
            
            cp "$service_file" "/etc/systemd/system/${filename}"
            chmod 644 "/etc/systemd/system/${filename}"
            
            systemctl daemon-reload
            systemctl enable "$service_name"
            systemctl start "$service_name"
            
            print_ok "Service installed and started"
        fi
    done
}

#==============================================================================
# MODULE UNINSTALLATION
#==============================================================================

uninstall_module() {
    local module_name="$1"
    local module_dir="${MODULE_INFO["${module_name}_path"]}"
    local display_name="${MODULE_INFO["${module_name}_name"]}"
    
    print_section "Uninstalling: $display_name"
    log_info "Starting uninstallation of module: $module_name"
    
    # Check for custom uninstall script
    local custom_uninstall="${module_dir}/uninstall.sh"
    if [ -f "$custom_uninstall" ]; then
        print_install "Running custom uninstaller..."
        if bash "$custom_uninstall"; then
            print_ok "Custom uninstallation completed"
        else
            print_error "Custom uninstallation failed"
            return 1
        fi
    else
        # Standard uninstallation
        uninstall_standard_module "$module_name" "$module_dir"
    fi
    
    MODULE_STATUS["$module_name"]="not_installed"
    print_ok "$display_name uninstalled successfully"
}

uninstall_standard_module() {
    local module_name="$1"
    local module_dir="$2"
    
    # Remove decoders
    for decoder_file in "$module_dir"/*decoder*.xml "$module_dir"/*decoders*.xml; do
        if [ -f "$decoder_file" ]; then
            local filename=$(basename "$decoder_file")
            if [ -f "${WAZUH_DECODERS}/${filename}" ]; then
                print_install "Removing decoder: $filename"
                rm -f "${WAZUH_DECODERS}/${filename}"
                print_ok "Decoder removed"
            fi
        fi
    done
    
    # Remove rules
    for rules_file in "$module_dir"/*rules*.xml; do
        if [ -f "$rules_file" ]; then
            local filename=$(basename "$rules_file")
            if [ -f "${WAZUH_RULES}/${filename}" ]; then
                print_install "Removing rules: $filename"
                rm -f "${WAZUH_RULES}/${filename}"
                print_ok "Rules removed"
            fi
        fi
    done
    
    # Stop and remove systemd services
    for service_file in "$module_dir"/*.service; do
        if [ -f "$service_file" ]; then
            local filename=$(basename "$service_file")
            local service_name="${filename%.service}"
            if [ -f "/etc/systemd/system/${filename}" ]; then
                print_install "Removing service: $filename"
                systemctl stop "$service_name" 2>/dev/null || true
                systemctl disable "$service_name" 2>/dev/null || true
                rm -f "/etc/systemd/system/${filename}"
                systemctl daemon-reload
                print_ok "Service removed"
            fi
        fi
    done
}

#==============================================================================
# DASHBOARD INSTALLATION
#==============================================================================

install_dashboards() {
    print_section "Dashboard Installation"
    
    if [ ! -d "$DASHBOARDS_DIR" ]; then
        print_warn "No dashboards directory found"
        return 0
    fi
    
    local dashboard_count=$(find "$DASHBOARDS_DIR" -name "*.ndjson" 2>/dev/null | wc -l)
    if [ "$dashboard_count" -eq 0 ]; then
        print_warn "No dashboard files found"
        return 0
    fi
    
    echo ""
    echo -e "  Found ${GREEN}$dashboard_count${NC} dashboard(s) available for import."
    echo ""
    read -p "  Do you want to import dashboards? (y/n): " import_choice
    
    if [[ ! "$import_choice" =~ ^[Yy]$ ]]; then
        print_info "Skipping dashboard import"
        return 0
    fi
    
    # Get Wazuh Dashboard URL
    echo ""
    read -p "  Wazuh Dashboard URL (e.g., https://wazuh.example.com): " WAZUH_URL
    
    if [ -z "$WAZUH_URL" ]; then
        print_error "URL cannot be empty"
        return 1
    fi
    
    # Remove trailing slash
    WAZUH_URL="${WAZUH_URL%/}"
    
    # Get credentials
    echo ""
    read -p "  Username: " WAZUH_USER
    echo -n "  Password: "
    IFS= read -rs WAZUH_PASS
    echo ""
    
    if [ -z "$WAZUH_USER" ] || [ -z "$WAZUH_PASS" ]; then
        print_error "Credentials cannot be empty"
        return 1
    fi
    
    # Create netrc file for secure credential handling
    local NETRC_FILE=$(mktemp)
    chmod 600 "$NETRC_FILE"
    cat > "$NETRC_FILE" << NETRC_EOF
machine $(echo "$WAZUH_URL" | sed -E 's|https?://||' | sed 's|/.*||' | sed 's|:.*||')
login ${WAZUH_USER}
password ${WAZUH_PASS}
NETRC_EOF
    
    # Cleanup on exit
    trap "rm -f '$NETRC_FILE' 2>/dev/null" EXIT
    
    # Test connection
    echo ""
    print_install "Testing connection..."
    
    local HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" \
        --netrc-file "$NETRC_FILE" \
        "${WAZUH_URL}/api/status" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "000" ]; then
        print_error "Cannot connect to $WAZUH_URL"
        rm -f "$NETRC_FILE"
        return 1
    elif [ "$HTTP_CODE" = "401" ]; then
        print_error "Authentication failed (401)"
        rm -f "$NETRC_FILE"
        return 1
    elif [ "$HTTP_CODE" != "200" ]; then
        print_warn "Unexpected response: HTTP $HTTP_CODE"
    else
        print_ok "Connection successful"
    fi
    
    # Import dashboards
    echo ""
    local success=0
    local failed=0
    
    for dashboard in "$DASHBOARDS_DIR"/*.ndjson; do
        if [ -f "$dashboard" ]; then
            local filename=$(basename "$dashboard")
            print_install "Importing: $filename"
            
            local RESPONSE=$(curl -k -s -X POST \
                "${WAZUH_URL}/api/saved_objects/_import?overwrite=true" \
                -H "osd-xsrf: true" \
                -H "Content-Type: multipart/form-data" \
                --netrc-file "$NETRC_FILE" \
                -F "file=@${dashboard}" 2>&1)
            
            if echo "$RESPONSE" | grep -qE '"success":true|"successCount"'; then
                print_ok "Imported successfully"
                success=$((success + 1))
            else
                print_error "Import failed"
                failed=$((failed + 1))
            fi
        fi
    done
    
    # Cleanup
    rm -f "$NETRC_FILE"
    
    echo ""
    print_ok "Dashboard import complete: $success succeeded, $failed failed"
}

#==============================================================================
# WAZUH OPERATIONS
#==============================================================================

test_wazuh_config() {
    print_install "Testing Wazuh configuration..."
    
    if ${WAZUH_DIR}/bin/wazuh-logtest-legacy -t 2>&1 | grep -q "Configuration OK"; then
        print_ok "Configuration is valid"
        return 0
    else
        print_error "Configuration test failed"
        ${WAZUH_DIR}/bin/wazuh-logtest-legacy -t 2>&1 | tail -20
        return 1
    fi
}

restart_wazuh() {
    print_install "Restarting Wazuh Manager..."
    
    if systemctl restart wazuh-manager; then
        sleep 3
        if systemctl is-active --quiet wazuh-manager; then
            print_ok "Wazuh Manager restarted successfully"
            return 0
        fi
    fi
    
    print_error "Failed to restart Wazuh Manager"
    return 1
}

#==============================================================================
# INTERACTIVE MENU
#==============================================================================

show_main_menu() {
    while true; do
        print_banner
        display_modules
        
        # Show installation location
        echo -e "  ${BOLD}Current Location:${NC} ${SCRIPT_DIR}"
        if [[ "$SCRIPT_DIR" == /tmp/* ]]; then
            echo -e "  ${YELLOW}⚠ Running from /tmp - will be lost on reboot!${NC}"
        fi
        echo ""
        
        echo -e "  ${BOLD}Options:${NC}"
        echo -e "  ─────────────────────────────────────────────────────────────────────────"
        echo -e "  ${GREEN}[I]${NC} Install modules       ${GREEN}[U]${NC} Uninstall modules"
        echo -e "  ${GREEN}[D]${NC} Install dashboards    ${GREEN}[T]${NC} Test configuration"
        echo -e "  ${GREEN}[R]${NC} Restart Wazuh         ${GREEN}[A]${NC} Install ALL modules"
        echo -e "  ${GREEN}[S]${NC} Status summary        ${GREEN}[P]${NC} Install to /opt (permanent)"
        echo -e "  ${GREEN}[Q]${NC} Quit"
        echo ""
        
        read -p "  Select option: " choice
        
        case "${choice,,}" in
            i) select_modules_to_install ;;
            u) select_modules_to_uninstall ;;
            d) install_dashboards ;;
            t) test_wazuh_config; read -p "Press Enter to continue..." ;;
            r) restart_wazuh; read -p "Press Enter to continue..." ;;
            a) install_all_modules ;;
            s) show_status_summary ;;
            p) install_to_opt ;;
            q) 
                echo ""
                print_ok "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

select_modules_to_install() {
    print_section "Select Modules to Install"
    
    echo ""
    echo -e "  Enter module numbers separated by comma (e.g., 1,3,5)"
    echo -e "  Or 'all' to install all modules, 'back' to go back"
    echo ""
    
    # List modules with numbers
    local i=1
    declare -A num_to_module
    
    for module_dir in "$MODULES_DIR"/*/; do
        if [ -d "$module_dir" ]; then
            local module_name=$(basename "$module_dir")
            local manifest="${module_dir}/manifest.conf"
            
            if [ -f "$manifest" ]; then
                local display_name="${MODULE_INFO["${module_name}_name"]}"
                local status="${MODULE_STATUS["$module_name"]}"
                
                if [ "$status" != "installed" ]; then
                    echo -e "  ${GREEN}[$i]${NC} $display_name"
                    num_to_module[$i]="$module_name"
                else
                    echo -e "  ${YELLOW}[$i]${NC} $display_name (already installed)"
                fi
                
                i=$((i + 1))
            fi
        fi
    done
    
    echo ""
    read -p "  Your selection: " selection
    
    if [ "$selection" = "back" ]; then
        return
    fi
    
    if [ "$selection" = "all" ]; then
        install_all_modules
        return
    fi
    
    # Parse selection
    IFS=',' read -ra SELECTED <<< "$selection"
    local modules_to_install=()
    
    for num in "${SELECTED[@]}"; do
        num=$(echo "$num" | tr -d ' ')
        if [ -n "${num_to_module[$num]}" ]; then
            modules_to_install+=("${num_to_module[$num]}")
        fi
    done
    
    if [ ${#modules_to_install[@]} -eq 0 ]; then
        print_error "No valid modules selected"
        sleep 2
        return
    fi
    
    # Install selected modules
    for module in "${modules_to_install[@]}"; do
        install_module "$module"
    done
    
    # Test and restart
    echo ""
    if test_wazuh_config; then
        restart_wazuh
    else
        print_error "Configuration test failed. Rolling back..."
        for module in "${modules_to_install[@]}"; do
            uninstall_module "$module"
        done
    fi
    
    read -p "Press Enter to continue..."
}

select_modules_to_uninstall() {
    print_section "Select Modules to Uninstall"
    
    echo ""
    
    # List installed modules
    local i=1
    declare -A num_to_module
    local has_installed=false
    
    for module_dir in "$MODULES_DIR"/*/; do
        if [ -d "$module_dir" ]; then
            local module_name=$(basename "$module_dir")
            local manifest="${module_dir}/manifest.conf"
            
            if [ -f "$manifest" ]; then
                local display_name="${MODULE_INFO["${module_name}_name"]}"
                local status="${MODULE_STATUS["$module_name"]}"
                
                if [ "$status" = "installed" ] || [ "$status" = "partial" ]; then
                    echo -e "  ${RED}[$i]${NC} $display_name"
                    num_to_module[$i]="$module_name"
                    has_installed=true
                fi
                
                i=$((i + 1))
            fi
        fi
    done
    
    if [ "$has_installed" = false ]; then
        print_info "No modules installed"
        sleep 2
        return
    fi
    
    echo ""
    read -p "  Enter module numbers to uninstall (comma separated) or 'back': " selection
    
    if [ "$selection" = "back" ]; then
        return
    fi
    
    # Parse selection
    IFS=',' read -ra SELECTED <<< "$selection"
    
    for num in "${SELECTED[@]}"; do
        num=$(echo "$num" | tr -d ' ')
        if [ -n "${num_to_module[$num]}" ]; then
            uninstall_module "${num_to_module[$num]}"
        fi
    done
    
    restart_wazuh
    read -p "Press Enter to continue..."
}

install_all_modules() {
    print_section "Installing All Modules"
    
    local installed=0
    local failed=0
    
    for module_dir in "$MODULES_DIR"/*/; do
        if [ -d "$module_dir" ]; then
            local module_name=$(basename "$module_dir")
            local status="${MODULE_STATUS["$module_name"]}"
            
            if [ "$status" != "installed" ]; then
                if install_module "$module_name"; then
                    installed=$((installed + 1))
                else
                    failed=$((failed + 1))
                fi
            fi
        fi
    done
    
    echo ""
    print_ok "Installation complete: $installed installed, $failed failed"
    
    if test_wazuh_config; then
        restart_wazuh
        
        # Ask about dashboards
        install_dashboards
    fi
    
    read -p "Press Enter to continue..."
}

#==============================================================================
# PERMANENT INSTALLATION
#==============================================================================

install_to_opt() {
    print_section "Install to /opt (Permanent)"
    
    local OPT_DIR="/opt/wazuh-multivendor-installer"
    
    # Check if already in /opt
    if [[ "$SCRIPT_DIR" == "$OPT_DIR" ]]; then
        print_ok "Already installed in $OPT_DIR"
        read -p "Press Enter to continue..."
        return 0
    fi
    
    # Check if destination exists
    if [ -d "$OPT_DIR" ]; then
        echo ""
        print_warn "Directory $OPT_DIR already exists"
        echo ""
        echo -e "  ${BOLD}Options:${NC}"
        echo -e "  [1] Overwrite (backup existing)"
        echo -e "  [2] Update (git pull)"
        echo -e "  [3] Cancel"
        echo ""
        read -p "  Select option: " opt_choice
        
        case "$opt_choice" in
            1)
                # Backup and overwrite
                local backup_dir="${OPT_DIR}.backup-$(date +%Y%m%d-%H%M%S)"
                print_install "Backing up to $backup_dir"
                mv "$OPT_DIR" "$backup_dir"
                ;;
            2)
                # Git pull update
                if [ -d "${OPT_DIR}/.git" ]; then
                    print_install "Updating via git pull..."
                    cd "$OPT_DIR"
                    git pull origin main
                    print_ok "Updated successfully"
                    echo ""
                    print_info "Run the installer from the new location:"
                    echo -e "  ${CYAN}cd $OPT_DIR && sudo ./install.sh${NC}"
                    read -p "Press Enter to continue..."
                    return 0
                else
                    print_error "Not a git repository, cannot update"
                    read -p "Press Enter to continue..."
                    return 1
                fi
                ;;
            *)
                print_info "Cancelled"
                read -p "Press Enter to continue..."
                return 0
                ;;
        esac
    fi
    
    # Copy to /opt
    print_install "Copying to $OPT_DIR..."
    
    if cp -r "$SCRIPT_DIR" "$OPT_DIR"; then
        chmod +x "${OPT_DIR}/install.sh"
        chmod +x "${OPT_DIR}/deploy-dashboards.sh" 2>/dev/null || true
        
        print_ok "Installed to $OPT_DIR"
        echo ""
        
        # Create symlink for easy access
        if [ ! -f "/usr/local/bin/wazuh-installer" ]; then
            ln -sf "${OPT_DIR}/install.sh" /usr/local/bin/wazuh-installer
            print_ok "Created symlink: /usr/local/bin/wazuh-installer"
            echo ""
            print_info "You can now run the installer from anywhere:"
            echo -e "  ${CYAN}sudo wazuh-installer${NC}"
        fi
        
        echo ""
        print_info "Or run directly:"
        echo -e "  ${CYAN}cd $OPT_DIR && sudo ./install.sh${NC}"
        echo ""
        
        # Ask if user wants to switch to new location
        read -p "  Switch to new location now? (y/n): " switch_choice
        if [[ "$switch_choice" =~ ^[Yy]$ ]]; then
            echo ""
            print_ok "Restarting from $OPT_DIR..."
            cd "$OPT_DIR"
            exec "${OPT_DIR}/install.sh"
        fi
    else
        print_error "Failed to copy to $OPT_DIR"
    fi
    
    read -p "Press Enter to continue..."
}

show_status_summary() {
    print_section "Status Summary"
    
    echo ""
    
    # Wazuh Manager status
    if systemctl is-active --quiet wazuh-manager; then
        print_ok "Wazuh Manager: Running"
    else
        print_error "Wazuh Manager: Not Running"
    fi
    
    # Module status
    echo ""
    echo -e "  ${BOLD}Installed Modules:${NC}"
    
    local installed_count=0
    for module_dir in "$MODULES_DIR"/*/; do
        if [ -d "$module_dir" ]; then
            local module_name=$(basename "$module_dir")
            local display_name="${MODULE_INFO["${module_name}_name"]}"
            local status="${MODULE_STATUS["$module_name"]}"
            local category="${MODULE_INFO["${module_name}_category"]}"
            
            if [ "$status" = "installed" ]; then
                print_ok "$display_name ($category)"
                installed_count=$((installed_count + 1))
            fi
        fi
    done
    
    if [ $installed_count -eq 0 ]; then
        print_info "No modules installed"
    fi
    
    # Decoder count
    echo ""
    local decoder_count=$(ls -1 "${WAZUH_DECODERS}"/*.xml 2>/dev/null | wc -l)
    local rules_count=$(ls -1 "${WAZUH_RULES}"/*.xml 2>/dev/null | wc -l)
    
    print_info "Custom decoders: $decoder_count files"
    print_info "Custom rules: $rules_count files"
    
    read -p "Press Enter to continue..."
}

#==============================================================================
# PREREQUISITES CHECK
#==============================================================================

check_prerequisites() {
    print_section "Checking Prerequisites"
    
    # Check root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        echo -e "  ${YELLOW}Usage: sudo ./install.sh${NC}"
        exit 1
    fi
    print_ok "Running as root"
    
    # Warn if running from /tmp
    if [[ "$SCRIPT_DIR" == /tmp/* ]]; then
        print_warn "Running from /tmp - files will be lost on reboot!"
        echo -e "  ${YELLOW}Use option [P] in the menu to install permanently to /opt${NC}"
    fi
    
    # Check Wazuh
    if [ ! -d "$WAZUH_DIR" ]; then
        print_error "Wazuh Manager not found in $WAZUH_DIR"
        exit 1
    fi
    print_ok "Wazuh Manager found"
    
    # Check Wazuh service
    if ! systemctl is-active --quiet wazuh-manager; then
        print_warn "Wazuh Manager is not running"
    else
        print_ok "Wazuh Manager is running"
    fi
    
    # Check modules directory
    if [ ! -d "$MODULES_DIR" ]; then
        print_error "Modules directory not found: $MODULES_DIR"
        echo -e "  ${YELLOW}Please ensure the modules folder exists${NC}"
        exit 1
    fi
    print_ok "Modules directory found"
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        print_warn "curl not found (needed for dashboard import)"
    else
        print_ok "curl available"
    fi
    
    echo ""
}

#==============================================================================
# COMMAND LINE INTERFACE
#==============================================================================

show_help() {
    echo "Wazuh Multi-Vendor Integration Installer v${VERSION}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -l, --list          List available modules"
    echo "  -i, --install MOD   Install specific module(s)"
    echo "  -u, --uninstall MOD Uninstall specific module(s)"
    echo "  -a, --all           Install all modules"
    echo "  -d, --dashboards    Import dashboards only"
    echo "  -s, --status        Show status summary"
    echo "  -p, --permanent     Install this tool to /opt"
    echo "  --interactive       Run interactive menu (default)"
    echo ""
    echo "Examples:"
    echo "  $0                      # Interactive menu"
    echo "  $0 -l                   # List modules"
    echo "  $0 -i mikrotik          # Install Mikrotik module"
    echo "  $0 -i synology,qnap     # Install multiple modules"
    echo "  $0 -a                   # Install all modules"
    echo ""
}

#==============================================================================
# MAIN
#==============================================================================

main() {
    # Initialize log
    mkdir -p "$(dirname "$LOG_FILE")"
    log_info "=== Wazuh Multi-Vendor Installer started ==="
    
    # Parse command line
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--list)
            check_prerequisites
            discover_modules
            display_modules
            exit 0
            ;;
        -s|--status)
            check_prerequisites
            discover_modules
            show_status_summary
            exit 0
            ;;
        -a|--all)
            check_prerequisites
            discover_modules
            install_all_modules
            exit 0
            ;;
        -d|--dashboards)
            install_dashboards
            exit 0
            ;;
        -p|--permanent)
            check_prerequisites
            install_to_opt
            exit 0
            ;;
        -i|--install)
            check_prerequisites
            discover_modules
            shift
            IFS=',' read -ra MODULES <<< "$1"
            for mod in "${MODULES[@]}"; do
                install_module "$mod"
            done
            test_wazuh_config && restart_wazuh
            exit 0
            ;;
        -u|--uninstall)
            check_prerequisites
            discover_modules
            shift
            IFS=',' read -ra MODULES <<< "$1"
            for mod in "${MODULES[@]}"; do
                uninstall_module "$mod"
            done
            restart_wazuh
            exit 0
            ;;
        ""|--interactive)
            check_prerequisites
            discover_modules
            show_main_menu
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
