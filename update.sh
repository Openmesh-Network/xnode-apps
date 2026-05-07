set -e

for file in ./*; do
    [ -d "$file" ] || continue
    [ "$(basename "$file")" = "example" ] && continue
    nix flake update --flake "$file"
    echo "Updated $file"
done
