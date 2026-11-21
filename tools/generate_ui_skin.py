"""Regenerate text-free UI PNGs from the sampled Trickcal palette (Pillow)."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/ui/trickcal"
DEST.mkdir(parents=True, exist_ok=True)
S = 4
specs = {}

def plate(name, fill, edge, radius=16, width=2, shadow=False, focus=False,
          height=64, bottom_inset=0, slice_px=20):
    w, h = 96, height
    im = Image.new("RGBA", (w*S,h*S))
    d = ImageDraw.Draw(im)
    if shadow:
        d.rounded_rectangle((0,bottom_inset*S,w*S-1,h*S-1),radius=radius*S,fill="#B9B9B7")
    rect=(0,0,w*S-1,(h-bottom_inset)*S-1)
    d.rounded_rectangle(rect,radius=radius*S,fill=None if focus else fill,outline=edge,width=width*S)
    im.resize((w,h),Image.Resampling.LANCZOS).save(DEST/f"{name}.png")
    specs[name]={"size":[w,h],"slice":slice_px,"fill":fill,"edge":edge,"radius":radius,"shadow":shadow,"bottom_inset":bottom_inset}

plate("panel", "#F9F9F3", "#89CD4C",18)
plate("inset", "#E9F5CF", "#CDE793",12,1)
plate("inset_active", "#E9F5CF", "#5DA530",12,2)
plate("inset_flash", "#FFF3C7", "#E3C360",12,2)
plate("header", "#5DA530", "#5DA530",12,1)
button_states = [
    ("cancel_normal", "#FFF3C7", "#E3C360", True),
    ("cancel_hover", "#FFF3C7", "#5DA530", True),
    ("cancel_pressed", "#FFF3C7", "#E3C360", False),
    ("action_normal", "#FFDD74", "#F1A330", True),
    ("action_hover", "#FFDD74", "#5DA530", True),
    ("action_pressed", "#FFDD74", "#F1A330", False),
    ("disabled", "#A9A9A7", "#747C64", False),
    ("focus", None, "#5DA530", False),
]
for prefix, height, radius, inset, slice_px in [("",64,16,3,20),("compact_",32,10,2,14)]:
    for name, fill, edge, shadow in button_states:
        plate(prefix+name, fill, edge, radius, 2, shadow,
              focus=name=="focus",height=height,bottom_inset=inset,slice_px=slice_px)
(DEST/"skin_spec.json").write_text(json.dumps({"version":"0.2","scale_render":S,"compact_below_height":40,"assets":specs},ensure_ascii=False,indent=2),encoding="utf-8")
print(f"Generated {len(specs)} text-free PNG assets.")
