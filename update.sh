#! /bin/sh

db='db.txt'
base='https://devimages-cdn.apple.com/design/resources/download'
files='NY.dmg SF-Mono.dmg SF-Pro.dmg NY.dmg SF-Arabic.dmg SF-Compact.dmg'

isotimestamp='%Y-%m-%dT%H:%M:%SZ'

touch "$db"

update() {
    for u_f in $files; do
        curl -sS -o "$u_f" "$base/$u_f"
        # Generate cksum of DMG
        u_ck=$(cksum "$u_f")
        if grep -q "$u_ck" "$db"; then
            printf "File %s already in DB\n" "$u_f" 2>&2
            rm "$u_f"
            continue
        fi

        # Create backup of file.
        u_ts=$(date -u "+$isotimestamp")
        mv "$u_f" "${u_ts}_$u_f"

        # Generate cksum of cksums of contained fonts
        # This is needed since somtimes Apple repackages the DMG w/o changing
        # the fonts
        generate_cksum "${u_ts}_$u_f"
        u_fck=$(cksum "${u_ts}_$u_f.txt" | cut -d' ' -f1)
        
        ( cat "$db"; printf "%s %s %s %s\n" "$u_ck" "$u_ts" "$u_fck") |
            sort -k 3,3 -k 2,2 > "$db.tmp"
        mv "$db.tmp" "$db"
    done
}

generate_cksum() {
    gck_f="$1"
    gck_fontdir=$(extract_dmg "$gck_f")
    find "$gck_fontdir" \( -name '*.otf' -o -name '*.ttf' \) -execdir \
        cksum {} + > "$gck_f.txt"
}

verify() {
    while read -r v_ck v_no v_f v_ts v_fck; do
        if [ ! -f "${v_ts}_$v_f" ]; then
            printf "Warning: %s from %s not found!\n" "$v_f" "$v_ts" >&2
            continue
        fi
        v_ck2=$(cksum "${v_ts}_$v_f")
        if [ "$v_ck2" = "$v_ck $v_no" ]; then
            printf "Warning: Checksum for %s from %s not matching\n" "$v_f" "$v_ts" >&2
            continue
        fi
    done < "$db"
}

extract() {
    if [ "$#" -ne 2 ]; then printf 'extract called with wrong # of args\n' >&2; exit 1; fi

    e_ar="$1"
    e_dir="$2"
    if [ ! -d "$e_dir" ]; then
        7z x -y -o"$e_dir" "$e_ar" >&2
    fi
}

extract_dmg() {
    if [ "$#" -ne 1 ]; then printf "extract_dmg called with wrong # of args\n" >&2; exit 1; fi

    ed_oldpwd="$PWD"
    ed_ar="$1"
    extract "$ed_ar" "$ed_ar.dir"
    cd "$ed_ar.dir"
    ed_pkg=$(find . -name '*.pkg')
    extract "$ed_pkg" "$ed_pkg.dir"
    cd "$ed_pkg.dir"
    ed_pld=$(find . -name 'Payload~')
    extract "$ed_pld" "$ed_pld.dir"
    cd "$ed_pld.dir"
    cd Library/Fonts
    ed_fontpwd="$PWD"
    cd "$ed_oldpwd"

    # Print relative path
    ed_fontdir="${ed_fontpwd#$ed_oldpwd/}"
    echo "$ed_fontdir"
}

while getopts "uv" opt; do
    case "$opt" in
    u)  update ;;
    v)  verify ;;
    esac
done

