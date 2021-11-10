#! /bin/sh

db='db.txt'
base='https://devimages-cdn.apple.com/design/resources/download'
files='NY.dmg SF-Mono.dmg SF-Pro.dmg NY.dmg SF-Arabic.dmg SF-Compact.dmg'

isotimestamp='%Y-%m-%dT%H:%M:%SZ'

touch "$db"
for f in $files; do
    curl -o "$f" "$base/$f"
    ck=$(cksum "$f")
    if grep -q "$ck" "$db"; then
        rm "$f"
        continue
    fi

    ts=$(date -u "+$isotimestamp")
    mv "$f" "${ts}_$f"
    ( cat "$db"; printf "%s %s\n" "$ck" "$ts" ) |
        sort -k 3,3 -k 2,2 > "$db.tmp"
    mv "$db.tmp" "$db"
done
