//+------------------------------------------------------------------+
//|                         DoomBridgeEA_AllInOneFolder.mq5          |
//|   Project folder layout:                                         |
//|                                                                  |
//|   MQL5\Experts\DoomProject\                                     |
//|     DoomBridgeEA_AllInOneFolder.mq5                              |
//|     DoomBridge.ex5                                               |
//|     DoomBridge.dll                                               |
//|     freedoom2.wad                                                |
//|     sfx\                                                        |
//|       pistol.wav                                                 |
//|       shotgn.wav                                                 |
//|       doropn.wav                                                 |
//|       ...                                                        |
//+------------------------------------------------------------------+
#property strict
#property version "1.20"

#import "DoomBridge.dll"
int  DoomInitW(string wadPath);
void DoomShutdown();
int  DoomGetFramebuffer(uint &buf[], int bufLen);
int  DoomGetScreenWidth();
int  DoomGetScreenHeight();
void DoomKeyDown(int doomKey);
void DoomKeyUp(int doomKey);
int  DoomPollSfxEvents(int &ids[], int &volumes[], int maxEvents);
int  DoomGetLastErrorTextW(ushort &outText[], int maxChars);
#import

#import "user32.dll"
short GetAsyncKeyState(int vKey);
#import

#import "winmm.dll"
uint mciSendStringW(string command, ushort &ret[], uint retLen, long hwndCallback);
bool mciGetErrorStringW(uint err, ushort &text[], uint len);
#import

// ------------------------- Inputs ---------------------------------

input string ProjectPath         = "";              
input string ProjectFolder       = "DoomProject";   

input string WADFile             = "freedoom2.wad";
input string SfxFolder           = "sfx";

input int    TargetFPS           = 15;
input int    DisplayScale        = 3;
input int    XOffset             = 10;
input int    YOffset             = 20;
input bool   HideChart           = true;

input bool   EnableSound         = true;
input int    MaxSfxEventsPerTick = 64;
input bool   PrintSfxEvents      = false;
input bool   PrintUnknownSfx     = false;

// ------------------------- Display constants -----------------------

#define OBJ_NAME "DoomBridgeScreen"
#define RES_NAME "::DoomBridgeFramebuffer"

// ------------------------- SFX constants ---------------------------

#define MAX_SOUND_SLOTS 20
#define MAX_SFX_EVENTS  128

// ------------------------- DOOM key codes --------------------------

