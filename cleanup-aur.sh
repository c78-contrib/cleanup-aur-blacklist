#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="$SCRIPT_DIR/packages-full.txt"
REPORT_DIR="$SCRIPT_DIR/reports"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="$REPORT_DIR/installed-${TIMESTAMP}.txt"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

banner() { echo -e "${BLUE}${BOLD}═══ $1 ═══${NC}"; }
info()  { echo -e "${BLUE}[*]${NC} $1"; }
ok()    { echo -e "${GREEN}[✔]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✘]${NC} $1"; }

detect_helper() {
    if command -v paru &>/dev/null; then echo "paru"
    elif command -v yay &>/dev/null; then echo "yay"
    else echo "pacman"; fi
}

parse_aur_names() {
    sed 's/:.*//' "$PACKAGES_FILE" | grep -oP '^[a-zA-Z0-9][a-zA-Z0-9._+-]+' | sort -u
}

get_installed_aur() {
    local helper="$1"
    if [[ "$helper" == "pacman" ]]; then
        pacman -Qm 2>/dev/null | awk '{print $1}' | sort
    else
        "$helper" -Qm 2>/dev/null | awk '{print $1}' | sort
    fi
}

generate_report() {
    local -n installed_ref=$1
    mkdir -p "$REPORT_DIR"
    {
        echo "=============================================="
        echo "  Report of installed AUR packages"
        echo "=============================================="
        echo "  Generated : $(date)"
        echo "  File      : $PACKAGES_FILE"
        echo "  Total in file : $(parse_aur_names | wc -l) packages"
        echo "  Installed     : ${#installed_ref[@]} packages"
        echo "=============================================="
        echo ""
        for pkg in "${installed_ref[@]}"; do
            echo "▸ $pkg"
            local info_line
            info_line=$(grep "^${pkg}:" "$PACKAGES_FILE" 2>/dev/null | head -1 || true)
            if [[ -n "$info_line" ]]; then
                echo "  $info_line"
            fi
            echo ""
        done
    } > "$REPORT_FILE"
    ok "Report saved to: $REPORT_FILE"
}

uninstall_packages() {
    local helper="$1"
    local dry_run="$2"
    shift 2
    local pkgs=("$@")

    echo ""
    if $dry_run; then
        banner "UNINSTALL AUR PACKAGES [DRY-RUN]"
    else
        banner "UNINSTALL AUR PACKAGES"
    fi
    echo ""
    echo -e "  Found ${BOLD}${#pkgs[@]}${NC} packages from the file installed:"
    echo ""
    for pkg in "${pkgs[@]}"; do
        echo -e "    ${YELLOW}•${NC} $pkg"
    done
    echo ""

    if $dry_run; then
        warn "Simulation mode: no real commands will be executed."
        echo ""
    fi

    read -r -p "$(echo -e "${YELLOW}Do you want to uninstall them? [y/N]: ${NC}")" confirm
    if [[ ! "$confirm" =~ ^[yYsS]$ ]]; then
        info "Cancelled. No packages were uninstalled."
        return
    fi

    echo ""
    echo -e "  ${BOLD}1)${NC} All together  (single operation)"
    echo -e "  ${BOLD}2)${NC} One by one     (confirm each package)"
    echo -e "  ${BOLD}3)${NC} Cancel"
    echo ""
    read -r -p "$(echo -e "${BLUE}Choose mode [1-3]: ${NC}")" mode

    case "$mode" in
        1)
            if $dry_run; then
                if [[ "$helper" == "pacman" ]]; then
                    warn "[DRY-RUN] Would execute: sudo pacman -Rns ${pkgs[*]}"
                else
                    warn "[DRY-RUN] Would execute: $helper -Rns ${pkgs[*]}"
                fi
            else
                info "Uninstalling all packages..."
                if [[ "$helper" == "pacman" ]]; then
                    sudo pacman -Rns "${pkgs[@]}"
                else
                    "$helper" -Rns "${pkgs[@]}"
                fi
                ok "Uninstallation completed."
            fi
            ;;
        2)
            local count=0
            for pkg in "${pkgs[@]}"; do
                echo ""
                read -r -p "$(echo -e "${YELLOW}[$((count+1))/${#pkgs[@]}] Uninstall ${BOLD}$pkg${NC}${YELLOW}? [y/N]: ${NC}")" yn
                if [[ "$yn" =~ ^[yYsS]$ ]]; then
                    if $dry_run; then
                        if [[ "$helper" == "pacman" ]]; then
                            warn "[DRY-RUN] Would execute: sudo pacman -Rns $pkg"
                        else
                            warn "[DRY-RUN] Would execute: $helper -Rns $pkg"
                        fi
                    else
                        if [[ "$helper" == "pacman" ]]; then
                            sudo pacman -Rns "$pkg"
                        else
                            "$helper" -Rns "$pkg"
                        fi
                    fi
                    ((count++))
                else
                    info "Skipping $pkg"
                fi
            done
            if $dry_run; then
                ok "[DRY-RUN] Would have uninstalled $count package(s)."
            else
                ok "Finished. $count package(s) uninstalled."
            fi
            ;;
        3|*)
            info "Cancelled."
            ;;
    esac
}

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --dry-run    Simulates uninstallation without executing real commands"
    echo "  -h, --help   Show this help"
    exit 0
}

main() {
    local dry_run=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=true; shift ;;
            -h|--help) usage ;;
            *) err "Unknown option: $1"; usage ;;
        esac
    done

    echo ""
    if $dry_run; then
        banner "AUR CLEANUP [DRY-RUN]"
    else
        banner "AUR CLEANUP"
    fi
    echo ""

    if [[ ! -f "$PACKAGES_FILE" ]]; then
        err "File not found: $PACKAGES_FILE"
        exit 1
    fi

    local helper
    helper=$(detect_helper)
    info "AUR helper detected: ${BOLD}$helper${NC}"

    info "Parsing $(basename "$PACKAGES_FILE")..."
    local aur_from_file=()
    mapfile -t aur_from_file < <(parse_aur_names)
    ok "${#aur_from_file[@]} AUR packages found in file"

    info "Querying installed AUR packages on system..."
    local installed_aur=()
    mapfile -t installed_aur < <(get_installed_aur "$helper")
    ok "${#installed_aur[@]} AUR packages installed in total on system"

    info "Cross-referencing lists..."
    local matches=()
    while IFS= read -r pkg; do
        if printf '%s\n' "${installed_aur[@]}" | grep -Fxq "$pkg"; then
            matches+=("$pkg")
        fi
    done < <(printf '%s\n' "${aur_from_file[@]}")

    echo ""
    if [[ ${#matches[@]} -eq 0 ]]; then
        ok "No packages from the file are currently installed."
    else
        ok "Found ${BOLD}${#matches[@]}${NC} package(s) from the file installed."

        generate_report matches
        uninstall_packages "$helper" "$dry_run" "${matches[@]}"
    fi

    echo ""
    ok "Script finished."
}

main "$@"
