#!/bin/bash

# 1. Generate Dark Icons
echo "Generating Dark Icons..."
dart run flutter_launcher_icons -f flutter_launcher_icons_dark.yaml

# 2. Rename Android Dark Assets
echo "Renaming Android Dark Assets..."
cd android/app/src/main/res

# Rename adaptive background color if it exists
if [ -f "values/ic_launcher_background.xml" ]; then
    mv values/ic_launcher_background.xml values/ic_launcher_background_dark.xml
fi

# Loop through mipmap folders
for dir in mipmap-*; do
    if [ -d "$dir" ]; then
        # Rename PNGs
        [ -f "$dir/ic_launcher.png" ] && mv "$dir/ic_launcher.png" "$dir/ic_launcher_dark.png"
        [ -f "$dir/ic_launcher_round.png" ] && mv "$dir/ic_launcher_round.png" "$dir/ic_launcher_dark_round.png"
        [ -f "$dir/ic_launcher_foreground.png" ] && mv "$dir/ic_launcher_foreground.png" "$dir/ic_launcher_foreground_dark.png"
        
        # Handle XMLs in anydpi-v26
        if [[ "$dir" == "mipmap-anydpi-v26" ]]; then
            if [ -f "$dir/ic_launcher.xml" ]; then
                 mv "$dir/ic_launcher.xml" "$dir/ic_launcher_dark.xml"
                 # Update references in XML
                 sed -i 's/ic_launcher_background/ic_launcher_background_dark/g' "$dir/ic_launcher_dark.xml"
                 sed -i 's/ic_launcher_foreground/ic_launcher_foreground_dark/g' "$dir/ic_launcher_dark.xml"
            fi
            if [ -f "$dir/ic_launcher_round.xml" ]; then
                 mv "$dir/ic_launcher_round.xml" "$dir/ic_launcher_dark_round.xml"
                  # Update references in XML
                 sed -i 's/ic_launcher_background/ic_launcher_background_dark/g' "$dir/ic_launcher_dark_round.xml"
                 sed -i 's/ic_launcher_foreground/ic_launcher_foreground_dark/g' "$dir/ic_launcher_dark_round.xml"
            fi
        fi
    fi
done

# Loop through drawable folders for foreground icons
for dir in drawable-*; do
    if [ -d "$dir" ]; then
         [ -f "$dir/ic_launcher_foreground.png" ] && mv "$dir/ic_launcher_foreground.png" "$dir/ic_launcher_foreground_dark.png"
    fi
done

cd ../../../../..

# 3. Handle iOS Dark Assets
echo "Copying iOS Dark Assets..."
# Remove existing if any
rm -rf ios/Runner/Assets.xcassets/AppIconDark.appiconset
cp -r ios/Runner/Assets.xcassets/AppIcon.appiconset ios/Runner/Assets.xcassets/AppIconDark.appiconset

# 4. Generate Light Icons (Default)
echo "Generating Light (Default) Icons..."
dart run flutter_launcher_icons -f flutter_launcher_icons_light.yaml

echo "Done."