#define DOOM_KEY_TAB          9
#define DOOM_KEY_ENTER        13
#define DOOM_KEY_ESCAPE       27
#define DOOM_KEY_SPACE        32
#define DOOM_KEY_COMMA        44
#define DOOM_KEY_MINUS        0x2D
#define DOOM_KEY_PERIOD       46
#define DOOM_KEY_0            '0'
#define DOOM_KEY_1            '1'
#define DOOM_KEY_2            '2'
#define DOOM_KEY_3            '3'
#define DOOM_KEY_4            '4'
#define DOOM_KEY_5            '5'
#define DOOM_KEY_6            '6'
#define DOOM_KEY_7            '7'
#define DOOM_KEY_8            '8'
#define DOOM_KEY_9            '9'
#define DOOM_KEY_EQUALS       0x3D
#define DOOM_KEY_A            'a'
#define DOOM_KEY_B            'b'
#define DOOM_KEY_C            'c'
#define DOOM_KEY_D            'd'
#define DOOM_KEY_E            'e'
#define DOOM_KEY_F            'f'
#define DOOM_KEY_G            'g'
#define DOOM_KEY_H            'h'
#define DOOM_KEY_I            'i'
#define DOOM_KEY_J            'j'
#define DOOM_KEY_K            'k'
#define DOOM_KEY_L            'l'
#define DOOM_KEY_M            'm'
#define DOOM_KEY_N            'n'
#define DOOM_KEY_O            'o'
#define DOOM_KEY_P            'p'
#define DOOM_KEY_Q            'q'
#define DOOM_KEY_R            'r'
#define DOOM_KEY_S            's'
#define DOOM_KEY_T            't'
#define DOOM_KEY_U            'u'
#define DOOM_KEY_V            'v'
#define DOOM_KEY_W            'w'
#define DOOM_KEY_X            'x'
#define DOOM_KEY_Y            'y'
#define DOOM_KEY_Z            'z'
#define DOOM_KEY_BACKSPACE    127
#define DOOM_KEY_CTRL         (0x80+0x1D)
#define DOOM_KEY_LEFT_ARROW   0xAC
#define DOOM_KEY_UP_ARROW     0xAD
#define DOOM_KEY_RIGHT_ARROW  0xAE
#define DOOM_KEY_DOWN_ARROW   0xAF
#define DOOM_KEY_SHIFT        (0x80+0x36)
#define DOOM_KEY_ALT          (0x80+0x38)
#define DOOM_KEY_F1           (0x80+0x3B)
#define DOOM_KEY_F2           (0x80+0x3C)
#define DOOM_KEY_F3           (0x80+0x3D)
#define DOOM_KEY_F4           (0x80+0x3E)
#define DOOM_KEY_F5           (0x80+0x3F)
#define DOOM_KEY_F6           (0x80+0x40)
#define DOOM_KEY_F7           (0x80+0x41)
#define DOOM_KEY_F8           (0x80+0x42)
#define DOOM_KEY_F9           (0x80+0x43)
#define DOOM_KEY_F10          (0x80+0x44)
#define DOOM_KEY_F11          (0x80+0x57)
#define DOOM_KEY_F12          (0x80+0x58)
#define DOOM_KEY_PAUSE        0xFF
#define DOOM_KEY_UNKNOWN      (-1)

// ------------------------- VK codes --------------------------------

#define VK_BACK       0x08
#define VK_TAB        0x09
#define VK_RETURN     0x0D
#define VK_SHIFT      0x10
#define VK_CONTROL    0x11
#define VK_MENU       0x12
#define VK_PAUSE      0x13
#define VK_ESCAPE     0x1B
#define VK_SPACE      0x20
#define VK_LEFT       0x25
#define VK_UP         0x26
#define VK_RIGHT      0x27
#define VK_DOWN       0x28
#define VK_0          0x30
#define VK_9          0x39
#define VK_A          0x41
#define VK_Z          0x5A
#define VK_F1         0x70
#define VK_F12        0x7B
#define VK_OEM_COMMA  0xBC
#define VK_OEM_MINUS  0xBD
#define VK_OEM_PERIOD 0xBE
#define VK_OEM_PLUS   0xBB

// ------------------------- Global display state --------------------

int  g_srcW = 0;
int  g_srcH = 0;
int  g_srcPixels = 0;
int  g_dstW = 0;
int  g_dstH = 0;
uint g_src[];
uint g_dst[];
bool g_initialized = false;

// ------------------------- Key state -------------------------------

struct KeyMapping
{
   int vk;
   int doomKey;
};

KeyMapping g_keymap[];
bool       g_keyStates[];

// ------------------------- Sound state -----------------------------

struct SoundSlot
{
   string alias;
   bool   busy;
   string file;
};

SoundSlot g_slots[MAX_SOUND_SLOTS];
string    g_projectRoot;
string    g_wadPath;
string    g_soundBase;
int       g_played = 0;
int       g_dropped = 0;

int g_sfxIds[MAX_SFX_EVENTS];
int g_sfxVolumes[MAX_SFX_EVENTS];

// ------------------------- Path utility ----------------------------

string NormalizeDir(string p)
{
   StringReplace(p, "/", "\\");
   if(StringLen(p) > 0 && StringSubstr(p, StringLen(p) - 1, 1) != "\\")
      p += "\\";
   return p;
}

