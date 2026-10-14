"""Trim the five CC0 stone-on-board transients from the unaltered Freesound preview."""
import array
import hashlib
import json
import math
import pathlib
import wave

root = pathlib.Path(__file__).resolve().parents[1]
with wave.open(str(root / ".runtime/go-stones-decoded.wav"), "rb") as f:
    rate = f.getframerate()
    samples = array.array("h", f.readframes(f.getnframes()))
window = int(rate * 0.015)
energy = [max(abs(x) for x in samples[i:i+window]) / 32768 for i in range(0,len(samples),window)]
events = []
for i, level in enumerate(energy):
    t = i * window / rate
    if level > 0.12 and (not events or t-events[-1] > 0.6):
        events.append(t)
assert len(events) == 5, events
records = []
for index, t in enumerate(events):
    start, end = max(0, int((t-0.02)*rate)), min(len(samples),int((t+0.36)*rate))
    clip = list(samples[start:end])
    # Remove DC and gently trim the tail. Preserve relative timbre.
    dc = sum(clip)/len(clip)
    peak = max(abs(x-dc) for x in clip)
    gain = min(1.3, 24000/peak)
    out = array.array("h")
    for i, x in enumerate(clip):
        fade_in = min(1, i / max(1, int(0.002*rate)))
        fade_out = min(1, (len(clip)-1-i) / max(1,int(0.035*rate)))
        out.append(round((x-dc)*gain*fade_in*fade_out))
    target = root / f"assets/audio/stone-{index+1}.wav"
    with wave.open(str(target),"wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(out.tobytes())
    records.append({"file":str(target.relative_to(root)).replace("\\","/"),"source_start":start/rate,
                    "source_end":end/rate,"sha256":hashlib.sha256(target.read_bytes()).hexdigest(),
                    "peak":max(abs(x) for x in out)/32768})
source = root / "assets/audio/go-stones-source.mp3"
manifest = {
    "title":"GoStoneSounds.ogg","author":"billhails2",
    "source":"https://freesound.org/people/billhails2/sounds/588317/",
    "download":"https://cdn.freesound.org/previews/588/588317_12616419-hq.mp3",
    "license":"CC0 1.0","license_url":"https://creativecommons.org/publicdomain/zero/1.0/",
    "retrieved":"2026-10-11","description":"Real Yunzi stones on tabletop and shin-kaya boards, author-recorded.",
    "source_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),
    "processing":"Mono PCM decode, five transients trimmed, DC removal, short fades, bounded gain. No pitch changes.",
    "clips":records
}
(root/"assets/audio/source.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps({"events":events,"clips":records},indent=2))
