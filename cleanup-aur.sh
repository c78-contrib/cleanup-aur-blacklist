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

LANG_ES=false

banner() { echo -e "${BLUE}${BOLD}═══ $1 ═══${NC}"; }
info()  { echo -e "${BLUE}[*]${NC} $1"; }
ok()    { echo -e "${GREEN}[✔]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✘]${NC} $1"; }

detect_lang() {
    local lang="${LANG:-${LC_ALL:-${LC_MESSAGES:-}}}"
    [[ "$lang" =~ ^es(_|$) ]] && LANG_ES=true || LANG_ES=false
}

t() {
    if $LANG_ES; then
        case "$1" in
            banner_cleanup)         echo "LIMPIEZA AUR" ;;
            banner_cleanup_dry)     echo "LIMPIEZA AUR [DRY-RUN]" ;;
            banner_uninstall)       echo "DESINSTALAR PAQUETES AUR" ;;
            banner_uninstall_dry)   echo "DESINSTALAR PAQUETES AUR [DRY-RUN]" ;;

            report_title)           echo "Reporte de paquetes AUR instalados" ;;
            report_generated)       echo "Generado" ;;
            report_file)            echo "Archivo" ;;
            report_total)           echo "Total en archivo" ;;
            report_installed)       echo "Instalados" ;;
            fmt_report_saved)       echo "Reporte guardado en: %s" ;;

            msg_simulation)         echo "Modo simulación: no se ejecutará ningún comando real." ;;
            prompt_confirm)         echo "¿Deseas desinstalarlos? [s/N]:" ;;
            msg_cancelled_none)     echo "Cancelado. No se desinstaló ningún paquete." ;;
            msg_all_together)       echo "Todos juntos  (una sola operación)" ;;
            msg_one_by_one)         echo "Uno por uno    (confirmar cada paquete)" ;;
            msg_cancel_option)      echo "Cancelar" ;;
            prompt_mode)            echo "Elige modo [1-3]:" ;;
            msg_uninstalling_all)   echo "Desinstalando todos los paquetes..." ;;
            msg_uninstall_done)     echo "Desinstalación completada." ;;
            msg_cancelled)          echo "Cancelado." ;;
            fmt_skipping)           echo "Saltando %s" ;;
            fmt_finished)           echo "Finalizado. Se desinstalaron %s paquete(s)." ;;
            fmt_dry_finished)       echo "[DRY-RUN] Se habrían desinstalado %s paquete(s)." ;;
            fmt_would_exec)         echo "[DRY-RUN] Se ejecutaría: %s -Rns %s" ;;
            fmt_progress)           echo "[%s/%s] ¿Desinstalar %s? [s/N]:" ;;

            usage_header)           echo "Uso: %s [OPCIONES]" ;;
            usage_options)          echo "Opciones:" ;;
            usage_dry)              echo "  --dry-run    Simula la desinstalación sin ejecutar comandos reales" ;;
            usage_help)             echo "  -h, --help   Muestra esta ayuda" ;;
            fmt_unknown)            echo "Opción desconocida: %s" ;;

            msg_parsing)            echo "Parseando %s..." ;;
            fmt_found_file)         echo "%s paquetes AUR encontrados en el archivo" ;;
            msg_querying)           echo "Consultando paquetes AUR instalados en el sistema..." ;;
            fmt_installed)          echo "%s paquetes AUR instalados en total en el sistema" ;;
            msg_crossref)           echo "Cruzando listas..." ;;
            msg_no_matches)         echo "Ningún paquete del archivo está instalado actualmente." ;;
            fmt_matches_found)      echo "Se encontraron %s paquete(s) del archivo instalados." ;;
            fmt_found_n)            echo "Se encontraron %s paquetes del archivo instalados:" ;;
            msg_finished)           echo "Script finalizado." ;;
            fmt_helper)             echo "Helper AUR detectado: %s" ;;
            fmt_no_file)            echo "No se encontró el archivo: %s" ;;
            msg_plain_match)        echo "coincidencia directa (blacklist)" ;;
            msg_verified_match)     echo "firma verificada en PKGBUILD" ;;
            msg_blacklist_match)    echo "PKGBUILD inaccesible (blacklist)" ;;
            msg_no_match)           echo "PKGBUILD no coincide (ignorado)" ;;

            *) echo "$1" ;;
        esac
    else
        case "$1" in
            banner_cleanup)         echo "AUR CLEANUP" ;;
            banner_cleanup_dry)     echo "AUR CLEANUP [DRY-RUN]" ;;
            banner_uninstall)       echo "UNINSTALL AUR PACKAGES" ;;
            banner_uninstall_dry)   echo "UNINSTALL AUR PACKAGES [DRY-RUN]" ;;

            report_title)           echo "Report of installed AUR packages" ;;
            report_generated)       echo "Generated" ;;
            report_file)            echo "File" ;;
            report_total)           echo "Total in file" ;;
            report_installed)       echo "Installed" ;;
            fmt_report_saved)       echo "Report saved to: %s" ;;

            msg_simulation)         echo "Simulation mode: no real commands will be executed." ;;
            prompt_confirm)         echo "Do you want to uninstall them? [y/N]:" ;;
            msg_cancelled_none)     echo "Cancelled. No packages were uninstalled." ;;
            msg_all_together)       echo "All together  (single operation)" ;;
            msg_one_by_one)         echo "One by one     (confirm each package)" ;;
            msg_cancel_option)      echo "Cancel" ;;
            prompt_mode)            echo "Choose mode [1-3]:" ;;
            msg_uninstalling_all)   echo "Uninstalling all packages..." ;;
            msg_uninstall_done)     echo "Uninstallation completed." ;;
            msg_cancelled)          echo "Cancelled." ;;
            fmt_skipping)           echo "Skipping %s" ;;
            fmt_finished)           echo "Finished. %s package(s) uninstalled." ;;
            fmt_dry_finished)       echo "[DRY-RUN] Would have uninstalled %s package(s)." ;;
            fmt_would_exec)         echo "[DRY-RUN] Would execute: %s -Rns %s" ;;
            fmt_progress)           echo "[%s/%s] Uninstall %s? [y/N]:" ;;

            usage_header)           echo "Usage: %s [OPTIONS]" ;;
            usage_options)          echo "Options:" ;;
            usage_dry)              echo "  --dry-run    Simulates uninstallation without executing real commands" ;;
            usage_help)             echo "  -h, --help   Show this help" ;;
            fmt_unknown)            echo "Unknown option: %s" ;;

            msg_parsing)            echo "Parsing %s..." ;;
            fmt_found_file)         echo "%s AUR packages found in file" ;;
            msg_querying)           echo "Querying installed AUR packages on system..." ;;
            fmt_installed)          echo "%s AUR packages installed in total on system" ;;
            msg_crossref)           echo "Cross-referencing lists..." ;;
            msg_no_matches)         echo "No packages from the file are currently installed." ;;
            fmt_matches_found)      echo "Found %s package(s) from the file installed." ;;
            fmt_found_n)            echo "Found %s packages from the file installed:" ;;
            msg_finished)           echo "Script finished." ;;
            fmt_helper)             echo "AUR helper detected: %s" ;;
            fmt_no_file)            echo "File not found: %s" ;;
            msg_plain_match)        echo "direct match (blacklist)" ;;
            msg_verified_match)     echo "signature verified in PKGBUILD" ;;
            msg_blacklist_match)    echo "PKGBUILD unreachable (blacklist)" ;;
            msg_no_match)           echo "PKGBUILD does not match (skipped)" ;;

            *) echo "$1" ;;
        esac
    fi
}

