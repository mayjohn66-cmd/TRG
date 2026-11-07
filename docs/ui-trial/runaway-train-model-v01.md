# Runaway toy train model

Static model based on the supplied pastel toy locomotive reference: rounded blue boiler, cream bands, coral chassis and cowcatcher, arched golden roof, brown cab windows, embossed number 3 and six large driving wheels. Four open freight wagons follow in blue, butter yellow, mint and lilac, with cream rails and visible plank floors. Each wagon has four wheels.

The final asset is `assets/models/runaway_train/runaway_train_v02.tscn`, with a portable `runaway_train_v02.glb` beside it. `scenes/runaway_train_3d.gd` is the editable model generator. These are real meshes and PBR materials; the reference image is not used as a billboard. The model faces local -X; Y is up and Z is the axle direction. Separate locomotive, four wagon roots, 22 wheel pivots, front/rear coupling markers and four drawbars are retained for a later animation pass. No gameplay or train attack animation is connected yet.

`scenes/runaway_train_preview.tscn` provides a standalone inspection scene: left drag orbits the camera, wheel zooms, 1 frames the locomotive and 2 frames the whole train.

Generated and rendered in Godot 4.7.1 Compatibility. Saved native-scene and GLB readbacks preserve the same 270 mesh instances, 86,912 triangles, 22 wheels and four wagons. Positions and normals are finite, zero-area triangles are removed, and all four coupling pairs have matching height/lateral alignment. Overall dimensions are approximately 19.02 x 3.39 x 2.50 model units. GLB size is about 0.8 MB. Studio previews and the detailed validation report are in workspace `outputs/runaway-train-v02/soft-studio/`.
