"""Records the PRAM announcements (female voice, en-US-JennyNeural) into
assets/pram/<id>.mp3, using the scripts in lib/models/pram_item.dart.

    python tool/gen_pram.py
"""
import asyncio
import os
import re

import edge_tts

VOICE = "en-US-JennyNeural"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)


def read_scripts():
    src = open(os.path.join(ROOT, "lib", "models", "pram_item.dart"), encoding="utf-8").read()
    items = {}
    for block in re.findall(r"PramItem\((.*?)\n  \)", src, re.S):
        if "isMusic: true" in block:
            continue
        pid = re.search(r"id: '([^']+)'", block).group(1)
        script = re.search(r"script:\s*((?:'[^']*'\s*)+)", block).group(1)
        items[pid] = "".join(re.findall(r"'([^']*)'", script))
    return items


async def main():
    out = os.path.join(ROOT, "assets", "pram")
    os.makedirs(out, exist_ok=True)
    for pid, text in read_scripts().items():
        path = os.path.join(out, pid + ".mp3")
        await edge_tts.Communicate(text, VOICE, rate="+0%").save(path)
        print(pid, os.path.getsize(path), "bytes")


asyncio.run(main())
