#!/usr/bin/env bash
# Waybar status for the OneDrive client (abraunegg), running as the
# `onedrive` systemd user service. Prints one line of JSON for a custom module.
#
# States (CSS classes): synced, syncing, warning, error, stopped

icon_synced=$'\U000f0160'   # md-cloud_check
icon_syncing=$'\U000f063f'  # md-cloud_sync
icon_error=$'\U000f09e0'    # md-cloud_alert
icon_stopped=$'\U000f0164'  # md-cloud_off_outline

emit() { # icon, class, tooltip
    jq -cn --arg text "$1" --arg class "$2" --arg tooltip "$3" \
        '{text: $text, class: $class, alt: $class, tooltip: $tooltip}'
}

if ! systemctl --user is-active --quiet onedrive; then
    emit "$icon_stopped" stopped "OneDrive is not running
Click to start it"
    exit 0
fi

log=$(journalctl --user -u onedrive -n 500 -o cat --no-pager 2>/dev/null)

# Line number of the last match for a pattern (0 if none)
last() { grep -nE "$1" <<<"$log" | tail -1 | cut -d: -f1; }

done_at=$(last '^Sync with Microsoft OneDrive is complete')
partial_at=$(last '^Sync with Microsoft OneDrive has completed, however')
fail_at=$(last '^ERROR: |^Sync with Microsoft OneDrive was interrupted')
work_at=$(last '^(Starting a sync|Performing initial|Fetching items|Syncing changes|Downloading file|Uploading|Deleting item)')
done_at=${done_at:-0} partial_at=${partial_at:-0} fail_at=${fail_at:-0} work_at=${work_at:-0}

finished=$(( done_at > partial_at ? done_at : partial_at ))

# Most recent meaningful activity, for the tooltip
recent=$(grep -vE '^(Attempting to contact|Successfully reached|Configuring Global)' <<<"$log" | tail -1 | cut -c1-90)
since=$(systemctl --user show onedrive -p ActiveEnterTimestamp --value | cut -d' ' -f2-3)

if (( fail_at > finished )); then
    emit "$icon_error" error "OneDrive: problem syncing
$(sed -n "${fail_at}p" <<<"$log" | cut -c1-90)
Click to open the log"
elif (( work_at > finished )); then
    emit "$icon_syncing" syncing "OneDrive: syncing…
$recent"
elif (( partial_at > done_at )); then
    emit "$icon_error" warning "OneDrive: synced, but some items failed
Click to open the log"
else
    emit "$icon_synced" synced "OneDrive: up to date
Running since $since"
fi