string DefaultProjectRoot()
{
   return NormalizeDir(
      TerminalInfoString(TERMINAL_DATA_PATH)
      + "\\MQL5\\Experts\\"
      + ProjectFolder
   );
}

string ResolveProjectRoot()
{
   if(ProjectPath != "")
      return NormalizeDir(ProjectPath);

   return DefaultProjectRoot();
}

// ------------------------- Utility ---------------------------------

string UShortBufferToString(ushort &buf[])
{
   int n = ArraySize(buf);
   int len = 0;

   while(len < n && buf[len] != 0)
      len++;

   if(len <= 0)
      return "";

   return ShortArrayToString(buf, 0, len);
}

string GetBridgeError()
{
   ushort buf[];
   ArrayResize(buf, 512);
   ArrayInitialize(buf, 0);

   if(DoomGetLastErrorTextW(buf, 512) == 0)
      return "";

   return UShortBufferToString(buf);
}

string MciErrorText(uint err)
{
   if(err == 0)
      return "OK";

   ushort buf[];
   ArrayResize(buf, 512);
   ArrayInitialize(buf, 0);

   if(!mciGetErrorStringW(err, buf, 512))
      return "MCI error " + IntegerToString((int)err);

   string msg = UShortBufferToString(buf);
   if(msg == "")
      msg = "MCI error " + IntegerToString((int)err);

   return msg;
}

bool MciCommand(string cmd, bool verbose = false)
{
   ushort ret[];
   ArrayResize(ret, 1);
   ret[0] = 0;

   uint err = mciSendStringW(cmd, ret, 0, 0);

   if(verbose)
   {
      if(err == 0)
         Print("[MCI OK] ", cmd);
      else
         Print("[MCI ERR] ", cmd, " | ", MciErrorText(err), " | code=", err);
   }

   return (err == 0);
}

string MciQuery(string cmd)
{
   ushort ret[];
   ArrayResize(ret, 256);
   ArrayInitialize(ret, 0);

   uint err = mciSendStringW(cmd, ret, 256, 0);

   if(err != 0)
      return "";

   return UShortBufferToString(ret);
}

// ------------------------- Sound manager ---------------------------

void Sound_CloseSlot(int slot)
{
   if(slot < 0 || slot >= MAX_SOUND_SLOTS)
      return;

   MciCommand("stop " + g_slots[slot].alias, false);
   MciCommand("close " + g_slots[slot].alias, false);

   g_slots[slot].busy = false;
   g_slots[slot].file = "";
}

void Sound_UpdateSlots()
{
   for(int i = 0; i < MAX_SOUND_SLOTS; i++)
   {
      if(!g_slots[i].busy)
         continue;

      string mode = MciQuery("status " + g_slots[i].alias + " mode");

      if(mode != "playing")
         Sound_CloseSlot(i);
   }
}

int Sound_FindFreeSlot()
{
   for(int i = 0; i < MAX_SOUND_SLOTS; i++)
   {
      if(!g_slots[i].busy)
         return i;
   }

   return -1;
}

void Sound_Init()
{
   g_soundBase = NormalizeDir(g_projectRoot + SfxFolder);

   Print("Project root: ", g_projectRoot);
   Print("WAD path: ", g_wadPath);
   Print("Sound folder: ", g_soundBase);

   for(int i = 0; i < MAX_SOUND_SLOTS; i++)
   {
      g_slots[i].alias = "doomSfx" + IntegerToString(i);
      g_slots[i].busy = false;
      g_slots[i].file = "";
      Sound_CloseSlot(i);
   }
}

void Sound_Shutdown()
{
   for(int i = 0; i < MAX_SOUND_SLOTS; i++)
      Sound_CloseSlot(i);

   Print("Sound stopped. played=", g_played, " dropped=", g_dropped);
}

