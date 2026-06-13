#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="$SCRIPT_DIR/paquetes-full.txt"
REPORT_DIR="$SCRIPT_DIR/reportes"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="$REPORT_DIR/instalados-${TIMESTAMP}.txt"

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
        echo "  Reporte de paquetes AUR instalados"
        echo "=============================================="
        echo "  Generado : $(date)"
        echo "  Archivo  : $PACKAGES_FILE"
        echo "  Total en archivo: $(parse_aur_names | wc -l) paquetes"
        echo "  Instalados      : ${#installed_ref[@]} paquetes"
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
    ok "Reporte guardado en: $REPORT_FILE"
}

uninstall_packages() {
    local helper="$1"
    local dry_run="$2"
    shift 2
    local pkgs=("$@")

    echo ""
    if $dry_run; then
        banner "DESINSTALAR PAQUETES AUR [DRY-RUN]"
    else
        banner "DESINSTALAR PAQUETES AUR"
    fi
    echo ""
    echo -e "  Se encontraron ${BOLD}${#pkgs[@]}${NC} paquetes del archivo instalados:"
    echo ""
    for pkg in "${pkgs[@]}"; do
        echo -e "    ${YELLOW}•${NC} $pkg"
    done
    echo ""

    if $dry_run; then
        warn "Modo simulación: no se ejecutará ningún comando real."
        echo ""
    fi

    read -r -p "$(echo -e "${YELLOW}¿Deseas desinstalarlos? [s/N]: ${NC}")" confirm
    if [[ ! "$confirm" =~ ^[sSyY]$ ]]; then
        info "Cancelado. No se desinstaló ningún paquete."
        return
    fi

    echo ""
    echo -e "  ${BOLD}1)${NC} Todos juntos  (una sola operación)"
    echo -e "  ${BOLD}2)${NC} Uno por uno    (confirmar cada paquete)"
    echo -e "  ${BOLD}3)${NC} Cancelar"
    echo ""
    read -r -p "$(echo -e "${BLUE}Elige modo [1-3]: ${NC}")" mode

    case "$mode" in
        1)
            if $dry_run; then
                if [[ "$helper" == "pacman" ]]; then
                    warn "[DRY-RUN] Se ejecutaría: sudo pacman -Rns ${pkgs[*]}"
                else
                    warn "[DRY-RUN] Se ejecutaría: $helper -Rns ${pkgs[*]}"
                fi
            else
                info "Desinstalando todos los paquetes..."
                if [[ "$helper" == "pacman" ]]; then
                    sudo pacman -Rns "${pkgs[@]}"
                else
                    "$helper" -Rns "${pkgs[@]}"
                fi
                ok "Desinstalación completada."
            fi
            ;;
        2)
            local count=0
            for pkg in "${pkgs[@]}"; do
                echo ""
                read -r -p "$(echo -e "${YELLOW}[$((count+1))/${#pkgs[@]}] ¿Desinstalar ${BOLD}$pkg${NC}${YELLOW}? [s/N]: ${NC}")" yn
                if [[ "$yn" =~ ^[sSyY]$ ]]; then
                    if $dry_run; then
                        if [[ "$helper" == "pacman" ]]; then
                            warn "[DRY-RUN] Se ejecutaría: sudo pacman -Rns $pkg"
                        else
                            warn "[DRY-RUN] Se ejecutaría: $helper -Rns $pkg"
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
                    info "Saltando $pkg"
                fi
            done
            if $dry_run; then
                ok "[DRY-RUN] Se habrían desinstalado $count paquete(s)."
            else
                ok "Finalizado. Se desinstalaron $count paquete(s)."
            fi
            ;;
        3|*)
            info "Cancelado."
            ;;
    esac
}

usage() {
    echo "Uso: $(basename "$0") [OPCIONES]"
    echo ""
    echo "Opciones:"
    echo "  --dry-run    Simula la desinstalación sin ejecutar comandos reales"
    echo "  -h, --help   Muestra esta ayuda"
    exit 0
}

main() {
    local dry_run=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=true; shift ;;
            -h|--help) usage ;;
            *) err "Opción desconocida: $1"; usage ;;
        esac
    done

    echo ""
    if $dry_run; then
        banner "LIMPIEZA AUR [DRY-RUN]"
    else
        banner "LIMPIEZA AUR"
    fi
    echo ""

    if [[ ! -f "$PACKAGES_FILE" ]]; then
        err "No se encontró el archivo: $PACKAGES_FILE"
        exit 1
    fi

    local helper
    helper=$(detect_helper)
    info "Helper AUR detectado: ${BOLD}$helper${NC}"

    info "Parseando $(basename "$PACKAGES_FILE")..."
    local aur_from_file=()
    mapfile -t aur_from_file < <(parse_aur_names)
    ok "${#aur_from_file[@]} paquetes AUR encontrados en el archivo"

    info "Consultando paquetes AUR instalados en el sistema..."
    local installed_aur=()
    mapfile -t installed_aur < <(get_installed_aur "$helper")
    ok "${#installed_aur[@]} paquetes AUR instalados en total en el sistema"

    info "Cruzando listas..."
    local matches=()
    while IFS= read -r pkg; do
        if printf '%s\n' "${installed_aur[@]}" | grep -Fxq "$pkg"; then
            matches+=("$pkg")
        fi
    done < <(printf '%s\n' "${aur_from_file[@]}")

    echo ""
    if [[ ${#matches[@]} -eq 0 ]]; then
        ok "Ningún paquete del archivo está instalado actualmente."
    else
        ok "Se encontraron ${BOLD}${#matches[@]}${NC} paquete(s) del archivo instalados."

        generate_report matches
        uninstall_packages "$helper" "$dry_run" "${matches[@]}"
    fi

    echo ""
    ok "Script finalizado."
}

main "$@"