detect_helper() {
    if command -v paru &>/dev/null; then echo "paru"
    elif command -v yay &>/dev/null; then echo "yay"
    else echo "pacman"; fi
}

parse_aur_names() {
    sed 's/:.*//' "$PACKAGES_FILE" | grep -oP '^[a-zA-Z0-9][a-zA-Z0-9._+-]+' | sort -u
}

_trim() {
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//' <<< "$1"
}

get_tokens_from_line() {
    local line="$1"
    local rest="${line#*:}"
    if [[ "$rest" == *:* ]]; then
        local t1="${rest%%:*}"
        local t2="${rest#*:}"
        t1=$(_trim "$t1")
        t2=$(_trim "$t2")
        [[ -n "$t1" ]] && echo "$t1"
        [[ -n "$t2" ]] && echo "$t2"
    else
        local t
        t=$(_trim "$rest")
        [[ -n "$t" ]] && echo "$t"
    fi
}

get_pkgbuild_content() {
    local pkg="$1"
    local helper="$2"

    local cache_paths=(
        "$HOME/.cache/paru/clone/$pkg/PKGBUILD"
        "$HOME/.cache/yay/$pkg/PKGBUILD"
    )
    for path in "${cache_paths[@]}"; do
        if [[ -f "$path" ]]; then
            cat "$path" 2>/dev/null && return 0
        fi
    done

    local tmpdir
    tmpdir=$(mktemp -d -t aur-cleanup-XXXXXX)
    (
        cd "$tmpdir" || exit 1
        if [[ "$helper" == "pacman" ]]; then
            git clone "https://aur.archlinux.org/$pkg.git" 2>/dev/null || return 1
        else
            timeout 30 "$helper" -G "$pkg" 2>/dev/null || return 1
        fi
        [[ -f "$pkg/PKGBUILD" ]] && cat "$pkg/PKGBUILD" 2>/dev/null || return 1
    )
    local ret=$?
    rm -rf "$tmpdir" 2>/dev/null
    return $ret
}