bool Sound_PlayWav(string wavName)
{
   if(!EnableSound || wavName == "")
      return false;

   Sound_UpdateSlots();

   int slot = Sound_FindFreeSlot();

   if(slot < 0)
   {
      g_dropped++;
      if(PrintSfxEvents)
         Print("SFX drop: no free slot. wav=", wavName, " dropped=", g_dropped);
      return false;
   }

   string fullPath = g_soundBase + wavName;
   string alias = g_slots[slot].alias;

   Sound_CloseSlot(slot);

   if(!MciCommand("open \"" + fullPath + "\" type waveaudio alias " + alias, true))
   {
      g_dropped++;
      Print("SFX open failed. wav=", fullPath);
      return false;
   }

   MciCommand("set " + alias + " time format milliseconds", false);

   if(!MciCommand("play " + alias + " from 0", false))
   {
      Sound_CloseSlot(slot);
      g_dropped++;
      Print("SFX play failed. wav=", fullPath);
      return false;
   }

   g_slots[slot].busy = true;
   g_slots[slot].file = fullPath;
   g_played++;

   if(PrintSfxEvents)
      Print("SFX play slot=", slot, " wav=", wavName, " played=", g_played, " dropped=", g_dropped);

   return true;
}

string DoomSfxIdToWav(int sfxId)
{
   switch(sfxId)
   {
      case 1: return "pistol.wav";
      case 2: return "shotgn.wav";
      case 3: return "sgcock.wav";
      case 4: return "dshtgn.wav";
      case 5: return "dbopn.wav";
      case 6: return "dbcls.wav";
      case 7: return "dbload.wav";
      case 8: return "plasma.wav";
      case 9: return "bfg.wav";
      case 10: return "sawup.wav";
      case 11: return "sawidl.wav";
      case 12: return "sawful.wav";
      case 13: return "sawhit.wav";
      case 14: return "rlaunc.wav";
      case 15: return "rxplod.wav";
      case 16: return "firsht.wav";
      case 17: return "firxpl.wav";
      case 18: return "pstart.wav";
      case 19: return "pstop.wav";
      case 20: return "doropn.wav";
      case 21: return "dorcls.wav";
      case 22: return "stnmov.wav";
      case 23: return "swtchn.wav";
      case 24: return "swtchx.wav";
      case 25: return "plpain.wav";
      case 26: return "dmpain.wav";
      case 27: return "popain.wav";
      case 28: return "vipain.wav";
      case 29: return "mnpain.wav";
      case 30: return "pepain.wav";
      case 31: return "slop.wav";
      case 32: return "itemup.wav";
      case 33: return "wpnup.wav";
      case 34: return "oof.wav";
      case 35: return "telept.wav";
      case 36: return "posit1.wav";
      case 37: return "posit2.wav";
      case 38: return "posit3.wav";
      case 39: return "bgsit1.wav";
      case 40: return "bgsit2.wav";
      case 41: return "sgtsit.wav";
      case 42: return "cacsit.wav";
      case 43: return "brssit.wav";
      case 44: return "cybsit.wav";
      case 45: return "spisit.wav";
      case 46: return "bspsit.wav";
      case 47: return "kntsit.wav";
      case 48: return "vilsit.wav";
      case 49: return "mansit.wav";
      case 50: return "pesit.wav";
      case 51: return "sklatk.wav";
      case 52: return "sgtatk.wav";
      case 53: return "skepch.wav";
      case 54: return "vilatk.wav";
      case 55: return "claw.wav";
      case 56: return "skeswg.wav";
      case 57: return "pldeth.wav";
      case 58: return "pdiehi.wav";
      case 59: return "podth1.wav";
      case 60: return "podth2.wav";
      case 61: return "podth3.wav";
      case 62: return "bgdth1.wav";
      case 63: return "bgdth2.wav";
      case 64: return "sgtdth.wav";
      case 65: return "cacdth.wav";
      case 66: return "skldth.wav";
      case 67: return "brsdth.wav";
      case 68: return "cybdth.wav";
      case 69: return "spidth.wav";
      case 70: return "bspdth.wav";
      case 71: return "vildth.wav";
      case 72: return "kntdth.wav";
      case 73: return "pedth.wav";
      case 74: return "skedth.wav";
      case 75: return "posact.wav";
      case 76: return "bgact.wav";
      case 77: return "dmact.wav";
      case 78: return "bspact.wav";
      case 79: return "bspwlk.wav";
      case 80: return "vilact.wav";
      case 81: return "noway.wav";
      case 82: return "barexp.wav";
      case 83: return "punch.wav";
      case 84: return "hoof.wav";
      case 85: return "metal.wav";
      case 86: return "chgun.wav";
      case 87: return "tink.wav";
      case 88: return "bdopn.wav";
      case 89: return "bdcls.wav";
      case 90: return "itmbk.wav";
      case 91: return "flame.wav";
      case 92: return "flamst.wav";
      case 93: return "getpow.wav";
      case 94: return "bospit.wav";
      case 95: return "boscub.wav";
      case 96: return "bossit.wav";
      case 97: return "bospn.wav";
      case 98: return "bosdth.wav";
      case 99: return "manatk.wav";
      case 100: return "mandth.wav";
      case 101: return "sssit.wav";
      case 102: return "ssdth.wav";
      case 103: return "keenpn.wav";
      case 104: return "keendt.wav";
      case 105: return "skeact.wav";
      case 106: return "skesit.wav";
      case 107: return "skeatk.wav";
      case 108: return "radio.wav";
   }

   return "";
}

