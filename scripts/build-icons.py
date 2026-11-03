"""Compose the two plugin marks from vendored Google Material Design SVGs."""
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "material"
OUTPUT = ROOT / "assets" / "plugins"


def paths(name: str) -> str:
    svg = ET.parse(SOURCE / f"{name}.svg").getroot()
    return "".join(
        f'<path d="{element.attrib["d"]}"/>'
        for element in svg.iter("{http://www.w3.org/2000/svg}path")
        if element.get("fill") != "none"
    )


def compose(name: str, base: str, badge: str, accent: str) -> None:
    # Render at 128 px; the 32-unit composition stays clear in Studio's small toolbar.
    body = f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 32 32">
  <title>Asset {name}: Material {base} + {badge}</title>
  <g transform="translate(0 1) scale(1.12)" fill="{accent}">{paths(base)}</g>
  <circle cx="24" cy="24" r="8" fill="#ffffff"/>
  <circle cx="24" cy="24" r="7" fill="#18364f"/>
  <g transform="translate(17.5 17.5) scale(0.542)" fill="#ffffff">{paths(badge)}</g>
</svg>
'''
    (OUTPUT / f"{name}.svg").write_text(body, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    compose("Previewer", "view_in_ar", "visibility", "#268ee6")
    compose("Organizer", "folder", "label", "#19a397")
