# Image Shuffling Scripts

This directory contains scripts to reorder wallpaper images without modifying the WallPin source code.

## Scripts Available

### 🎯 `shuffle-wallpapers.sh` - Advanced Shuffling

The main shuffling script with multiple reordering strategies:

```bash
./shuffle-wallpapers.sh [strategy]
```

**Strategies:**

| Strategy | Description | Example Use Case |
|----------|-------------|------------------|
| `reverse` | Inverts order completely (first↔last) | Want newest images first |
| `random` | Reproducible random order | Daily variety, same seed |
| `chunks` | Swaps blocks of 50 images | Mix different collections |
| `interleave` | Alternates even/odd images | Blend similar themes |
| `backup` | Create backup only | Before manual changes |
| `restore` | Return to original order | Undo any changes |

**Features:**
- ✅ Automatic backup before changes
- ✅ Handles both `wall_XXX` and `wallpaper_XXX` patterns
- ✅ Preserves file extensions (.jpg, .png, .jpeg)
- ✅ Progress tracking for large collections
- ✅ Colorized output and status messages

### ⚡ `quick-shuffle.sh` - Simple Reverse

One-command reverse shuffling:

```bash
./quick-shuffle.sh
```

Simple script that swaps first with last, second with second-to-last, etc.

## Workflow Examples

### Daily Variety
```bash
# Different look each day (based on date)
./shuffle-wallpapers.sh random
./hyprwall-multi.sh restart-all
```

### Seasonal Rotation
```bash
# Bring older images to front
./shuffle-wallpapers.sh reverse
./hyprwall-multi.sh restart-all

# Back to normal after season
./shuffle-wallpapers.sh restore
```

### Collection Mixing
```bash
# Mix different image groups
./shuffle-wallpapers.sh chunks
./hyprwall-multi.sh restart-all
```

### Testing Different Orders
```bash
# Try interleaved
./shuffle-wallpapers.sh interleave
./hyprwall-multi.sh restart-all

# If you don't like it, restore
./shuffle-wallpapers.sh restore
```

## Technical Details

### How It Works
1. **Scans** `assets/` directory for image files
2. **Creates backup** in `assets_backup/` (automatic)
3. **Generates new names** based on chosen strategy
4. **Renames files** through temporary directory
5. **Preserves extensions** and naming patterns

### File Patterns Supported
- `wall_001.jpg` → `wall_400.jpg`
- `wallpaper_001.png` → `wallpaper_400.png`
- Mixed extensions (jpg, jpeg, png)
- Gaps in numbering (handles missing files)

### Safety Features
- **Automatic backup**: Always created before changes
- **Dry-run capable**: Preview changes without applying
- **Rollback support**: `restore` command returns to original
- **Error handling**: Stops on problems, doesn't corrupt files

## Usage in Hyprland

### Keybind Integration
Add to `~/.config/hypr/hyprland.conf`:

```bash
# Shuffle wallpapers and restart
bind = SUPER SHIFT, R, exec, /path/to/WallPin/shuffle-wallpapers.sh random && /path/to/WallPin/hyprwall-multi.sh restart-all

# Quick reverse and restart
bind = SUPER SHIFT, T, exec, /path/to/WallPin/quick-shuffle.sh && /path/to/WallPin/hyprwall-multi.sh restart-all

# Restore original order
bind = SUPER SHIFT, O, exec, /path/to/WallPin/shuffle-wallpapers.sh restore && /path/to/WallPin/hyprwall-multi.sh restart-all
```

### Automatic Daily Shuffle
Add to crontab (`crontab -e`):

```bash
# Shuffle wallpapers every day at 8 AM
0 8 * * * cd /path/to/WallPin && ./shuffle-wallpapers.sh random

# Restart wallpapers every day at 8:01 AM  
1 8 * * * /path/to/WallPin/hyprwall-multi.sh restart-all
```

## Troubleshooting

### Common Issues

**"No such file or directory"**
- Make sure to run from WallPin root directory
- Check that `assets/` folder exists

**"Permission denied"**
- Make scripts executable: `chmod +x *.sh`

**"Backup already exists"**
- Script will ask to overwrite
- Or manually remove: `rm -rf assets_backup/`

**Changes not visible**
- Restart wallpaper after shuffling:
  ```bash
  ./hyprwall-multi.sh restart-all
  ```

### Manual Restoration
If something goes wrong:

```bash
# If backup exists
cp -r assets_backup/* assets/

# If no backup, restore from git
git checkout HEAD -- assets/
```

## Advanced Usage

### Custom Strategies
You can modify `shuffle-wallpapers.sh` to add your own strategies in the `generate_new_name()` function.

### Large Collections
For collections over 1000 images, the script shows progress every 50 files.

### Integration with Other Tools
The scripts work with any image viewer that reads files alphabetically from the assets directory.