void Sound_PlaySfxId(int sfxId, int volume)
{
   string wav = DoomSfxIdToWav(sfxId);

   if(wav == "")
   {
      if(PrintUnknownSfx)
         Print("Unknown SFX id=", sfxId, " volume=", volume);
      return;
   }

   if(PrintSfxEvents)
      Print("SFX event id=", sfxId, " volume=", volume, " wav=", wav);

   Sound_PlayWav(wav);
}

void PollDoomSfx()
{
   if(!EnableSound)
      return;

   int maxEvents = MathMin(MaxSfxEventsPerTick, MAX_SFX_EVENTS);
   int n = DoomPollSfxEvents(g_sfxIds, g_sfxVolumes, maxEvents);

   for(int i = 0; i < n; i++)
      Sound_PlaySfxId(g_sfxIds[i], g_sfxVolumes[i]);
}

// ------------------------- Key input -------------------------------

void BuildKeyMap()
{
   int count = 0;
   ArrayResize(g_keymap, 90);
   ArrayResize(g_keyStates, 90);

   for(int vk = VK_A; vk <= VK_Z; vk++)
   {
      g_keymap[count].vk = vk;
      g_keymap[count].doomKey = 'a' + (vk - VK_A);
      g_keyStates[count] = false;
      count++;
   }

   for(int vk = VK_0; vk <= VK_9; vk++)
   {
      g_keymap[count].vk = vk;
      g_keymap[count].doomKey = '0' + (vk - VK_0);
      g_keyStates[count] = false;
      count++;
   }

   for(int i = 0; i < 12; i++)
   {
      g_keymap[count].vk = VK_F1 + i;
      g_keymap[count].doomKey = DOOM_KEY_F1 + i;
      g_keyStates[count] = false;
      count++;
   }

   int specials[][2] =
   {
      { VK_RETURN,     DOOM_KEY_ENTER },
      { VK_ESCAPE,     DOOM_KEY_ESCAPE },
      { VK_SPACE,      DOOM_KEY_SPACE },
      { VK_TAB,        DOOM_KEY_TAB },
      { VK_BACK,       DOOM_KEY_BACKSPACE },
      { VK_CONTROL,    DOOM_KEY_CTRL },
      { VK_SHIFT,      DOOM_KEY_SHIFT },
      { VK_MENU,       DOOM_KEY_ALT },
      { VK_LEFT,       DOOM_KEY_LEFT_ARROW },
      { VK_UP,         DOOM_KEY_UP_ARROW },
      { VK_RIGHT,      DOOM_KEY_RIGHT_ARROW },
      { VK_DOWN,       DOOM_KEY_DOWN_ARROW },
      { VK_PAUSE,      DOOM_KEY_PAUSE },
      { VK_OEM_COMMA,  DOOM_KEY_COMMA },
      { VK_OEM_MINUS,  DOOM_KEY_MINUS },
      { VK_OEM_PERIOD, DOOM_KEY_PERIOD },
      { VK_OEM_PLUS,   DOOM_KEY_EQUALS }
   };

   int numSpecials = ArrayRange(specials, 0);

   for(int i = 0; i < numSpecials; i++)
   {
      g_keymap[count].vk = specials[i][0];
      g_keymap[count].doomKey = specials[i][1];
      g_keyStates[count] = false;
      count++;
   }

   ArrayResize(g_keymap, count);
   ArrayResize(g_keyStates, count);
}

