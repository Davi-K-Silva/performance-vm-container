!/usr/bin/env bash
# prepare_env.sh — clean caches, check ACPI, set CPUs to performance + constant freq
set -euo pipefail

SCRIPT_PATH="$(readlink -f "$0")"

log()  { printf "\033[1;36m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!!\033[0m %s\n" "$*"; }

# Ensure we are root (needed for /proc and /sys writes)
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log "Re-executing as root with sudo..."
    exec sudo -E bash "$SCRIPT_PATH" "$@"
fi

clean_caches() {
    log "Flushing filesystem buffers and dropping caches..."
    sync
    # 1 = pagecache, 2 = dentries and inodes, 3 = all
    echo 3 > /proc/sys/vm/drop_caches
}

check_acpi() {
    log "Checking ACPI messages from dmesg (last 20 lines)..."
    dmesg | grep -i acpi | tail -n 20 || true
}

set_cpu_governor_performance() {
    local cpu_dir gov_file
    local cpus_found=false

    log "Setting CPU frequency governor to 'performance' for all CPUs..."

    for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
        [[ -d "$cpu_dir" ]] || continue
        cpus_found=true
        gov_file="$cpu_dir/cpufreq/scaling_governor"
        if [[ -w "$gov_file" ]]; then
            echo performance > "$gov_file"
        fi
    done

    if ! $cpus_found 2>/dev/null; then
        warn "No CPU directories found under /sys/devices/system/cpu/cpu[0-9]*."
    fi
}

pin_cpu_frequency_constant() {
    local cpu_dir max_file min_file max

    log "Pinning CPUs to constant frequency (min = max where possible)..."

    for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
        [[ -d "$cpu_dir" ]] || continue

        max_file="$cpu_dir/cpufreq/scaling_max_freq"
        min_file="$cpu_dir/cpufreq/scaling_min_freq"

        if [[ -r "$max_file" && -w "$min_file" ]]; then
            max=$(<"$max_file")
            echo "$max" > "$min_file"
        fi
    done
}

disable_turbo_if_possible() {
    log "Trying to disable CPU turbo/boost (if supported)..."

    # Intel P-state
    if [[ -w /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
        echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
        log "Disabled Intel turbo via intel_pstate no_turbo=1."
    fi

    # Generic cpufreq boost flag
    if [[ -w /sys/devices/system/cpu/cpufreq/boost ]]; then
        echo 0 > /sys/devices/system/cpu/cpufreq/boost
        log "Disabled generic cpufreq boost flag."
    fi

    # amd-pstate or other drivers may have different knobs; those are not handled explicitly here.
}

show_summary() {
    log "CPU governor summary:"
    for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
        [[ -d "$cpu_dir" ]] || continue
        if [[ -r "$cpu_dir/cpufreq/scaling_governor" ]]; then
            printf "  %s: %s\n" \
                "$(basename "$cpu_dir")" \
                "$(cat "$cpu_dir/cpufreq/scaling_governor")"
        fi
    done

    if [[ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]]; then
        log "Current frequency of cpu0:"
        cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq
    fi
}

main() {
    clean_caches
    check_acpi
    set_cpu_governor_performance
    pin_cpu_frequency_constant
    disable_turbo_if_possible
    show_summary

    log "Environment preparation complete."
}

main "$@"

