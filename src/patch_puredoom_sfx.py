# patch_puredoom_sfx.py
#
# Creates PureDOOM_SfxHooked.h from PureDOOM.h by inserting a bridge callback
# into PureDOOM's I_StartSound().  Build DoomBridge.dll after running this file
# if you want MQL5 to receive actual DOOM SFX events via DoomPollSfxEvents().
#
# Usage:
#   python patch_puredoom_sfx.py
#   mingw32-make clean
#   mingw32-make

from pathlib import Path

src = Path("PureDOOM.h")
dst = Path("PureDOOM_SfxHooked.h")

if not src.exists():
    raise SystemExit("PureDOOM.h was not found in this directory.")

text = src.read_text(encoding="latin-1")

if "DoomBridge_PushSfxEvent(id, vol, sep, pitch, priority);" in text:
    dst.write_text(text, encoding="latin-1")
    print(f"PureDOOM.h already appears to be hooked. Wrote {dst}.")
    raise SystemExit(0)

old = '''int I_StartSound(int id, int vol, int sep, int pitch, int priority)
{
    // Returns a handle (not used).
    id = addsfx(id, vol, steptable[pitch], sep);
    return id;
}
'''

new = '''int I_StartSound(int id, int vol, int sep, int pitch, int priority)
{
    // Notify the MT5 bridge that a game SFX event has started.
    // The original id is the DOOM sfxenum_t value, which MQL5 maps to a WAV name.
    DoomBridge_PushSfxEvent(id, vol, sep, pitch, priority);

    // Returns a handle (not used).
    id = addsfx(id, vol, steptable[pitch], sep);
    return id;
}
'''

if old not in text:
    raise SystemExit(
        "Could not find the expected I_StartSound() block. "
        "Your PureDOOM.h may differ. Search for 'int I_StartSound' and insert:\n"
        "    DoomBridge_PushSfxEvent(id, vol, sep, pitch, priority);\n"
        "immediately after the opening brace."
    )

text = text.replace(old, new, 1)
dst.write_text(text, encoding="latin-1")
print(f"Wrote {dst}")
