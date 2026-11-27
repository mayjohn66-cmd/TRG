"""Export frame-delimited Godot Movie Maker footage as edit-friendly H.264 clips."""
import json
from pathlib import Path
import subprocess
import sys

folder, ffmpeg = Path(sys.argv[1]).resolve(), str(Path(sys.argv[2]).resolve())
output = folder / "videos"
output.mkdir(exist_ok=True)
clips = json.loads((folder / "clips.json").read_text(encoding="utf-8"))
names = []
for clip in clips:
    target = output / (clip["name"] + ".mp4")
    start = clip["start_frame"] / 30
    duration = (clip["end_frame"] - clip["start_frame"]) / 30
    subprocess.run([
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-ss", f"{start:.9f}",
        "-i", str(folder / "final-tools.avi"), "-t", f"{duration:.9f}",
        "-map", "0:v:0", "-map", "0:a:0", "-c:v", "libx264", "-preset", "fast",
        "-crf", "18", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "128k",
        "-movflags", "+faststart", str(target),
    ], check=True)
    names.append(target.name)
    print(target.name, f"{duration:.2f}s", target.stat().st_size, flush=True)
(output / "concat.txt").write_text("".join(f"file '{name}'\n" for name in names), encoding="utf-8")
subprocess.run([
    ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0",
    "-i", str(output / "concat.txt"), "-c", "copy", "-movflags", "+faststart",
    str(output / "all-direct-tools.mp4"),
], check=True)
print("EXPORTED", len(names), "clips plus combined video", flush=True)
