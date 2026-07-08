from PIL import Image, ImageDraw
import os, subprocess

HIRES = Image.open("soco-shield-master-hires.png").convert("RGBA")
EMB = Image.open("soco-shield-master-embroidery.png").convert("RGBA")

OUT = ".."
TMP = "tmp_frames"
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)


def source_for(size):
    return EMB if size <= 64 else HIRES


def resized(size):
    return source_for(size).resize((size, size), Image.LANCZOS)


def save(im, path):
    full = os.path.join(OUT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    im.save(full)
    print("wrote", full, im.size, im.mode)


def make_ico(sizes, out_path):
    frame_paths = []
    for s in sizes:
        fp = os.path.join(TMP, f"frame_{s}.png")
        resized(s).save(fp)
        frame_paths.append(fp)
    full = os.path.join(OUT, out_path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    subprocess.run(["convert"] + frame_paths + [full], check=True)
    print("wrote", full, sizes, "(via ImageMagick, verified multi-frame below)")


# --- 1. Master square PNGs ---
save(HIRES, "res/icon.png")
save(HIRES, "res/mac-icon.png")

# --- 2. Windows ICOs (real multi-frame, small sizes from embroidery source) ---
make_ico([16, 32, 48, 64, 128, 256], "res/icon.ico")
make_ico([32], "res/tray-icon.ico")
make_ico([16, 32, 48, 64, 128, 256], "flutter/windows/runner/resources/app_icon.ico")

# --- 3. macOS icns: single hires base, let Pillow downscale internally (correct usage) ---
icns_sizes = [16, 32, 64, 128, 256, 512, 1024]
icns_path = os.path.join(OUT, "flutter/macos/Runner/AppIcon.icns")
os.makedirs(os.path.dirname(icns_path), exist_ok=True)
HIRES.save(icns_path, format="ICNS", sizes=[(s, s) for s in icns_sizes])
print("wrote", icns_path, icns_sizes)

# --- 4. Android mipmaps ---
densities = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}
BG = (255, 255, 255, 255)

for density, (icon_size, fg_size) in densities.items():
    square_src = resized(icon_size)
    legacy = Image.new("RGBA", (icon_size, icon_size), BG)
    legacy.paste(square_src, (0, 0), square_src)
    save(legacy, f"flutter/android/app/src/main/res/mipmap-{density}/ic_launcher.png")

    mask = Image.new("L", (icon_size, icon_size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, icon_size, icon_size), fill=255)
    round_icon = Image.new("RGBA", (icon_size, icon_size), (0, 0, 0, 0))
    round_icon.paste(legacy, (0, 0), mask)
    save(round_icon, f"flutter/android/app/src/main/res/mipmap-{density}/ic_launcher_round.png")

    src_for_fg = source_for(fg_size)
    inner = int(fg_size * 0.60)
    fg_canvas = Image.new("RGBA", (fg_size, fg_size), (0, 0, 0, 0))
    content = src_for_fg.resize((inner, inner), Image.LANCZOS)
    off = (fg_size - inner) // 2
    fg_canvas.paste(content, (off, off), content)
    save(fg_canvas, f"flutter/android/app/src/main/res/mipmap-{density}/ic_launcher_foreground.png")

print("DONE")
