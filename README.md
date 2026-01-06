# viu-slide

Simple Bash wrapper around [`viu`](https://github.com/atanunq/viu) that turns any folder of images into a looping terminal slideshow. It discovers JPG, PNG, GIF, BMP, and WebP files, refreshes the list between passes, and exposes a streamlined flag set for interval, recursion, shuffle, and display tweaks.

## Requirements
- Bash 4+ on macOS or Linux.
- [`viu`](https://github.com/atanunq/viu) must be installed and on your `PATH` (`cargo install viu` or use your package manager).

## Usage
```
./viu-slide.sh /path/to/folder [options] [-- viu_options]
```
- The folder must exist and contain at least one supported image.
- Anything after `--` is forwarded directly to `viu`, so you can still tap into advanced renderer flags.

## Key Options
- `-i SECONDS` – delay between images (default `2`). Accepts integers or decimals.
- `-r, --recursive` – include images from subdirectories (`find -maxdepth` is otherwise 1).
- `-S, --shuffle` – randomize the order once each cycle.
- `-b` – force block output. The script auto-enables this inside tmux/screen to avoid kitty graphics escape sequences.
- `-w/--width`, `-h/--height`, `-x/--x-offset`, `-y/--y-offset`, `-a/--absolute` – convenience pass-throughs for common `viu` sizing/positioning flags.
- `-n/--name`, `-c/--caption`, `-t/--transparent`, `-f/--frame-rate`, `-1/--once`, `-s/--static`, `-T/--static-gif` – expose additional `viu` display toggles.
- `-H/--help` – print the condensed usage table.

## Examples
```bash
# Cycle through ./photos every 3 seconds, shuffle order, and resize to 80 columns
./viu-slide.sh ./photos -i 3 --shuffle -- --width 80

# Recursive slideshow with filenames shown before each image
./viu-slide.sh ./wallpapers --recursive --name

# Force block output inside tmux and slow down GIF playback
./viu-slide.sh ./gifs -b -- -f 10

```

## License
MIT License — see `LICENSE` for details.