int VkToDoomKey(int vk)
{
   int count = ArraySize(g_keymap);

   for(int i = 0; i < count; i++)
   {
      if(g_keymap[i].vk == vk)
         return g_keymap[i].doomKey;
   }

   return DOOM_KEY_UNKNOWN;
}

int FindKeyIndex(int vk)
{
   int count = ArraySize(g_keymap);

   for(int i = 0; i < count; i++)
   {
      if(g_keymap[i].vk == vk)
         return i;
   }

   return -1;
}

void PollKeyStates()
{
   int count = ArraySize(g_keymap);

   for(int i = 0; i < count; i++)
   {
      short state = GetAsyncKeyState(g_keymap[i].vk);
      bool isDown = ((state & 0x8000) != 0);

      if(g_keyStates[i] && !isDown)
      {
         DoomKeyUp(g_keymap[i].doomKey);
         g_keyStates[i] = false;
      }
   }
}

// ------------------------- Display ---------------------------------

void SetupChart()
{
   if(HideChart)
      ChartSetInteger(0, CHART_SHOW, false);

   ChartSetInteger(0, CHART_KEYBOARD_CONTROL, false);
}

void RestoreChart()
{
   if(HideChart)
      ChartSetInteger(0, CHART_SHOW, true);
}

void ScaleFramebuffer()
{
   int scale = MathMax(1, DisplayScale);

   if(scale == 1)
   {
      ArrayCopy(g_dst, g_src, 0, 0, g_srcPixels);
      return;
   }

   for(int y = 0; y < g_srcH; y++)
   {
      for(int sy = 0; sy < scale; sy++)
      {
         int dstY = y * scale + sy;
         int dstRow = dstY * g_dstW;
         int srcRow = y * g_srcW;

         for(int x = 0; x < g_srcW; x++)
         {
            uint c = g_src[srcRow + x];
            int dstX = x * scale;

            for(int sx = 0; sx < scale; sx++)
               g_dst[dstRow + dstX + sx] = c;
         }
      }
   }
}

