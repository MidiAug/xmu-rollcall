"""Create the self-hosted website font from the repository's OFL test font.

Optional maintenance dependency: fonttools and brotli in .tools/site-font.
The normal website build only copies the resulting WOFF2 file.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".tools" / "site-font"))

from fontTools import subset


def main() -> None:
    texts = [p.read_text(encoding="utf-8-sig") for p in (ROOT / "site").glob("*.html")]
    texts.append((ROOT / "scripts" / "build_site.py").read_text(encoding="utf-8"))
    options = subset.Options()
    options.flavor = "woff2"
    options.recalc_timestamp = False
    font = subset.load_font(str(ROOT / "test/fixtures/fonts/NotoSansSC-Regular.otf"), options)
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(text="".join(texts))
    subsetter.subset(font)
    # Give the modified subset its own family name; retain copyright and license.
    names = {1: "Rollcall Web", 3: "RollcallWeb-Regular", 4: "Rollcall Web Regular",
             6: "RollcallWeb-Regular", 16: "Rollcall Web", 17: "Regular"}
    for record in list(font["name"].names):
        if record.nameID in names:
            font["name"].setName(names[record.nameID], record.nameID,
                                 record.platformID, record.platEncID, record.langID)
    target = ROOT / "site/fonts/rollcall-web.woff2"
    target.parent.mkdir(parents=True, exist_ok=True)
    subset.save_font(font, str(target), options)
    print(f"Created {target.name}: {target.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