pkgbuild_contains() {
    local content="$1"
    shift
    local tokens=("$@")

    [[ ${#tokens[@]} -eq 0 ]] && return 0

    for token in "${tokens[@]}"; do
        if echo "$content" | grep -Fq "$token"; then
            return 0
        fi
    done
    return 1
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
        echo "  $(t report_title)"
        echo "=============================================="
        echo "  $(t report_generated) : $(date)"
        echo "  $(t report_file)      : $PACKAGES_FILE"
        local pkg_count
        pkg_count=$(parse_aur_names | wc -l)
        echo "  $(t report_total) : $pkg_count packages"
        echo "  $(t report_installed)     : ${#installed_ref[@]} packages"
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
    ok "$(printf "$(t fmt_report_saved)" "$REPORT_FILE")"
}

uninstall_packages() {
    local helper="$1"
    local dry_run="$2"
    shift 2
    local pkgs=("$@")

    echo ""
    if $dry_run; then
        banner "$(t banner_uninstall_dry)"
    else
        banner "$(t banner_uninstall)"
    fi
    echo ""
    echo -e "  $(printf "$(t fmt_found_n)" "${#pkgs[@]}")"
    echo ""
    for pkg in "${pkgs[@]}"; do
        echo -e "    ${YELLOW}•${NC} $pkg"
    done
    echo ""

    if $dry_run; then
        warn "$(t msg_simulation)"
        echo ""
    fi

    read -r -p "$(echo -e "${YELLOW}$(t prompt_confirm) ${NC}")" confirm
    if [[ ! "$confirm" =~ ^[yYsS]$ ]]; then
        info "$(t msg_cancelled_none)"
        return
    fi

    echo ""
    echo -e "  ${BOLD}1)${NC} $(t msg_all_together)"
    echo -e "  ${BOLD}2)${NC} $(t msg_one_by_one)"
    echo -e "  ${BOLD}3)${NC} $(t msg_cancel_option)"
    echo ""
    read -r -p "$(echo -e "${BLUE}$(t prompt_mode) ${NC}")" mode

    case "$mode" in
        1)
            if $dry_run; then
                warn "$(printf "$(t fmt_would_exec)" "$helper" "${pkgs[*]}")"
            else
                info "$(t msg_uninstalling_all)"
                if [[ "$helper" == "pacman" ]]; then
                    sudo pacman -Rns "${pkgs[@]}"
                else
                    "$helper" -Rns "${pkgs[@]}"
                fi
                ok "$(t msg_uninstall_done)"
            fi
            ;;
        2)
            local count=0
            for pkg in "${pkgs[@]}"; do
                echo ""
                read -r -p "$(echo -e "${YELLOW}$(printf "$(t fmt_progress)" "$((count+1))" "${#pkgs[@]}" "$pkg") ${NC}")" yn
                if [[ "$yn" =~ ^[yYsS]$ ]]; then
                    if $dry_run; then
                        warn "$(printf "$(t fmt_would_exec)" "$helper" "$pkg")"
                    else
                        if [[ "$helper" == "pacman" ]]; then
                            sudo pacman -Rns "$pkg"
                        else
                            "$helper" -Rns "$pkg"
                        fi
                    fi
                    ((count++))
                else
                    info "$(printf "$(t fmt_skipping)" "$pkg")"
                fi
            done
            if $dry_run; then
                ok "$(printf "$(t fmt_dry_finished)" "$count")"
            else
                ok "$(printf "$(t fmt_finished)" "$count")"
            fi
            ;;
        3|*)
            info "$(t msg_cancelled)"
            ;;
    esac
}

usage() {
    printf "$(t usage_header)\n" "$(basename "$0")"
    echo ""
    echo "$(t usage_options)"
    echo "$(t usage_dry)"
    echo "$(t usage_help)"
    exit 0
}

main() {
    detect_lang
    local dry_run=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=true; shift ;;
            -h|--help) usage ;;
            *) err "$(printf "$(t fmt_unknown)" "$1")"; usage ;;
        esac
    done

    echo ""
    if $dry_run; then
        banner "$(t banner_cleanup_dry)"
    else
        banner "$(t banner_cleanup)"
    fi
    echo ""

    if [[ ! -f "$PACKAGES_FILE" ]]; then
        err "$(printf "$(t fmt_no_file)" "$PACKAGES_FILE")"
        exit 1
    fi

    local helper
    helper=$(detect_helper)
    info "$(printf "$(t fmt_helper)" "$helper")"

    local aur_from_file=()
    info "$(printf "$(t msg_parsing)" "$(basename "$PACKAGES_FILE")")"
    mapfile -t aur_from_file < <(parse_aur_names)
    ok "$(printf "$(t fmt_found_file)" "${#aur_from_file[@]}")"

    local installed_aur=()
    info "$(t msg_querying)"
    mapfile -t installed_aur < <(get_installed_aur "$helper")
    ok "$(printf "$(t fmt_installed)" "${#installed_aur[@]}")"

    info "$(t msg_crossref)"
    local matches=()
    local plain_count=0
    local verified_count=0
    local blacklist_count=0
    while IFS= read -r pkg; do
        if printf '%s\n' "${installed_aur[@]}" | grep -Fxq "$pkg"; then
            local line
            line=$(grep "^${pkg}:" "$PACKAGES_FILE" 2>/dev/null | head -1 || echo "$pkg")
            if [[ "$line" != *:* ]]; then
                matches+=("$pkg")
                ((plain_count++))
            else
                local tokens=()
                mapfile -t tokens < <(get_tokens_from_line "$line")
                local content
                content=$(get_pkgbuild_content "$pkg" "$helper")
                if [[ -z "$content" ]]; then
                    matches+=("$pkg")
                    ((blacklist_count++))
                elif pkgbuild_contains "$content" "${tokens[@]}"; then
                    matches+=("$pkg")
                    ((verified_count++))
                fi
            fi
        fi
    done < <(printf '%s\n' "${aur_from_file[@]}")

    echo ""
    if [[ ${#matches[@]} -eq 0 ]]; then
        ok "$(t msg_no_matches)"
    else
        ok "$(printf "$(t fmt_matches_found)" "${#matches[@]}")"
        if (( plain_count > 0 )); then
            echo -e "    ${BOLD}${plain_count}${NC} $(t msg_plain_match)"
        fi
        if (( verified_count > 0 )); then
            echo -e "    ${BOLD}${verified_count}${NC} $(t msg_verified_match)"
        fi
        if (( blacklist_count > 0 )); then
            echo -e "    ${BOLD}${blacklist_count}${NC} $(t msg_blacklist_match)"
        fi

        generate_report matches
        uninstall_packages "$helper" "$dry_run" "${matches[@]}"
    fi

    echo ""
    ok "$(t msg_finished)"
}

main "$@"
