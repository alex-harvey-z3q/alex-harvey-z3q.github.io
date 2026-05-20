from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import fitz
from PIL import Image

SOURCE_ROOT = Path(__file__).resolve().parents[1]
SITE_ROOT = SOURCE_ROOT.parent
ASSET_DIR = SITE_ROOT / "assets" / "clementi"
OUT_PDF = SOURCE_ROOT / "generated" / "figures"
LY_DIR = SOURCE_ROOT / "lilypond"


def clear_outputs() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    OUT_PDF.mkdir(parents=True, exist_ok=True)
    for pattern in ("figure_*.png", "figure_*.pdf", "figures.pdf"):
        for path in ASSET_DIR.glob(pattern):
            path.unlink()
    for path in OUT_PDF.glob("*.pdf"):
        path.unlink()


def render_png(pdf_path: Path, out_png: Path) -> None:
    doc = fitz.open(pdf_path)
    images = []
    for page in doc:
        pix = page.get_pixmap(matrix=fitz.Matrix(2, 2), alpha=False)
        images.append(Image.frombytes("RGB", (pix.width, pix.height), pix.samples))
    if len(images) == 1:
        images[0].save(out_png)
    else:
        gap = 40
        width = max(image.width for image in images)
        height = sum(image.height for image in images) + gap * (len(images) - 1)
        combined = Image.new("RGB", (width, height), "white")
        y = 0
        for image in images:
            combined.paste(image, (0, y))
            y += image.height + gap
        combined.save(out_png)
    doc.close()


def lilypond_env() -> dict[str, str]:
    env = os.environ.copy()
    cache_dir = SOURCE_ROOT / ".cache" / "fontconfig"
    cache_dir.mkdir(parents=True, exist_ok=True)
    env.setdefault("XDG_CACHE_HOME", str(SOURCE_ROOT / ".cache"))
    env.setdefault("FONTCONFIG_PATH", "/opt/homebrew/etc/fonts")
    return env


def export_lilypond_sources() -> None:
    sys.path.insert(0, str(SOURCE_ROOT / "notation"))
    from export_lilypond import main as export_main

    export_main()


def render_lilypond_pdf(source: Path, out_base: Path) -> Path:
    subprocess.run(
        ["lilypond", "-fpdf", "-o", str(out_base), str(source)],
        check=True,
        cwd=SOURCE_ROOT,
        env=lilypond_env(),
    )
    return out_base.with_suffix(".pdf")


def main() -> None:
    clear_outputs()
    export_lilypond_sources()

    for ly_path in sorted(LY_DIR.glob("figure_*.ly")):
        out_base = OUT_PDF / ly_path.stem
        pdf_path = render_lilypond_pdf(ly_path, out_base)
        png_path = ASSET_DIR / f"{ly_path.stem}.png"
        render_png(pdf_path, png_path)
        pdf_path.unlink()

    print(f"Generated LilyPond-rendered figure PNGs in {ASSET_DIR}")


if __name__ == "__main__":
    main()
