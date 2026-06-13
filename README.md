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

1. **Language detection** — Detects system language from `$LANG`; outputs messages in Spanish if `$LANG` starts with `es`, otherwise in English
2. **Parsing** — Extracts AUR package names from `packages-full.txt` (first field before `:` in lines with metadata, or the entire line if it's just a name)
3. **Detection** — Auto-detects available AUR helper (`paru` → `yay` → `pacman`)
4. **Crossing** — Compares file list with AUR packages installed on system (`paru -Qm`)
5. **PKGBUILD verification** — For each match with metadata, inspects the package's PKGBUILD to confirm it contains the malicious signatures (see below) before marking it for uninstallation
6. **Report** — Generates `reports/installed-<timestamp>.txt` with matching packages and their associated metadata
7. **Interactive Uninstallation** — If there are matches, offers:
   - **Batch mode**: uninstalls all together (`paru -Rns pkg1 pkg2 ...`)
   - **One by one mode**: confirms each package individually
   - **Cancel**

## PKGBUILD verification

When a package from the blacklist is found installed on the system, the script verifies that its PKGBUILD actually contains the malicious signatures before recommending its removal. This prevents false positives when a package with the same name was installed from a legitimate source.

**Verification tokens** are extracted from the metadata in `packages-full.txt`. For a line like:

```
apple-music-desktop:apple-music-desktop-deps.install:  npm install atomic-lockfile ora
```

The tokens are:
- `apple-music-desktop-deps.install` — the install file name
- `npm install atomic-lockfile ora` — the full npm payload

**Decision matrix:**

| Condition | Result |
|-----------|--------|
| Entry without `:` (plain name) | Marked directly (blacklist) |
| PKGBUILD found and contains at least one token | Marked (signature verified) |
| PKGBUILD unreachable (not in cache, clone failed) | Marked (blacklist, safety precaution) |
| PKGBUILD found but contains no tokens | Skipped (legitimate installation) |

The output shows a breakdown of matches by category:
```
[✔] Found 6 package(s) from the file installed.
    2 direct match (blacklist)
    3 signature verified in PKGBUILD
    1 PKGBUILD unreachable (blacklist)
```

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

For lines with metadata, the content after the first `:` is used as verification tokens during PKGBUILD inspection. Only the package name (first field) and these tokens affect the matching logic.

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
