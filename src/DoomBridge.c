// DoomBridge.c
// PureDOOM -> MetaTrader 5 DLL bridge.
// Build with MSYS2 CLANG64: mingw32-make
// Put PureDOOM.h in this same directory before building.

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <setjmp.h>

#ifndef DOOMBRIDGE_API
#define DOOMBRIDGE_API __declspec(dllexport)
#endif

#if defined(_WIN64)
#define DOOMBRIDGE_CALL __stdcall
#else
#define DOOMBRIDGE_CALL __stdcall
#endif

#define DOOMBRIDGE_SCREEN_W 320
#define DOOMBRIDGE_SCREEN_H 200
#define DOOMBRIDGE_SFX_QUEUE_SIZE 256

// -----------------------------------------------------------------------------
// SFX event queue. The optional PureDOOM_SfxHooked.h patch calls
// DoomBridge_PushSfxEvent() from I_StartSound(). Without the patch, the exported
// DoomPollSfxEvents() simply returns zero events.
// -----------------------------------------------------------------------------
typedef struct DoomBridgeSfxEvent
{
    int id;
    int volume;
    int sep;
    int pitch;
    int priority;
} DoomBridgeSfxEvent;

static DoomBridgeSfxEvent g_sfx_queue[DOOMBRIDGE_SFX_QUEUE_SIZE];
static int g_sfx_read = 0;
static int g_sfx_write = 0;

static void DoomBridge_ResetSfxQueue(void)
{
    g_sfx_read = 0;
    g_sfx_write = 0;
}

void DoomBridge_PushSfxEvent(int id, int volume, int sep, int pitch, int priority)
{
    int next = (g_sfx_write + 1) % DOOMBRIDGE_SFX_QUEUE_SIZE;

    if (next == g_sfx_read)
        return; // full: drop

    g_sfx_queue[g_sfx_write].id = id;
    g_sfx_queue[g_sfx_write].volume = volume;
    g_sfx_queue[g_sfx_write].sep = sep;
    g_sfx_queue[g_sfx_write].pitch = pitch;
    g_sfx_queue[g_sfx_write].priority = priority;
    g_sfx_write = next;
}

// -----------------------------------------------------------------------------
// PureDOOM implementation.
// We use PureDOOM's default malloc/file/time/getenv implementations.
// We deliberately do not use its default exit() implementation; instead we
// set a custom callback using doom_set_exit() so errors do not terminate MT5.
// -----------------------------------------------------------------------------
#define DOOM_IMPLEMENTATION
#define DOOM_IMPLEMENT_MALLOC
#define DOOM_IMPLEMENT_FILE_IO
#define DOOM_IMPLEMENT_GETTIME
#define DOOM_IMPLEMENT_GETENV
#define DOOM_WIN32 1
#define WIN32 1

#if defined(__has_include)
#  if __has_include("PureDOOM_SfxHooked.h")
#    include "PureDOOM_SfxHooked.h"
#  else
#    include "PureDOOM.h"
#  endif
#else
#  include "PureDOOM.h"
#endif



static int g_initialized = 0;
static int g_started_once = 0;
static char g_last_error[1024];
static char g_wad_path[MAX_PATH * 4];
static char g_wad_dir[MAX_PATH * 4];
static char g_wad_base[MAX_PATH * 4];
static char g_target_iwad_name[64];
static jmp_buf g_exit_jmp;
static int g_jmp_active = 0;

static const char *BridgeBaseName(const char *path);

static void *BridgeOpen(const char *filename, const char *mode)
{
    FILE *f;
    const char *base;

    f = fopen(filename, mode);
    if (f)
        return f;

    base = BridgeBaseName(filename);

    if (g_wad_path[0] != '\0' && g_target_iwad_name[0] != '\0' && _stricmp(base, g_target_iwad_name) == 0)
    {
        return fopen(g_wad_path, mode);
    }

    return NULL;
}

