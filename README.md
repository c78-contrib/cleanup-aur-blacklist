# limpieza-aur

Script interactivo para identificar y desinstalar paquetes AUR listados en `paquetes.txt` que estén actualmente instalados en un sistema Arch Linux.

## Requisitos

- `bash` >= 4
- `paru`, `yay` o `pacman` (auto-detecta el disponible)
- `grep` con soporte PCRE (`-P`)

## Uso

```bash
./limpieza-aur.sh               # Modo normal (desinstala de verdad)
./limpieza-aur.sh --dry-run     # Simulación: muestra qué haría sin ejecutar
./limpieza-aur.sh -h            # Ayuda
```

## Qué hace

1. **Parseo** — Extrae los nombres de paquetes AUR de `paquetes.txt` (primer campo antes de `:`)
2. **Detección** — Auto-detecta el helper AUR disponible (`paru` → `yay` → `pacman`)
3. **Cruce** — Compara la lista del archivo con los AUR instalados en el sistema (`paru -Qm`)
4. **Reporte** — Genera `reportes/instalados-<timestamp>.txt` con los paquetes coincidentes y sus dependencias npm asociadas
5. **Desinstalación interactiva** — Si hay coincidencias, ofrece:
   - **Modo batch**: desinstala todos juntos (`paru -Rns pkg1 pkg2 ...`)
   - **Modo uno a uno**: confirma cada paquete individualmente
   - **Cancelar**

## Modo dry-run

Con `--dry-run` el script opera igual pero sin ejecutar comandos de desinstalación reales. En su lugar muestra el comando que se ejecutaría:

```
[!] [DRY-RUN] Se ejecutaría: paru -Rns 123pan-bin actual-ai annobin
```

## Archivos

| Archivo | Descripción |
|---|---|
| `paquetes.txt` | Lista de paquetes AUR con sus dependencias npm (formato `pkg:archivo: npm install ...`) |
| `limpieza-aur.sh` | Script principal |
| `reportes/` | Directorio donde se guardan los reportes generados |

## Formato de paquetes.txt

Cada entrada tiene el formato:

```
<paquete-aur>:<archivo-install>:  npm install <dep1> <dep2> ...
```

Ejemplo:
```
123pan-bin:123pan-bin-deps.install:  npm install atomic-lockfile ora fast-glob
```

El script extrae únicamente el nombre del paquete AUR (primer campo antes del `:`).
