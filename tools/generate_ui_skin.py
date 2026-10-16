"""Regenerate text-free UI PNGs from the sampled Trickcal palette (Pillow)."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/ui/trickcal"
DEST.mkdir(parents=True, exist_ok=True)
S = 4
specs = {}

def plate(name, fill, edge, radius=16, width=2, shadow=False, focus=False):
    w, h = 96, 64
    im = Image.new("RGBA", (w*S,h*S))
    d = ImageDraw.Draw(im)
    if shadow:
        d.rounded_rectangle((0,3*S,w*S-1,h*S-1),radius=radius*S,fill="#B9B9B7")
    rect=(0,0,w*S-1,(h-(3 if shadow else 0))*S-1)
    d.rounded_rectangle(rect,radius=radius*S,fill=None if focus else fill,outline=edge,width=width*S)
    im.resize((w,h),Image.Resampling.LANCZOS).save(DEST/f"{name}.png")
    specs[name]={"size":[w,h],"slice":20,"fill":fill,"edge":edge,"radius":radius,"shadow":shadow}

plate("panel", "#F9F9F3", "#89CD4C",18)
plate("inset", "#E9F5CF", "#CDE793",12,1)
plate("inset_active", "#E9F5CF", "#5DA530",12,2)
plate("inset_flash", "#FFF3C7", "#E3C360",12,2)
plate("header", "#5DA530", "#5DA530",12,1)
plate("cancel_normal", "#FFF3C7", "#E3C360",16,2,True)
plate("cancel_hover", "#FFF3C7", "#5DA530",16,2,True)
plate("cancel_pressed", "#FFF3C7", "#E3C360",16,2)
plate("action_normal", "#FFDD74", "#F1A330",16,2,True)
plate("action_hover", "#FFDD74", "#5DA530",16,2,True)
plate("action_pressed", "#FFDD74", "#F1A330",16,2)
plate("disabled", "#A9A9A7", "#747C64",16,2)
plate("focus", None, "#5DA530",16,2,focus=True)
(DEST/"skin_spec.json").write_text(json.dumps({"version":"0.1","scale_render":S,"assets":specs},ensure_ascii=False,indent=2),encoding="utf-8")
print(f"Generated {len(specs)} text-free PNG assets.")