static void BridgeClose(void *handle)
{
    if (handle)
        fclose((FILE *)handle);
}

static int BridgeRead(void *handle, void *buf, int count)
{
    if (!handle)
        return -1;
    return (int)fread(buf, 1, (size_t)count, (FILE *)handle);
}

static int BridgeWrite(void *handle, const void *buf, int count)
{
    if (!handle)
        return -1;
    return (int)fwrite(buf, 1, (size_t)count, (FILE *)handle);
}

static int BridgeSeek(void *handle, int offset, doom_seek_t origin)
{
    if (!handle)
        return -1;
    return fseek((FILE *)handle, offset, (int)origin);
}

static int BridgeTell(void *handle)
{
    if (!handle)
        return -1;
    return (int)ftell((FILE *)handle);
}

static int BridgeEof(void *handle)
{
    if (!handle)
        return 1;
    return feof((FILE *)handle);
}

static char *BridgeGetEnv(const char *var)
{
    static char dot[] = ".";

    if (!var)
        return NULL;

    if (_stricmp(var, "DOOMWADDIR") == 0)
        return g_wad_dir[0] ? g_wad_dir : dot;

    if (_stricmp(var, "HOME") == 0)
        return dot;

    return getenv(var);
}


static void BridgeSetError(const char *msg)
{
    if (!msg)
        msg = "";

    strncpy(g_last_error, msg, sizeof(g_last_error) - 1);
    g_last_error[sizeof(g_last_error) - 1] = '\0';
}

static void BridgePrint(const char *str)
{
    if (str)
        OutputDebugStringA(str);
}

static void BridgeExit(int code)
{
    char buf[128];
    snprintf(buf, sizeof(buf), "PureDOOM requested exit: code=%d", code);
    BridgeSetError(buf);

    if (g_jmp_active)
        longjmp(g_exit_jmp, code == 0 ? 1 : code);
}

static int WideToAnsiPath(const wchar_t *w, char *out, int out_size)
{
    if (!w || !out || out_size <= 0)
        return 0;

    int n = WideCharToMultiByte(CP_ACP, 0, w, -1, out, out_size, NULL, NULL);
    if (n <= 0 || n >= out_size)
    {
        out[0] = '\0';
        return 0;
    }

    return 1;
}

static const char *BridgeBaseName(const char *path)
{
    const char *a;
    const char *b;
    const char *p;

    if (!path)
        return "";

    a = strrchr(path, '\\');
    b = strrchr(path, '/');
    p = a > b ? a : b;
    return p ? p + 1 : path;
}

static void BridgeSplitPath(const char *path)
{
    const char *base;
    size_t dir_len;

    g_wad_dir[0] = '\0';
    g_wad_base[0] = '\0';
    g_target_iwad_name[0] = '\0';

    if (!path || path[0] == '\0')
        return;

    base = BridgeBaseName(path);
    strncpy(g_wad_base, base, sizeof(g_wad_base) - 1);
    g_wad_base[sizeof(g_wad_base) - 1] = '\0';

    dir_len = (size_t)(base - path);
    if (dir_len > 0 && dir_len < sizeof(g_wad_dir))
    {
        memcpy(g_wad_dir, path, dir_len);
        g_wad_dir[dir_len] = '\0';

        // Remove trailing slash/backslash because PureDOOM appends /doom2.wad.
        while (dir_len > 0 && (g_wad_dir[dir_len - 1] == '\\' || g_wad_dir[dir_len - 1] == '/'))
        {
            g_wad_dir[dir_len - 1] = '\0';
            dir_len--;
        }
    }
    else
    {
        strcpy(g_wad_dir, ".");
    }

    // PureDOOM's original IWAD detection does not know freedoom1.wad/freedoom2.wad
    // and does not use -iwad.  It searches DOOMWADDIR for canonical names.
    // Redirect only the matching canonical candidate to the user-supplied WAD.
    if (_stricmp(g_wad_base, "freedoom2.wad") == 0)
        strcpy(g_target_iwad_name, "doom2.wad");
    else if (_stricmp(g_wad_base, "doom2.wad") == 0)
        strcpy(g_target_iwad_name, "doom2.wad");
    else if (_stricmp(g_wad_base, "doom1.wad") == 0)
        strcpy(g_target_iwad_name, "doom1.wad");
    else if (_stricmp(g_wad_base, "doom.wad") == 0)
        strcpy(g_target_iwad_name, "doom.wad");
    else if (_stricmp(g_wad_base, "doomu.wad") == 0 || _stricmp(g_wad_base, "freedoom1.wad") == 0)
        strcpy(g_target_iwad_name, "doomu.wad");
    else if (_stricmp(g_wad_base, "plutonia.wad") == 0)
        strcpy(g_target_iwad_name, "plutonia.wad");
    else if (_stricmp(g_wad_base, "tnt.wad") == 0)
        strcpy(g_target_iwad_name, "tnt.wad");
    else
        strcpy(g_target_iwad_name, "doom2.wad"); // best effort for custom Doom II-compatible IWADs
}

