bspc subscribe desktop_layout | while read -r _ _ desktop_id layout; do
    if [ "$layout" == "tiled" ]; then
        # If tiled set _PICOM_MONOCLE to all window nodes
        bspc query -N -n .window -d "$desktop_id" \
        | xargs -I % xprop -id % -f "$HINT" 32c -set "$HINT" 1;
    else
        # Else, set 0 to all non focused window nodes
        bspc query -N -n .window.!focused -d "$desktop_id" \
        | xargs -I % xprop -id % -f "$HINT" 32c -set "$HINT" 0;
    fi
done
