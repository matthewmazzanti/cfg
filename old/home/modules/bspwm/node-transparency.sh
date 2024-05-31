# Store last ids
PREV_NODE_ID=
PREV_DESK_ID=

# On every focus change, set my custom _PICOM_MONOCLE xprop to 1,
bspc subscribe node_focus | while read -r _ _ desktop_id node_id; do
    xprop -id "$node_id" -f "$HINT" 32c -set "$HINT" 1;

    # Check if previous desktop is the same of now (no need to hide when changing desktops)
    if [ "$PREV_DESK_ID" == "$desktop_id" ] && [ "$PREV_NODE_ID" != "$node_id" ]; then
        # Get the layout of the previous node to hide
        PREV_LAYOUT=$(bspc query -T -d "$desktop_id" | jq -r .layout);

        # Hide the previous node only if it was on a monocle desktop
        [ "$PREV_LAYOUT" == "monocle" ] && xprop -id "$PREV_NODE_ID" -f "$HINT" 32c -set "$HINT" 0;
    fi

    # Update previous ids
    PREV_NODE_ID=$node_id
    PREV_DESK_ID=$desktop_id
done
