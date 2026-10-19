"""Build a small browser fixture from the production Sfx script and OGG.

python build_web_audio_fixture.py <scratch dir> <web_nothreads_release.zip> <godot executable>
The GameSession stand-in supplies only the three settings consumed by Sfx.
"""
from pathlib import Path
import shutil, subprocess, os, sys
repo=Path(__file__).resolve().parents[2]
dest=Path(sys.argv[1]).resolve()
template=Path(sys.argv[2]).resolve()
exe=sys.argv[3]
assert not (dest/'project.godot').exists(), 'Use a new scratch directory.'
(dest/'scenes').mkdir(parents=True,exist_ok=True)
(dest/'assets/sfx').mkdir(parents=True,exist_ok=True)
(dest/'assets/bgm').mkdir(parents=True,exist_ok=True)
(dest/'build').mkdir(exist_ok=True)
shutil.copy2(repo/'scenes/sfx.gd',dest/'scenes/sfx.gd')
shutil.copy2(repo/'assets/sfx/hop_01.ogg',dest/'assets/sfx/hop_01.ogg')
shutil.copy2(repo/'assets/bgm/lobby_daylife.ogg',dest/'assets/bgm/lobby_daylife.ogg')
shutil.copy2(repo/'assets/bgm/battle_monatium_night.ogg',dest/'assets/bgm/battle_monatium_night.ogg')
(dest/'game_session.gd').write_text('class_name GameSession\nextends RefCounted\nstatic var audio_muted: bool = false\nstatic var sfx_volume: float = 0.8\nstatic var bgm_volume: float = 0.6\n')
(dest/'project.godot').write_text('''config_version=5
[application]
config/name="Web Audio Regression"
run/main_scene="res://main.tscn"
[display]
window/size/viewport_width=640
window/size/viewport_height=360
[rendering]
renderer/rendering_method="gl_compatibility"
''')
(dest/'main.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://main.gd" id="1"]\n[node name="AudioFixture" type="Node"]\nscript=ExtResource("1")\n')
(dest/'main.gd').write_text('''extends Node
var callback: JavaScriptObject
func _ready() -> void:
 Sfx.apply_settings()
 callback=JavaScriptBridge.create_callback(_command)
 JavaScriptBridge.get_interface("window").audioCommand=callback
 JavaScriptBridge.eval("window.audioFixtureReady=true")
func _command(args: Array) -> void:
 var command: String = str(args[0])
 match command:
  "file": Sfx.play(&"hop",0.0,0.0)
  "synth": Sfx.play(&"roulette_tick",0.0,0.0)
  "mute": GameSession.audio_muted=true; Sfx.apply_settings()
  "unmute": GameSession.audio_muted=false; Sfx.apply_settings()
  "quiet": GameSession.sfx_volume=0.1; Sfx.apply_settings()
  "loud": GameSession.sfx_volume=0.8; Sfx.apply_settings()
  "repeat": Sfx.apply_settings()
  "bgm": Sfx.bgm_play(Sfx.LOBBY_TRACK)
  "battle": Sfx.bgm_stop(); Sfx.bgm_play(Sfx.BATTLE_TRACK)
  "bgm_stop": Sfx.bgm_stop()
  "bgm_quiet": GameSession.bgm_volume=0.1; Sfx.apply_settings()
  "bgm_loud": GameSession.bgm_volume=0.6; Sfx.apply_settings()
 JavaScriptBridge.eval("window.audioFixtureState="+JSON.stringify({"muted":GameSession.audio_muted,"volume":GameSession.sfx_volume,"buses":AudioServer.bus_count,"master":AudioServer.get_bus_name(0),"sfx":AudioServer.get_bus_index(&"SFX"),"bgm":AudioServer.get_bus_index(&"BGM")}))
 JavaScriptBridge.eval("window.bgmFixtureState="+JSON.stringify({"track":String(Sfx._bgm_name),"playing":Sfx._bgm.playing if Sfx._bgm != null else false,"position":Sfx._bgm.get_playback_position() if Sfx._bgm != null else 0.0,"length":Sfx._bgm.stream.get_length() if Sfx._bgm != null and Sfx._bgm.stream != null else 0.0,"loop":Sfx._bgm.stream.loop if Sfx._bgm != null and Sfx._bgm.stream != null else false}))
''')
preset=(repo/'export_presets.cfg').read_text(encoding='utf-8').replace('custom_template/release=""','custom_template/release="'+template.as_posix()+'"').replace('html/custom_html_shell="res://web/shell.html"','html/custom_html_shell=""')
(dest/'export_presets.cfg').write_text(preset,encoding='utf-8')
runtime=dest/'.runtime';runtime.mkdir()
env=os.environ.copy();env['APPDATA']=str(runtime);env['LOCALAPPDATA']=str(runtime)
for args in [['--import'],['--export-release','Web','build/index.html']]:
 p=subprocess.run([exe,'--headless','--path',str(dest),*args],env=env,capture_output=True,timeout=120)
 print(p.stdout.decode('utf-8',errors='replace')[-1500:]);print(p.stderr.decode('utf-8',errors='replace')[-1500:])
 if p.returncode:sys.exit(p.returncode)
print('AUDIO_FIXTURE_EXPORTED')
