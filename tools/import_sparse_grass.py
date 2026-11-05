"""Convert the downloaded ground textures without modifying the source archive.

Run with Blender:
  blender --background --disable-autoexec --python tools/import_sparse_grass.py -- \
    --source assets/source/sparse_grass_4k.blend.zip --output assets/environment/sparse_grass

The game uses 2K maps and no displacement geometry. Normal/roughness maps
are saved as linear PNG data, not display-transformed renders.
"""
import argparse
import sys
import tempfile
import zipfile
from pathlib import Path

import bpy


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--size", type=int, default=2048)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    if args.size < 1:
        parser.error("--size must be positive")
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    maps = (
        ("textures/sparse_grass_diff_4k.jpg", "albedo.jpg", "sRGB", "JPEG"),
        ("textures/sparse_grass_nor_gl_4k.exr", "normal.png", "Non-Color", "PNG"),
        ("textures/sparse_grass_rough_4k.exr", "roughness.png", "Non-Color", "PNG"),
    )
    with zipfile.ZipFile(args.source) as archive, tempfile.TemporaryDirectory() as temp:
        for member, name, color_space, file_format in maps:
            # Copy only known members; never extract untrusted archive paths.
            path = Path(temp) / Path(member).name
            path.write_bytes(archive.read(member))
            image = bpy.data.images.load(str(path), check_existing=False)
            image.colorspace_settings.name = color_space
            image.scale(args.size, args.size)
            image.file_format = file_format
            image.filepath_raw = str(output / name)
            image.save()
            print(f"Saved {name}: {args.size}x{args.size}, {color_space}")
            bpy.data.images.remove(image)


if __name__ == "__main__":
    main()
