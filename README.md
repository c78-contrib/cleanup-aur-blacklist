# limpieza-aur

Script interactivo para identificar y desinstalar paquetes AUR listados en `paquetes-full.txt` que estén actualmente instalados en un sistema Arch Linux.

## Requisitos

- `bash` >= 4
- `paru`, `yay` o `pacman` (auto-detecta el disponible)

## Uso

```bash
./limpieza-aur.sh               # Modo normal (desinstala de verdad)
./limpieza-aur.sh --dry-run     # Simulación: muestra qué haría sin ejecutar
./limpieza-aur.sh -h            # Ayuda
```

## Qué hace

1. **Parseo** — Extrae los nombres de paquetes AUR de `paquetes-full.txt` (primer campo antes de `:` en líneas con metadatos, o la línea completa si es solo nombre)
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

| Archivo | Rol | Descripción |
|---|---|---|
| `paquetes-full.txt` | **Lista base y actualizable** | Archivo principal leído por el script. Contiene todos los paquetes AUR a gestionar, en dos formatos: con metadatos (`pkg:archivo: npm install ...`) o solo nombre. |
| `paquetes-add.txt` | **Staging para nuevos paquetes** | Lista temporal de paquetes a agregar (un nombre por línea). Se usa para incorporar nuevas entradas a `paquetes-full.txt` sin duplicados. |
| `limpieza-aur.sh` | Script | Script principal de detección y desinstalación. |
| `reportes/` | Salida | Directorio donde se guardan los reportes generados con timestamp. |

## Formato de paquetes-full.txt

El archivo acepta dos formatos de entrada:

**Con metadatos:**
```
<paquete-aur>:<archivo-install>:  npm install <dep1> <dep2> ...
```

**Solo nombre:**
```
<paquete-aur>
```

Ejemplos:
```
123pan-bin:123pan-bin-deps.install:  npm install atomic-lockfile ora fast-glob
fast-glob
```

El script extrae el nombre del paquete AUR de ambas variantes mediante `sed 's/:.*//'`, eliminando todo desde el primer `:` (si existe) y tomando el nombre resultante.

## Mantenimiento de la lista

`paquetes-full.txt` es la lista base y actualizable. El flujo para agregar nuevos paquetes es:

1. Editar `paquetes-add.txt` agregando los nuevos nombres de paquete (uno por línea)
2. Regenerar `paquetes-full.txt` incorporando solo las entradas no duplicadas:

```bash
# Extraer nombres ya presentes en paquetes-full.txt
sed 's/:.*//' paquetes-full.txt | grep -oP '^[a-zA-Z0-9][a-zA-Z0-9._+-]+' | sort -u > /tmp/existing.txt

# Filtrar solo los nuevos desde paquetes-add.txt
comm -23 <(sort paquetes-add.txt) /tmp/existing.txt > /tmp/new_only.txt

# Agregar al final de paquetes-full.txt
cat /tmp/new_only.txt >> paquetes-full.txt

# Limpiar paquetes-add.txt para el próximo uso
> paquetes-add.txt
```

3. El script `limpieza-aur.sh` usará automáticamente la lista actualizada en su próxima ejecución.
