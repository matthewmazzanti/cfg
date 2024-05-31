kitty \
    -o remember_window_size=no \
    -o initial_window_width=1300 \
    -o initial_window_height=800 \
    -o background_opacity=0.7 \
    --class=launcher \
    bash -c \
    "compgen -c \
    | grep -v wrapped \
    | sort -u \
    | fzf --layout=reverse \
    | xargs -r -i launch {}"
