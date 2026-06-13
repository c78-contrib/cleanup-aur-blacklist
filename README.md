# AUR Cleanup

Interactive script to identify and uninstall AUR packages listed in `packages-full.txt` that are currently installed on an Arch Linux system. Those packages potentially contains malware.

## Requirements

- `bash` >= 4
- `paru`, `yay` or `pacman` (auto-detects available)

## Usage

```bash
./cleanup-aur.sh               # Normal mode (uninstalls for real)
./cleanup-aur.sh --dry-run     # Simulation: shows what it would do without executing
./cleanup-aur.sh -h            # Help
```

## What it does

1. **Parsing** — Extracts AUR package names from `packages-full.txt` (first field before `:` in lines with metadata, or the entire line if it's just a name)
2. **Detection** — Auto-detects available AUR helper (`paru` → `yay` → `pacman`)
3. **Crossing** — Compares file list with AUR packages installed on system (`paru -Qm`)
4. **Report** — Generates `reports/installed-<timestamp>.txt` with matching packages and their associated npm dependencies
5. **Interactive Uninstallation** — If there are matches, offers:
   - **Batch mode**: uninstalls all together (`paru -Rns pkg1 pkg2 ...`)
   - **One by one mode**: confirms each package individually
   - **Cancel**

## Language

The script detects the system language from the `$LANG` environment variable. If `$LANG` starts with `es` (e.g., `es_ES.UTF-8`, `es_MX.UTF-8`), all output messages appear in Spanish. Otherwise, English is used as the default.

```
LANG=es_ES.UTF-8 ./cleanup-aur.sh    # Mensajes en español
LANG=en_US.UTF-8 ./cleanup-aur.sh    # English messages
```

## Dry-run mode

With `--dry-run` the script operates the same but without executing real uninstallation commands. Instead it shows the command that would be executed:

```
[!] [DRY-RUN] Would execute: paru -Rns 123pan-bin actual-ai annobin
```

## Files

| File | Role | Description |
|---|---|---|
| `packages-full.txt` | **Base and updatable list** | Main file read by the script. Contains all AUR packages to manage, in two formats: with metadata (`pkg:file: npm install [...]`) or just the name. |
| `packages-add.txt` | **Staging for new packages** | Temporary list of packages to add (one name per line). Used to add new entries to `packages-full.txt` without duplicates. |
| `cleanup-aur.sh` | Script | Main detection and uninstallation script. |
| `reports/` | Output | Directory where generated reports with timestamp are saved. |

## Format of packages-full.txt

The file accepts two input formats:

**With metadata:**
```
<aur-package>:<install-file>:  npm install <dep1> <dep2> ...
```

**Name only:**
```
<aur-package>
```

Examples:
```
123pan-bin:123pan-bin-deps.install:  npm install atomic-lockfile ora fast-glob
fast-glob
```

The script extracts the AUR package name from both variants using `sed 's/:.*//'`, removing everything from the first `:` onwards (if it exists) and taking the resulting name.

## Maintaining the list

`packages-full.txt` is the base and updatable list. The workflow to add new packages is:

1. Edit `packages-add.txt` adding the new package names (one per line)
2. Regenerate `packages-full.txt` incorporating only non-duplicate entries:

```bash
# Extract names already present in packages-full.txt
sed 's/:.*//' packages-full.txt | grep -oP '^[a-zA-Z0-9][a-zA-Z0-9._+-]+' | sort -u > /tmp/existing.txt

# Filter only the new ones from packages-add.txt
comm -23 <(sort packages-add.txt) /tmp/existing.txt > /tmp/new_only.txt

# Add to the end of packages-full.txt
cat /tmp/new_only.txt >> packages-full.txt

# Clean up packages-add.txt for next use
> packages-add.txt
```

3. The `cleanup-aur.sh` script will automatically use the updated list on its next run.
