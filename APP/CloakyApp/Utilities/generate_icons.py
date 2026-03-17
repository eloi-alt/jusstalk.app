import os
import json
import subprocess

base_dir = "/Users/eloi/Desktop/cloakyy/CloakyApp/Resources/Assets.xcassets/AppIcon.appiconset"
source_icon = os.path.join(base_dir, "icon.png")

# Define all the required icon sizes based on standard iOS App Icon set
# (idiom, size, scale)
icons_config = [
    ("iphone", 20, 2),
    ("iphone", 20, 3),
    ("iphone", 29, 2),
    ("iphone", 29, 3),
    ("iphone", 40, 2),
    ("iphone", 40, 3),
    ("iphone", 60, 2),
    ("iphone", 60, 3),
    ("ipad", 20, 1),
    ("ipad", 20, 2),
    ("ipad", 29, 1),
    ("ipad", 29, 2),
    ("ipad", 40, 1),
    ("ipad", 40, 2),
    ("ipad", 76, 1),
    ("ipad", 76, 2),
    ("ipad", 83.5, 2),
    ("ios-marketing", 1024, 1)
]

images_json = []

for idiom, size, scale in icons_config:
    pixel_size = int(size * scale)
    filename = f"icon_{size}x{size}_{scale}x.png"
    if idiom == "ios-marketing":
         filename = "icon_1024x1024_1x.png" 
    
    filepath = os.path.join(base_dir, filename)
    
    # Use sips to resize
    cmd = ["sips", "-z", str(pixel_size), str(pixel_size), source_icon, "--out", filepath]
    print(f"Generating {filename} ({pixel_size}x{pixel_size})...")
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    entry = {
        "size": f"{size}x{size}" if size != 83.5 else "83.5x83.5",
        "idiom": idiom,
        "filename": filename,
        "scale": f"{scale}x"
    }
    
    # Clean up floats (e.g. 20.0x20.0 -> 20x20)
    if entry["size"].endswith(".0x20.0"): entry["size"] = "20x20" # simplistic check, better to format
    if size == int(size):
        entry["size"] = f"{int(size)}x{int(size)}"
    else:
        entry["size"] = f"{size}x{size}"
        
    images_json.append(entry)

contents = {
    "images": images_json,
    "info": {
        "version": 1,
        "author": "xcode"
    }
}

with open(os.path.join(base_dir, "Contents.json"), "w") as f:
    json.dump(contents, f, indent=2)

print("Done generating icons and Contents.json")
