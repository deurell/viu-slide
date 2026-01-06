#!/usr/bin/env bash
#
# Simple image slideshow using viu
# Usage: ./viu-slide.sh /path/to/folder [options] [-- viu_options]
# Examples:
#   ./viu-slide.sh ./photos -i 3 --shuffle -- --width 80 --name
#   ./viu-slide.sh ./gifs -b --recursive -- -f 20

# Exit if no folder is given
usage() {
    local exit_code="${1:-1}"
    cat <<EOF
Usage: $(basename "$0") /path/to/folder [options] [-- viu_options]

Options:
  -i SECONDS          Delay between images (default: 2)
  -b                  Force block output (useful for tmux/screen)
  -r, --recursive     Include images in subdirectories
  -S, --shuffle       Randomize order each pass
  -w, --width N       Resize images to the given width (viu -w)
  -h, --height N      Resize images to the given height (viu -h)
  -x, --x-offset N    Horizontal offset (viu -x)
  -y, --y-offset N    Vertical offset (viu -y)
  -a, --absolute      Use absolute offsets (viu -a)
  -n, --name          Show filename before each image (viu -n)
  -c, --caption       Show filename after each image (viu -c)
  -t, --transparent   Keep transparent backgrounds (viu -t)
  -f, --frame-rate N  Override GIF frame rate (viu -f)
  -1, --once          Play GIFs once (viu -1)
  -s, --static        Show the first GIF frame only (viu -s)
  -T, --static-gif    Alias for --static
  -H, --help          Show this help text

Anything after `--` is passed directly to viu.
EOF
    exit "$exit_code"
}

FOLDER=""
INTERVAL=2  # Default interval = 2 seconds
BLOCK_MODE=false
RECURSIVE=false
SHUFFLE=false
AUTO_BLOCK_NOTICE=false
VIU_ARGS=()
SUPPORTED_EXTENSIONS=(jpg jpeg png gif bmp webp)

while [ "$#" -gt 0 ]; do
    case "$1" in
        -b)
            BLOCK_MODE=true
            shift
            ;;
        -r|--recursive)
            RECURSIVE=true
            shift
            ;;
        -S|--shuffle)
            SHUFFLE=true
            shift
            ;;
        -i)
            if [ -n "$2" ]; then
                INTERVAL="$2"
                shift 2
            else
                echo "Error: -i requires an interval value."
                usage
            fi
            ;;
        -w|--width)
            if [ -n "$2" ]; then
                VIU_ARGS+=("--width" "$2")
                shift 2
            else
                echo "Error: -w/--width requires a value."
                usage
            fi
            ;;
        -h|--height)
            if [ -n "$2" ]; then
                VIU_ARGS+=("--height" "$2")
                shift 2
            else
                echo "Error: -h/--height requires a value."
                usage
            fi
            ;;
        -x|--x-offset)
            if [ -n "$2" ]; then
                VIU_ARGS+=("-x" "$2")
                shift 2
            else
                echo "Error: -x/--x-offset requires a value."
                usage
            fi
            ;;
        -y|--y-offset)
            if [ -n "$2" ]; then
                VIU_ARGS+=("-y" "$2")
                shift 2
            else
                echo "Error: -y/--y-offset requires a value."
                usage
            fi
            ;;
        -a|--absolute)
            VIU_ARGS+=("--absolute-offset")
            shift
            ;;
        -n|--name)
            VIU_ARGS+=("--name")
            shift
            ;;
        -c|--caption)
            VIU_ARGS+=("--caption")
            shift
            ;;
        -t|--transparent)
            VIU_ARGS+=("--transparent")
            shift
            ;;
        -f|--frame-rate)
            if [ -n "$2" ]; then
                VIU_ARGS+=("--frame-rate" "$2")
                shift 2
            else
                echo "Error: -f/--frame-rate requires a value."
                usage
            fi
            ;;
        -1|--once)
            VIU_ARGS+=("--once")
            shift
            ;;
        -s|--static|-T|--static-gif)
            VIU_ARGS+=("--static")
            shift
            ;;
        -H|--help)
            usage 0
            ;;
        --)
            shift
            while [ "$#" -gt 0 ]; do
                VIU_ARGS+=("$1")
                shift
            done
            break
            ;;
        -*)
            echo "Error: Unknown option '$1'."
            usage
            ;;
        *)
            if [ -z "$FOLDER" ]; then
                FOLDER="$1"
            else
                echo "Error: Unexpected positional argument '$1'."
                usage
            fi
            shift
            ;;
    esac
