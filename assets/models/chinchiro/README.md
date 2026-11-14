# Chinchiro rice bowl

`rice_bowl_v01.tscn` is the in-game model; `rice_bowl_v01.glb` is a portable copy.
Both contain the same 5,376-triangle ceramic mesh with baked vertex colours.
The bowl has a closed underside, foot, curved inner/outer walls and rounded lip.
The mouth is open, and the blue floor ring is part of the ceramic surface.

Regenerate both from the checked-in profile with:

```sh
godot --headless --path . -s res://tools/build_chinchiro_bowl.gd
```

The native model is 6.62 units wide and 2.2049 units high. Its inner floor is at
Y = 0.30. The same profile supplies the presentation's contact-height constraint.
`DiceRoll3D` instances the scene only for CHINCHIRO and keeps one cached model.
The die's confirmed engine result is unchanged; the scene adds no random roll.

This is a Godot-generated mesh, not a Blender asset. It needs no runtime editor,
external textures, physics server, or additional download.
