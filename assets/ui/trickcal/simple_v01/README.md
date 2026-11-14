# Simple common UI skins v0.1

User direction: simple UI, familiar existing green/cream palette. No clover, ornamental corners, metallic frames or flashy highlights. Primary actions retain #FFDD74 yellow; secondary actions retain #FFF3C7 cream, panels use #E9F5CF light green, outlines use #5DA530 and live text #333333. Existing green header and inset skins stay unchanged.

Three original PNGs were generated with built-in imagegen and copied byte-for-byte. skins.source.json records prompts, source names, SHA-256 and visible bounds. Rejected ornate and hollow-panel attempts are not project assets.

UiSkin samples the visible source bounds and caches display-sized textures, then uses 9-slice stretching. Backgrounds and buttons share their geometry across normal, hover, pressed and disabled states. Hover/press use a small brightness change; keyboard focus is a simple green outline. Labels, click areas, margins, sounds and game rules remain live controls. Existing specialized circular roll, hub and augment skins are separate.

Runtime import: max 512px, lossy quality 0.9, no mipmaps. Originals are unchanged. Native screenshots and menu/lobby smoke checks are stored in task outputs/simple-ui-v01. Browser testing uses ego-browser per user direction and requires the CLI to be available.