done

if [ -z "$FOLDER" ]; then
    echo "Error: folder path required."
    usage
fi

# Ensure interval is positive
if ! [[ "$INTERVAL" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: Interval must be a positive number."
    exit 1
fi

if ! awk "BEGIN { exit ($INTERVAL > 0) ? 0 : 1 }"; then
    echo "Error: Interval must be a positive number."
    exit 1
fi

# Check if viu is installed
if ! command -v viu &> /dev/null; then
    echo "Error: viu is not installed. Install it with 'cargo install viu' or your package manager."
    exit 1
fi

# Check if folder exists
if [ ! -d "$FOLDER" ]; then
    echo "Error: Folder '$FOLDER' not found."
    exit 1
fi

# Kitty graphics do not pass through tmux/screen, so fall back to block mode automatically.
if [ "$BLOCK_MODE" = false ]; then
    if [ -n "$TMUX" ] || [ -n "$STY" ] || [[ "$TERM" == screen* ]] || [[ "$TERM" == tmux* ]]; then
        BLOCK_MODE=true
        AUTO_BLOCK_NOTICE=true
    fi
fi

if [ "$AUTO_BLOCK_NOTICE" = true ]; then
    echo "Info: tmux/screen detected; using block mode to avoid kitty escape sequences." >&2
fi

# Hide cursor for cleaner slideshow output and restore on exit
cleanup() {
    tput cnorm
}
trap cleanup EXIT
trap 'exit 130' INT TERM
tput civis

collect_images() {
    IMAGES=()
    local depth_args=()
    if [ "$RECURSIVE" = false ]; then
        depth_args=(-maxdepth 1)
    fi

    local ext_expr=()
    for ext in "${SUPPORTED_EXTENSIONS[@]}"; do
        ext_expr+=(-iname "*.${ext}")
        ext_expr+=(-o)
    done
    # Remove trailing -o
    unset 'ext_expr[${#ext_expr[@]}-1]'

    while IFS= read -r -d '' img; do
        IMAGES+=("$img")
    done < <(find "$FOLDER" "${depth_args[@]}" -type f \( "${ext_expr[@]}" \) -print0)
}

prepare_cycle_images() {
    CURRENT_IMAGES=("${IMAGES[@]}")
    if [ "$SHUFFLE" = true ] && [ "${#CURRENT_IMAGES[@]}" -gt 1 ]; then
        local tmp j i
        for ((i=${#CURRENT_IMAGES[@]}-1; i>0; i--)); do
            j=$((RANDOM % (i + 1)))
            tmp=${CURRENT_IMAGES[i]}
            CURRENT_IMAGES[i]=${CURRENT_IMAGES[j]}
            CURRENT_IMAGES[j]=$tmp
        done
    fi
}

collect_images
if [ "${#IMAGES[@]}" -eq 0 ]; then
    echo "Error: No supported images found in '$FOLDER'." >&2
    exit 1
fi

# Loop forever
while true; do
    prepare_cycle_images
    # Iterate over supported image formats
    for img in "${CURRENT_IMAGES[@]}"; do
        clear
        if [ "$BLOCK_MODE" = true ]; then
            viu -b "${VIU_ARGS[@]}" "$img"
        else
            viu -a "${VIU_ARGS[@]}" "$img"
        fi
        sleep "$INTERVAL"
    done

    # Refresh the file list to catch newly added images
    collect_images
    if [ "${#IMAGES[@]}" -eq 0 ]; then
        echo "Error: No supported images found in '$FOLDER'." >&2
        exit 1
    fi
done
