# .justfile — manage quadlets

ROOT_DIR := justfile_directory()
HOME_DIR := home_directory()
QUADLETS_SOURCE_DIR := ROOT_DIR / "quadlets"
QUADLETS_TARGET_DIR := HOME_DIR / ".config/containers/systemd"


# Show all available recipes in this justfile
list:
    @just --list

# Create symlinks of quadlets into the systemd user directory and reload
install:
    #!/usr/bin/env fish
    echo "🔗 Installing quadlets from {{ QUADLETS_SOURCE_DIR}} into {{ QUADLETS_TARGET_DIR }}"
    mkdir -p "{{ QUADLETS_TARGET_DIR }}"
    for f in {{ QUADLETS_SOURCE_DIR }}/*container {{ QUADLETS_SOURCE_DIR }}/*network {{ QUADLETS_SOURCE_DIR }}/*volume {{ QUADLETS_SOURCE_DIR }}/*service {{ QUADLETS_SOURCE_DIR }}/*socket {{ QUADLETS_SOURCE_DIR }}/*mount
        set quadlet_name "$(basename $f)"
        if test -e "$f"
            echo "➡️ Linking $f to {{ QUADLETS_TARGET_DIR }}/$quadlet_name"
            ln -sf "$f" "{{ QUADLETS_TARGET_DIR }}/$quadlet_name"
        end
    end
    echo "🔁 Reloading systemd user daemon to recognize new quadlet units"
    systemctl --user daemon-reload
    echo "✅ Install complete."

# Stop all services and remove symlinks
uninstall:
    #!/usr/bin/env fish
    echo "🛑 Stopping services and removing quadlet symlinks from {{ QUADLETS_TARGET_DIR }}"
    for f in {{ QUADLETS_SOURCE_DIR }}/*container {{ QUADLETS_SOURCE_DIR }}/*network {{ QUADLETS_SOURCE_DIR }}/*volume {{ QUADLETS_SOURCE_DIR }}/*service {{ QUADLETS_SOURCE_DIR }}/*socket {{ QUADLETS_SOURCE_DIR }}/*mount
        set quadlet_filename_with_extension "$(basename $f)"
        set quadlet_filename "$(path change-extension '' $quadlet_filename_with_extension)"
        set quadlet_fileextension "$(path extension $quadlet_filename_with_extension)"
        if test -e "{{ QUADLETS_TARGET_DIR }}/$quadlet_filename_with_extension"
            if test "$quadlet_fileextension" = ".container"
                echo "⛔ Stopping $quadlet_filename_with_extension if running"
                systemctl --user stop "$quadlet_filename" || true
            end
            echo "🗑️ Removing symlink {{ QUADLETS_TARGET_DIR }}/$quadlet_filename_with_extension"
            rm -f "{{ QUADLETS_TARGET_DIR }}/$quadlet_filename_with_extension"
        end
    end
    echo "🔁 Reloading systemd user daemon to recognize new quadlet units"
    systemctl --user daemon-reload
    echo "✅ Uninstall complete."

# Start all quadlet units found in the target dir, or only one if provided
start service='':
    #!/usr/bin/env fish
    set -l requested "{{ service }}"
    set -l targets
    if test -n "$requested"
        set -a targets (string replace -r '\\.container$' '' "$requested")
        echo "▶️ Starting requested quadlet: $targets[1]"
    else
        echo "▶️ Starting quadlet units found in {{ QUADLETS_TARGET_DIR }}"
        for f in {{ QUADLETS_SOURCE_DIR }}/*container
            set quadlet_filename_with_extension "$(basename $f)"
            set quadlet_filename "$(path change-extension '' $quadlet_filename_with_extension)"
            set -a targets "$quadlet_filename"
        end
    end

    for quadlet_filename in $targets
        set -l quadlet_filename_with_extension "$quadlet_filename.container"
        if test -e "{{ QUADLETS_TARGET_DIR}}/$quadlet_filename_with_extension"
            echo "▶️ Starting $quadlet_filename"
            systemctl --user start "$quadlet_filename" || true
        else
            echo "⚠️ Skipping $quadlet_filename (unit file not linked in {{ QUADLETS_TARGET_DIR }})"
        end
    end

# Stop all quadlet units found in the target dir, or only one if provided
stop service='':
    #!/usr/bin/env fish
    set -l requested "{{ service }}"
    set -l targets
    if test -n "$requested"
        set -a targets (string replace -r '\\.container$' '' "$requested")
        echo "🛑 Stopping requested quadlet: $targets[1]"
    else
        echo "🛑 Stopping quadlet units found in {{ QUADLETS_TARGET_DIR }}"
        for f in {{ QUADLETS_SOURCE_DIR }}/*container
            set quadlet_filename_with_extension "$(basename $f)"
            set quadlet_filename "$(path change-extension '' $quadlet_filename_with_extension)"
            set -a targets "$quadlet_filename"
        end
    end

    for quadlet_filename in $targets
        set -l quadlet_filename_with_extension "$quadlet_filename.container"
        if test -e "{{ QUADLETS_TARGET_DIR}}/$quadlet_filename_with_extension"
            echo "🛑 Stopping $quadlet_filename"
            systemctl --user stop "$quadlet_filename" || true
        else
            echo "⚠️ Skipping $quadlet_filename (unit file not linked in {{ QUADLETS_TARGET_DIR }})"
        end
    end

# Show status for each quadlet unit (no pager)
status service='':
    #!/usr/bin/env fish
    set -l requested "{{ service }}"
    set -l targets
    if test -n "$requested"
        set -a targets (string replace -r '\\.container$' '' "$requested")
        echo "🔎 Quadlet unit status for requested quadlet from {{ QUADLETS_TARGET_DIR }}:"
    else
        echo "🔎 Quadlet unit status from {{ QUADLETS_TARGET_DIR }}:"
        for f in {{ QUADLETS_SOURCE_DIR }}/*container
            set quadlet_filename_with_extension "$(basename $f)"
            set quadlet_filename "$(path change-extension '' $quadlet_filename_with_extension)"
            set -a targets "$quadlet_filename"
        end
    end

    echo -n "🔍 Analizando quadlets... "
    set -l table_data
    for quadlet_filename in $targets
        set -l link_status "OFF"
        set -l link_color red
        set -l run_status "---"
        set -l run_color white
        set -l quadlet_filename_with_extension "$quadlet_filename.container"
        if test -e "{{ QUADLETS_TARGET_DIR}}/$quadlet_filename_with_extension"
            set link_status "ON"
            set link_color green
            if systemctl --user is-active --quiet "$quadlet_filename"
                set run_status "running"
                set run_color green
            else
                set run_status "stopped"
                set run_color yellow
            end
        end
        set -a table_data "$link_color|$link_status|$run_color|$run_status|$quadlet_filename"
    end
    printf "\r%-50s\n" "✅ Análisis completado"
    echo "------------------------------------------"
    printf "%-8s %-12s %s\n" "LINK" "STATUS" "STACK"
    echo "------------------------------------------"
    for line in $table_data
        set -l parts (string split "|" $line)
        echo -n " ["
        set_color $parts[1]; echo -n "$parts[2]"; set_color normal
        echo -n "]    "
        set_color $parts[3]; printf "%-11s" "$parts[4]"; set_color normal
        echo " $parts[5]"
    end
    echo "------------------------------------------"


# Remove podman volumes
clean_volumes:
    #!/usr/bin/env fish
    echo "🧼 Removing podman volumes declared in .volume files"
    for volume_file in {{ QUADLETS_SOURCE_DIR }}/*.volume
        if test -e "$volume_file"
            # Read VolumeName from the [Volume] section style key-value line.
            set volume_name (string trim (string replace -r '^VolumeName=' '' (grep -m1 '^VolumeName=' "$volume_file")))
            if test -n "$volume_name"
                echo "🗑️ Removing volume: $volume_name"
                podman volume rm -f "$volume_name" || true
            else
                echo "⚠️ Skipping $volume_file (VolumeName not found)"
            end
        end
    end

# Check quadlet
check quadlet:
    #!/usr/bin/env fish
    echo "🧼 Checking {{ quadlet }}"
    /usr/lib/podman/quadlet -dryrun -user $USER {{ quadlet }}

# Logs for a specific container (follow mode, shows last hour)
logs service:
    @echo "📜 Showing logs for {{ service }} container (Ctrl+C to exit)"
    @journalctl --user -u "{{ service }}" -f --since "1 hour ago"

logsf service:
    @echo "📜 Showing logs for {{ service }} container (Ctrl+C to exit)"
    @journalctl --user -xsfu "{{ service }}"