DoomBridge MT5 - Build Instructions / ビルド手順

===============================================================================
English
===============================================================================

Overview
--------

This package builds DoomBridge.dll, a Windows DLL that embeds PureDOOM and is
called from a MetaTrader 5 Expert Advisor.

The DLL is used for:

  - running the DOOM engine through PureDOOM;
  - loading a WAD file such as freedoom2.wad;
  - exposing the 320x200 framebuffer to MQL5;
  - exporting sound-effect events to MQL5;
  - letting the MQL5 side play extracted WAV files through MCI.

The typical runtime layout is:

  MQL5\Experts\DoomProject\
    DoomBridgeEA.mq5
    DoomBridge.ex5
    DoomBridge.dll
    freedoom2.wad
    sfx\
      pistol.wav
      shotgn.wav
      doropn.wav
      ...

Build requirements
------------------

Use the MSYS2 CLANG64 environment.

Required tools:

  - MSYS2 CLANG64
  - clang
  - mingw32-make
  - python

Example MSYS2 installation command:

  pacman -S --needed mingw-w64-clang-x86_64-clang mingw-w64-clang-x86_64-make python

Required source files
---------------------

The DoomBridge build directory should contain:

  DoomBridge.c
  PureDOOM.h
  patch_puredoom_sfx.py
  Makefile

If sound-effect event export is used, the build process generates:

  PureDOOM_SfxHooked.h

Do not remove this generated file if it is the file used by DoomBridge.c during
compilation.

Build steps
-----------

From MSYS2 CLANG64:

  cd /c/path/to/DoomBridge

If using the sound hook:

  python patch_puredoom_sfx.py

Then build:

  mingw32-make clean
  mingw32-make

The expected output is:

  DoomBridge.dll

Compiler flags
--------------

A conservative debug/stability build may use:

  CFLAGS=-O0 -g -Wall -std=gnu99 -fno-strict-aliasing -fwrapv

Meaning:

  -O0
    Disable optimization.

  -g
    Include debug information.

  -Wall
    Enable common compiler warnings.

  -std=gnu99
    Compile as C99 with GNU extensions.

  -fno-strict-aliasing
    Disable strict-aliasing based optimizations. This is safer for older C code
    and pointer-heavy code.

  -fwrapv
    Treat signed integer overflow in addition, subtraction, and multiplication
    as two's-complement wraparound. This is safer for old fixed-point game code
    that may rely on wraparound behavior.

Deployment
----------

Copy the built DLL and project files to:

  MQL5\Experts\DoomProject\
    DoomBridgeEA.mq5
    DoomBridge.ex5
    DoomBridge.dll
    freedoom2.wad
    sfx\*.wav

In MetaTrader 5:

  1. Open MetaEditor.
  2. Compile DoomBridgeEA.mq5.
  3. Enable DLL imports for the Expert Advisor.
  4. Attach the EA to a chart.

Notes
-----

Commercial DOOM IWAD files are not included. Users must provide their own legally
obtained copies if they want to use them.

Freedoom is the recommended redistributable WAD for this package.

===============================================================================
日本語
===============================================================================

概要
----

このパッケージは DoomBridge.dll をビルドします。

DoomBridge.dll は PureDOOM を組み込んだ Windows DLL で、MetaTrader 5 の
Expert Advisor から呼び出されます。

DLLの主な役割は以下です。

  - PureDOOMでDOOMエンジンを動かす
  - freedoom2.wad などのWADファイルを読み込む
  - 320x200のフレームバッファをMQL5側へ渡す
  - 効果音イベントをMQL5側へ渡す
  - MQL5側で、抽出済みWAVをMCI経由で鳴らせるようにする

実行時の基本構成は以下です。

  MQL5\Experts\DoomProject\
    DoomBridgeEA.mq5
    DoomBridge.ex5
    DoomBridge.dll
    freedoom2.wad
    sfx\
      pistol.wav
      shotgn.wav
      doropn.wav
      ...

必要なビルド環境
----------------

MSYS2 CLANG64 環境を使用します。

必要なツールは以下です。

  - MSYS2 CLANG64
  - clang
  - mingw32-make
  - python

MSYS2でのインストール例:

  pacman -S --needed mingw-w64-clang-x86_64-clang mingw-w64-clang-x86_64-make python

必要なソースファイル
--------------------

DoomBridge のビルド用フォルダには、少なくとも以下を置きます。

  DoomBridge.c
  PureDOOM.h
  patch_puredoom_sfx.py
  Makefile

効果音イベントのエクスポートを使う場合、ビルド前に以下が生成されます。

  PureDOOM_SfxHooked.h

DoomBridge.c がこの生成済みヘッダを使っている場合、このファイルも配布物に含めてください。

ビルド手順
----------

MSYS2 CLANG64 で以下を実行します。

  cd /c/path/to/DoomBridge

効果音フックを使う場合:

  python patch_puredoom_sfx.py

その後、ビルドします。

  mingw32-make clean
  mingw32-make

成功すると、以下が生成されます。

  DoomBridge.dll

コンパイラフラグ
----------------

安定確認用のビルドでは、以下のような設定を使えます。

  CFLAGS=-O0 -g -Wall -std=gnu99 -fno-strict-aliasing -fwrapv

意味は以下です。

  -O0
    最適化を無効にする。

  -g
    デバッグ情報を付ける。

  -Wall
    よく使われる警告を有効にする。

  -std=gnu99
    C99にGNU拡張を加えたモードでコンパイルする。

  -fno-strict-aliasing
    strict aliasing前提の最適化を無効にする。古いCコードやポインタ操作が多い
    コードでは安全側に寄せられる。

  -fwrapv
    signed int の加算・減算・乗算オーバーフローを2の補数ラップとして扱う。
    古い固定小数点ゲームコードで、整数の回り込みに依存している場合の安全策。

配置
----

ビルドしたDLLとプロジェクトファイルを以下に置きます。

  MQL5\Experts\DoomProject\
    DoomBridgeEA.mq5
    DoomBridge.ex5
    DoomBridge.dll
    freedoom2.wad
    sfx\*.wav

MetaTrader 5 側では以下を行います。

  1. MetaEditorを開く
  2. DoomBridgeEA.mq5 をコンパイルする
  3. EAのDLL使用を許可する
  4. EAをチャートに適用する

注意
----

商用DOOM IWADファイルは同梱しません。商用WADを使いたい場合は、ユーザーが
合法的に入手したファイルを自分で配置してください。

このパッケージで再配布するWADとしては、Freedoomを推奨します。