static uint32_t RgbaBytesToArgbUint(const unsigned char *p)
{
    uint32_t r = (uint32_t)p[0];
    uint32_t g = (uint32_t)p[1];
    uint32_t b = (uint32_t)p[2];
    uint32_t a = (uint32_t)p[3];
    return (a << 24) | (r << 16) | (g << 8) | b;
}

#ifdef __cplusplus
extern "C" {
#endif

DOOMBRIDGE_API int DOOMBRIDGE_CALL DoomInitW(const wchar_t *wadPath)
{
    BridgeSetError("");
    DoomBridge_ResetSfxQueue();

    if (g_started_once)
    {
        // PureDOOM does not expose a full shutdown/reinit API. If MT5 detaches
        // and reattaches the EA while the DLL is still loaded, resume the same
        // engine instance instead of calling doom_init() again.
        g_initialized = 1;
        return 1;
    }

    if (!WideToAnsiPath(wadPath, g_wad_path, (int)sizeof(g_wad_path)))
    {
        BridgeSetError("Failed to convert WAD path. Use an ASCII-only path first.");
        return 0;
    }

    BridgeSplitPath(g_wad_path);

    DWORD attrs = GetFileAttributesA(g_wad_path);
    if (attrs == INVALID_FILE_ATTRIBUTES || (attrs & FILE_ATTRIBUTE_DIRECTORY))
    {
        BridgeSetError("WAD file was not found.");
        return 0;
    }

    doom_set_print(BridgePrint);
    doom_set_exit(BridgeExit);
    doom_set_getenv(BridgeGetEnv);
    doom_set_file_io(BridgeOpen, BridgeClose, BridgeRead, BridgeWrite, BridgeSeek, BridgeTell, BridgeEof);

    char *argv[1];
    argv[0] = (char *)"puredoom-mt5";

    int flags = DOOM_FLAG_HIDE_MOUSE_OPTIONS |
                DOOM_FLAG_HIDE_SOUND_OPTIONS |
                DOOM_FLAG_HIDE_MUSIC_OPTIONS;

    g_jmp_active = 1;
    int jmp_code = setjmp(g_exit_jmp);
    if (jmp_code == 0)
    {
        doom_init(1, argv, flags);
        g_initialized = 1;
        g_started_once = 1;
        g_jmp_active = 0;
        return 1;
    }

    g_jmp_active = 0;
    if (g_last_error[0] == '\0')
        BridgeSetError("PureDOOM initialization failed.");
    return 0;
}

DOOMBRIDGE_API void DOOMBRIDGE_CALL DoomShutdown(void)
{
    // No full PureDOOM shutdown API exists. Keep the instance alive in the DLL.
    // Reattaching the EA can resume it without calling doom_init() again.
    g_initialized = 0;
}

DOOMBRIDGE_API int DOOMBRIDGE_CALL DoomGetScreenWidth(void)
{
    return DOOMBRIDGE_SCREEN_W;
}

DOOMBRIDGE_API int DOOMBRIDGE_CALL DoomGetScreenHeight(void)
{
    return DOOMBRIDGE_SCREEN_H;
}

DOOMBRIDGE_API int DOOMBRIDGE_CALL DoomGetFramebuffer(uint32_t *out_pixels, int bufLen)
{
    if (!g_initialized || !out_pixels)
        return 0;

    const int total = DOOMBRIDGE_SCREEN_W * DOOMBRIDGE_SCREEN_H;
    if (bufLen < total)
        return 0;

    g_jmp_active = 1;
    int jmp_code = setjmp(g_exit_jmp);
    if (jmp_code != 0)
    {
        g_jmp_active = 0;
        g_initialized = 0;
        return 0;
    }

    doom_update();
    const unsigned char *fb = doom_get_framebuffer(4); // RGBA bytes
    g_jmp_active = 0;

    if (!fb)
        return 0;

    for (int i = 0; i < total; ++i)
        out_pixels[i] = RgbaBytesToArgbUint(fb + i * 4);

    return 1;
}

DOOMBRIDGE_API void DOOMBRIDGE_CALL DoomKeyDown(int doomKey)
{
    if (!g_initialized)
        return;
    doom_key_down((doom_key_t)doomKey);
}

DOOMBRIDGE_API void DOOMBRIDGE_CALL DoomKeyUp(int doomKey)
{
    if (!g_initialized)
        return;
    doom_key_up((doom_key_t)doomKey);
}

DOOMBRIDGE_API int DOOMBRIDGE_CALL DoomPollSfxEvents(int *out_ids, int *out_volumes, int max_events)
{
    if (!out_ids || !out_volumes || max_events <= 0)
        return 0;

    int count = 0;
    while (g_sfx_read != g_sfx_write && count < max_events)
    {
        out_ids[count] = g_sfx_queue[g_sfx_read].id;
        out_volumes[count] = g_sfx_queue[g_sfx_read].volume;
        g_sfx_read = (g_sfx_read + 1) % DOOMBRIDGE_SFX_QUEUE_SIZE;
        ++count;
    }
    return count;
}

DOOMBRIDGE_API int DOOMBRIDGE_CALL DoomPollSfxEventsEx(
    int *out_ids,
    int *out_volumes,
    int *out_seps,
    int *out_pitches,
    int *out_priorities,
    int max_events)
{
    if (!out_ids || !out_volumes || !out_seps || !out_pitches || !out_priorities || max_events <= 0)
        return 0;

    int count = 0;
    while (g_sfx_read != g_sfx_write && count < max_events)
    {
        out_ids[count] = g_sfx_queue[g_sfx_read].id;
        out_volumes[count] = g_sfx_queue[g_sfx_read].volume;
        out_seps[count] = g_sfx_queue[g_sfx_read].sep;
        out_pitches[count] = g_sfx_queue[g_sfx_read].pitch;
        out_priorities[count] = g_sfx_queue[g_sfx_read].priority;
        g_sfx_read = (g_sfx_read + 1) % DOOMBRIDGE_SFX_QUEUE_SIZE;
        ++count;
    }
    return count;
}

DOOMBRIDGE_API int DOOMBRIDGE_CALL DoomGetLastErrorTextW(wchar_t *out_text, int max_chars)
{
    if (!out_text || max_chars <= 0)
        return 0;

    int n = MultiByteToWideChar(CP_ACP, 0, g_last_error, -1, out_text, max_chars);
    if (n <= 0)
    {
        out_text[0] = 0;
        return 0;
    }
    return 1;
}

#ifdef __cplusplus
}
#endif

BOOL WINAPI DllMain(HINSTANCE hinst, DWORD reason, LPVOID reserved)
{
    (void)hinst;
    (void)reason;
    (void)reserved;
    return TRUE;
}