bool CreateDisplay()
{
   int scale = MathMax(1, DisplayScale);

   g_dstW = g_srcW * scale;
   g_dstH = g_srcH * scale;

   ArrayResize(g_src, g_srcPixels);
   ArrayResize(g_dst, g_dstW * g_dstH);

   ArrayInitialize(g_src, 0xFF000000);
   ArrayInitialize(g_dst, 0xFF000000);

   ObjectDelete(0, OBJ_NAME);
   ResourceFree(RES_NAME);

   if(!ResourceCreate(RES_NAME, g_dst, g_dstW, g_dstH, 0, 0, g_dstW, COLOR_FORMAT_ARGB_NORMALIZE))
   {
      Print("ResourceCreate init failed. error=", GetLastError());
      return false;
   }

   if(!ObjectCreate(0, OBJ_NAME, OBJ_BITMAP_LABEL, 0, 0, 0))
   {
      Print("ObjectCreate failed. error=", GetLastError());
      return false;
   }

   ObjectSetInteger(0, OBJ_NAME, OBJPROP_XDISTANCE, XOffset);
   ObjectSetInteger(0, OBJ_NAME, OBJPROP_YDISTANCE, YOffset);
   ObjectSetInteger(0, OBJ_NAME, OBJPROP_XSIZE, g_dstW);
   ObjectSetInteger(0, OBJ_NAME, OBJPROP_YSIZE, g_dstH);
   ObjectSetString(0, OBJ_NAME, OBJPROP_BMPFILE, RES_NAME);
   ObjectSetInteger(0, OBJ_NAME, OBJPROP_BACK, false);

   ChartRedraw(0);
   return true;
}

// ------------------------- EA lifecycle ----------------------------

int OnInit()
{
   g_projectRoot = ResolveProjectRoot();
   g_wadPath = g_projectRoot + WADFile;

   BuildKeyMap();
   SetupChart();

   Print("Project root: ", g_projectRoot);
   Print("Expected DLL path: ", g_projectRoot, "DoomBridge.dll");
   Print("WAD path: ", g_wadPath);
   Print("SFX path: ", NormalizeDir(g_projectRoot + SfxFolder));

   if(DoomInitW(g_wadPath) == 0)
   {
      Print("DoomInitW failed: ", GetBridgeError());
      RestoreChart();
      return INIT_FAILED;
   }

   g_srcW = DoomGetScreenWidth();
   g_srcH = DoomGetScreenHeight();
   g_srcPixels = g_srcW * g_srcH;

   if(g_srcW <= 0 || g_srcH <= 0 || g_srcPixels <= 0)
   {
      Print("Invalid screen size: ", g_srcW, "x", g_srcH);
      RestoreChart();
      return INIT_FAILED;
   }

   if(!CreateDisplay())
   {
      RestoreChart();
      return INIT_FAILED;
   }

   Sound_Init();

   int timerMs = 1000 / MathMax(1, TargetFPS);

   if(!EventSetMillisecondTimer(timerMs))
   {
      Print("EventSetMillisecondTimer failed. error=", GetLastError());
      Sound_Shutdown();
      RestoreChart();
      return INIT_FAILED;
   }

   g_initialized = true;

   Print("DoomBridgeEA_AllInOneFolder initialized. src=", g_srcW, "x", g_srcH,
         " dst=", g_dstW, "x", g_dstH, " fps=", TargetFPS);

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();

   if(g_initialized)
   {
      DoomShutdown();
      g_initialized = false;
   }

   Sound_Shutdown();

   ObjectDelete(0, OBJ_NAME);
   ResourceFree(RES_NAME);

   RestoreChart();
   ChartRedraw(0);

   Print("DoomBridgeEA_AllInOneFolder stopped.");
}

void OnTimer()
{
   if(!g_initialized)
      return;

   PollKeyStates();
   Sound_UpdateSlots();

   if(DoomGetFramebuffer(g_src, g_srcPixels))
   {
      ScaleFramebuffer();
      ResourceCreate(RES_NAME, g_dst, g_dstW, g_dstH, 0, 0, g_dstW, COLOR_FORMAT_ARGB_NORMALIZE);
      ChartRedraw(0);
   }

   PollDoomSfx();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(!g_initialized)
      return;

   if(id == CHARTEVENT_KEYDOWN)
   {
      int vk = (int)lparam;
      int doomKey = VkToDoomKey(vk);

      if(doomKey != DOOM_KEY_UNKNOWN)
      {
         int idx = FindKeyIndex(vk);

         if(idx >= 0)
            g_keyStates[idx] = true;

         DoomKeyDown(doomKey);
      }
   }
}
