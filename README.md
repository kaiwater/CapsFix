# CapsFix

**一个修 macOS「快速打字随机大小写 + 中文输入法被打断」的小工具。**
**A tiny macOS utility that fixes random letter case and broken Chinese IME input.**

> 这不是键盘坏了，也不是输入法坏了。是 macOS 在**按键交叠（rollover）**时，把
> Caps Lock 的 `AlphaShift` 标志位错误地写进了 key-down 事件。
>
> This is not a broken keyboard and not a broken IME. macOS sets the Caps Lock
> (`AlphaShift`) flag on key-down events during **key rollover**.

---

## 下载 / Download

预编译 **Universal 版（Intel + Apple Silicon）**见
[Releases](https://github.com/kaiwater/CapsFix/releases)。

1. 解压 `CapsFix-<version>-macOS-universal.zip`；
2. 双击 `install.command`（或手动把 `CapsFix.app` 放进 `~/Applications`）；
3. 若被 Gatekeeper 拦截：右键 → 打开，或执行
   `xattr -dr com.apple.quarantine CapsFix.app`；
4. 系统设置 → 隐私与安全性 → 辅助功能 → 添加 `CapsFix.app`；
5. 生效后日志 `~/Library/Logs/capsfix.log` 会出现 `TAP_OK`。

Prebuilt **universal binary (Intel + Apple Silicon)** is available under
[Releases](https://github.com/kaiwater/CapsFix/releases).

1. Unzip `CapsFix-<version>-macOS-universal.zip`;
2. Double-click `install.command` (or move `CapsFix.app` into `~/Applications`);
3. If Gatekeeper blocks it: right-click → Open, or run
   `xattr -dr com.apple.quarantine CapsFix.app`;
4. System Settings → Privacy & Security → Accessibility → add `CapsFix.app`;
5. When it is working, `~/Library/Logs/capsfix.log` shows `TAP_OK`.

---

## 目录 / Contents

1. [事情是怎么开始的](#1-事情是怎么开始的--how-it-started)
2. [症状清单](#2-症状清单--symptoms)
3. [排查过程：先排除的嫌疑](#3-排查过程先排除的嫌疑--investigation-ruled-out)
4. [关键证据](#4-关键证据--key-evidence)
5. [根因](#5-根因--root-cause)
6. [为什么改设置都没用](#6-为什么改设置都没用--why-settings-cannot-fix-it)
7. [修复方案](#7-修复方案--the-fix)
8. [三个关键设计决定](#8-三个关键设计决定--three-key-design-decisions)
9. [构建与安装](#9-构建与安装--build--install)
10. [验证 / 诊断](#10-验证--诊断--verify--diagnose)
11. [硬件抖动 vs 软件 bug](#11-硬件抖动-vs-软件-bug--hardware-chatter-vs-software-bug)
12. [已知限制](#12-已知限制--limitations)
13. [许可](#13-许可--license)

---

## 1. 事情是怎么开始的 / How it started

**中文**

在一台 `MacBookPro13,3`（2016 款 15 英寸，macOS 15.8.2，通过 OpenCore Legacy
Patcher 运行）上，快速连续按两个字母键时，输出的字母大小写会随机变化，例如：

```
cVcVcVcVCVCvcvCVCvcvcvcv
```

慢速输入完全正常。数字和 `[`、`\` 看起来完全正常。中文输入必须非常慢，否则
拼音会被打断、回退成原始英文字母。

同样的现象此前也出现在另一台 **2021 款 MacBook Pro + 外接 Touch ID 键盘**上。
也就是说，它跨机器、跨键盘、跨 macOS 版本都存在过，不是这台 2016 机器独有的。

**English**

On a `MacBookPro13,3` (2016 15-inch, macOS 15.8.2 via OpenCore Legacy Patcher),
typing two letter keys in quick succession produced randomly cased output, e.g.:

```
cVcVcVcVCVCvcvCVCvcvcvcv
```

Slow typing was fine. Digits and `[` `\` looked completely normal. Chinese input had
to be typed very slowly, otherwise the pinyin composition was interrupted and fell
back to raw Latin letters.

The same symptom had previously appeared on a **2021 MacBook Pro with an external
Touch ID keyboard**. It spans machines, keyboards and macOS versions — it is not
specific to the 2016 machine.

---

## 2. 症状清单 / Symptoms

| 中文 | English |
|---|---|
| 快速、交叠按键时字母随机大写 | Random uppercase letters when keys overlap |
| 只有字母受影响，数字和 `[` `\` 正常 | Only letters affected; digits and `[` `\` fine |
| 慢速输入正常 | Slow typing is fine |
| 中文输入法在快速输入时被打断/丢字，回退为英文 | Chinese IME breaks / drops letters / falls back to Latin when typing fast |
| 屏幕共享（远程桌面）注入的按键不触发 | Keys injected over Screen Sharing do not trigger it |
| 换键盘/换机器仍可复现（同一个人、同一套系统设置） | Reproduces across keyboards/machines |

> 为什么"数字和 `[` `\` 正常"是一个重要线索？
> 因为 **Caps Lock 只影响字母，不影响数字和符号**。如果问题来自 Shift，数字会变成
> `!@#`，`[` 会变成 `{`。所以问题不在 Shift，而在 Caps Lock 状态。
>
> Why is "digits and brackets are fine" an important clue?
> Because **Caps Lock only affects letters, not digits or symbols**. If Shift were
> involved, digits would become `!@#` and `[` would become `{`. So the culprit is
> the Caps Lock state, not Shift.

---

## 3. 排查过程：先排除的嫌疑 / Investigation: ruled out

| 嫌疑 / Suspect | 结果 / Result | 依据 / Evidence |
|---|---|---|
| **Unshaky**（蝴蝶键盘"单击变双击"修复工具） | 排除 / Ruled out | 它是登录项，退出后仍复现；实时抓包也没显示它在改大小写 / It is a login item; quitting it did not fix the case bug, and event logs showed it was not the cause. |
| **鼠标双击修复类工具**（BetterMouse / Mac Mouse Fix / BetterTouchTool） | 排除 / Ruled out | 它们只挂钩鼠标事件；BTT/Karabiner 当时也没在运行 / They hook mouse events only; BTT/Karabiner were not running. |
| **通用控制 Universal Control** | 排除 / Ruled out | 关闭"允许光标和键盘在附近的 Mac 或 iPad 之间移动"后仍复现 / Disabling it did not fix it. |
| **用 Caps Lock 切换输入源** | 排除 / Ruled out | `CapsLockLanguageSwitch = No`，HIToolbox 里也没有该开关 / The setting was off; the relevant pref key was absent. |
| **粘滞键 / 慢速键 / 鼠标键** | 排除 / Ruled out | `HIDStickyKeysOn = 0`、`HIDSlowKeysDelay = 0`、`HIDMouseKeysOn = 0` / All off. |
| **Karabiner-Elements / BetterTouchTool / MTMR** | 排除 / Ruled out | 进程不在；没有第三方 HID/键盘 kext / Not running; no third-party HID kext loaded. |
| **多键盘 Caps 状态冲突** | 排除 / Ruled out | 把外接 `DSK` 设备的 Caps 同步为 0、关闭 `HIDCapsLockStateCache` 后仍复现 / Syncing the external device's Caps state and disabling the cache did not fix it. |
| **键盘硬件** | 排除（对本 bug）/ Ruled out (for this bug) | 换机器/键盘仍出现；远程注入不触发 / Reproduces across keyboards; remote-injected events do not trigger it. |
| **OCLP 打补丁** | 不是必要条件 / Not required | 2021 原生机器上也出现过 / Also reported on a native 2021 Mac. |

### 特别说明：Unshaky 与"丢字母" / Note: Unshaky and the "dropped letters"

排查中发现 **Unshaky 一直在运行**，而且它是登录项，`quit` 之后会被 launchd 拉回来。
它的工作方式是"在时间窗内吞掉重复按键"（该机器上配置为全键 40 ms、N 键 220 ms），
这会在快速输入时把**正常按键**也吞掉，造成"丢字母"（例如 `dada` → `dd`）。

Unshaky was found running (and auto-relaunched by launchd). Its job is to swallow
duplicate key events inside a time window (40 ms for all keys, 220 ms for `N` on
this machine). At speed it also swallows **legitimate** keys, producing dropped
letters (`dada` → `dd`).

---

## 4. 关键证据 / Key evidence

排查时用两个诊断脚本（见 `diagnostics/`）实时抓取键盘事件与修饰键状态。

Two diagnostic scripts (`diagnostics/`) were used to capture keyboard events and
modifier state in real time.

### 4.1 没有 Caps Lock 键码 / No Caps Lock keycode

- 全程 **0 个 `kc=57`**（Caps Lock 的 macOS 虚拟键码）事件；
- 但 `AlphaShift` 标志却在快速按键时反复翻转。

- **Zero `kc=57` events** (the macOS virtual keycode for Caps Lock);
- yet the `AlphaShift` flag flipped repeatedly during fast typing.

### 4.2 80/80 的确定性关联 / A deterministic 80/80 correlation

对 80 个非重复的 key-down 样本统计：

> **"按下这个键时，是否已有另一个键被按住"** 与 **"这个 key-down 是否带 `AlphaShift`"**
> **完全一致，80/80，零反例。**

For 80 non-repeat key-down samples:

> **"Was another key already held when this key went down?"** and **"Does this
> key-down carry `AlphaShift`?"** matched **perfectly, 80/80, zero exceptions.**

例子 / Example:

```
t=...152  DOWN kc=8  [-]      ← 没有其它键按住
t=...258  DOWN kc=9  [-]      ← 没有其它键按住
t=...364  DOWN kc=8  [-]      ← 没有其它键按住
t=...563  DOWN kc=9  [-]      ← 没有其它键按住
t=...671  DOWN kc=8  [CAPS]   ← 此时 kc=9 仍被按住 → 被误置 AlphaShift
t=...777  DOWN kc=9  [CAPS]   ← 此时 kc=8 仍被按住 → 被误置 AlphaShift
t=...905  DOWN kc=8  [-]      ← 再次没有其它键按住 → 干净
```

### 4.3 原始标志位 / Raw flag values

```
keyDown: 0x10100  = kCGEventFlagMaskNonCoalesced(0x100) | kCGEventFlagMaskAlphaShift(0x10000)
keyUp:   0x00100  = kCGEventFlagMaskNonCoalesced(0x100)
```

`0x10000` 正是 `kCGEventFlagMaskAlphaShift`。也就是说，**"按键按下"这个状态被错误地
映射成了 Caps Lock 位**。

`0x10000` is exactly `kCGEventFlagMaskAlphaShift`. In other words, **"a key is down"
was incorrectly mapped onto the Caps Lock bit.**

### 4.4 远程注入不触发 / Remote injection does not trigger it

通过屏幕共享从另一台电脑注入的按键不会复现。远程事件走的是会话层，绕过了出问题的
本地 HID → 事件管线。这进一步证明问题在**本地输入栈**，而不是应用层。

Keys injected from another computer over Screen Sharing did not reproduce it.
Remote events enter at the session layer and bypass the local HID → event pipeline.
This confirms the defect is in the **local input stack**, not in applications.

### 4.5 HID 层改写无效 / HID-layer rewriting is ineffective

尝试在 `.cghidEventTap` 清掉该位，但上层 session 事件仍然是 `[CAPS]`。所以必须在
**session 层**纠正。

Clearing the bit at `.cghidEventTap` did not propagate: session-level events still
showed `[CAPS]`. The correction has to happen at the **session layer**.

---

## 5. 根因 / Root cause

**中文**

macOS 的本地键盘事件管线在**按键交叠**时，会错误地把 Caps Lock 的 `AlphaShift`
标志位写进 key-down 事件（同时把全局修饰键状态也短暂置为大写）。这不是 Caps Lock
键被按下，也不是配置问题，而是输入栈对"按键按下计数 / 修饰键状态"的错误计算。

它是"老问题"的另一种表现：Apple 社区早在 2019 年（Catalina 10.15）就报告过
"Caps Lock 切换输入源时，慢速正常、正常打字速度下随机不切换或开启大写"。本次
触发条件不是"按 Caps Lock 切输入法"，而是更底层的**按键交叠**。

**English**

During **key rollover**, the macOS local keyboard event pipeline incorrectly writes
the Caps Lock `AlphaShift` flag into key-down events (and briefly sets the global
modifier state to Caps Lock). It is not the Caps Lock key being pressed and not a
configuration problem; it is a miscalculation of key-down/modifier state in the
input stack.

It is another manifestation of an old issue: Apple's community reported as early as
2019 (Catalina 10.15) that "when Caps Lock switches input sources, slow operation
works, but at normal typing speed it randomly fails to switch or enables Caps Lock".
Here the trigger is not tapping Caps Lock — it is **key rollover**.

---

## 6. 为什么改设置都没用 / Why settings cannot fix it

因为误置位发生在**系统生成事件的阶段**，早于任何用户设置（输入源、辅助功能、第三方
工具）介入。你能改的只是"如何解释事件"，改不了"事件本身被写错"。所以：

- 关掉通用控制：无效；
- 关掉 Caps 状态缓存：无效；
- 同步多键盘 Caps 状态：无效；
- 退出 Unshaky：对大小写无效（但对"丢字母"有效）；
- 换输入法/换键盘：无效。

Because the bad bit is written **while the system builds the event**, before any user
setting (input source, accessibility, third-party tool) is consulted. You can change
how events are interpreted, but not what was written into them. Hence disabling
Universal Control, caps-state caching, syncing multiple keyboards, or quitting
Unshaky does not fix the case bug.

---

## 7. 修复方案 / The fix

`CapsFix` 在 **session 层**安装一个 active `CGEventTap`，对每个键盘事件做三件事：

`CapsFix` installs an active `CGEventTap` at the **session layer** and does three
things for every keyboard event:

1. **跟踪按键状态**：维护当前按下的键集合。
2. **保存真实 Caps Lock 状态**：只在"没有任何键被按住"时采样 `AlphaShift`，
   这时它反映的是用户真正的 Caps Lock 状态。
3. **强制修正**：把每个事件的 `AlphaShift` 强制成真实状态——去掉 rollover 误置位，
   同时保留正常 Caps Lock。

1. **Track key state**: maintain the set of currently pressed keys.
2. **Keep the genuine Caps Lock state**: sample `AlphaShift` only when no key is
   held; at that moment it reflects the user's real Caps Lock state.
3. **Force the correct value**: set every event's `AlphaShift` to the genuine state —
   removing the rollover glitch while keeping real Caps Lock working.

此外，针对老化的蝴蝶键盘，提供**逐键去抖（per-key debounce）**：

- 默认：`N` 键 90 ms，其余键 15 ms；
- 只吞掉"同一键在极短时间内的重复 key-down"，以及它对应的 key-up；
- 不吞不同键，也不吞正常速度的重复输入。

Additionally, for aging butterfly keyboards, it provides **per-key debounce**:

- default: `N` = 90 ms, all other keys = 15 ms;
- swallows only a duplicate key-down of the same key within that window, plus its
  matching key-up;
- never touches different keys or normal-speed repeats.

---

## 8. 三个关键设计决定 / Three key design decisions

### 8.1 只清标志位，**绝不改写字符** / Clear the flag, **never rewrite the string**

一开始的实现会同时把事件里的字符（Unicode string）从 `A` 改成 `a`。结果：

- 英文大小写修好了；
- 但**中文输入法开始丢字母**（`dada` → `dd`），因为改写字符会打断 IME 的合成。

最终方案只改 `AlphaShift` 标志位。系统自己根据标志位计算字符，IME 也能正常合成。

The first implementation also rewrote the event's Unicode string from `A` to `a`.
Result: English case was fixed, but the **Chinese IME started dropping letters**
(`dada` → `dd`) because rewriting the characters breaks IME composition.

The final version only changes the `AlphaShift` flag. The system derives the
character from the flag, and the IME composes normally.

### 8.2 只在"没有键被按住"时采样真实 Caps 状态 / Sample the genuine state only when idle

如果无条件清零，真正的 Caps Lock 会失效。为了保留 Caps Lock：

- 当没有任何键被按住时，事件里的 `AlphaShift` 是可信的 → 记录下来；
- 当有键交叠时，这个位不可信 → 强制成刚才记录的真实状态。

If we always cleared it, real Caps Lock would stop working. To preserve it:

- when no key is held, `AlphaShift` is trustworthy → remember it;
- during rollover it is not → force it to the remembered genuine value.

### 8.3 去抖是逐键的 / Debounce is per-key

全局去抖会误伤正常输入。逐键去抖只处理"同一个键的短时间重复"，因此不会影响
`dada`、`zhongwen` 这类正常快速输入。

A global debounce would eat legitimate input. Per-key debounce only handles
same-key repeats within a tiny window, so it does not affect normal fast typing such
as `dada` or `zhongwen`.

---

## 9. 构建与安装 / Build & install

需要 / Requirements: macOS + Xcode Command Line Tools (`swiftc`).

```bash
./build.sh      # 编译并生成 build/CapsFix.app
./install.sh    # 安装到 ~/Applications 并注册 LaunchAgent
```

然后授权辅助功能 / Then grant Accessibility:

**系统设置 → 隐私与安全性 → 辅助功能 → 添加 `~/Applications/CapsFix.app`**
(System Settings → Privacy & Security → Accessibility → add `~/Applications/CapsFix.app`)

`install.sh` 会：

- 把 app 安装到 `~/Applications/CapsFix.app`；
- 写入 `~/Library/LaunchAgents/com.local.capsfix.plist`；
- 通过 `launchctl bootstrap` 启动，并设置 `RunAtLoad` + `KeepAlive`；
- 日志写到 `~/Library/Logs/capsfix.log`。

If Accessibility is not granted yet, the log shows `TAP_FAILED` and the agent keeps
retrying (every 10 s). Grant permission once and it will start.

---

## 10. 验证 / 诊断 / Verify & diagnose

`diagnostics/` 里是用于定位这个 bug 的工具：

- `flagwatch.swift`：轮询 `CGEventSource.flagsState`，记录 CAPS/SHIFT 等状态变化；
  可用来观察"快速按键时 CAPS 是否在翻转"。
- `keytap.swift`：记录每个 key-down/key-up/flagsChanged 的键码与原始 flags；
  可用来验证"没有 kc=57、但 key-down 带 `0x10000`"。

```bash
swift diagnostics/flagwatch.swift 60
swift diagnostics/keytap.swift 60
```

验证修复是否生效 / Verify the fix:

```bash
cat ~/Library/Logs/capsfix.log     # 应看到 TAP_OK
```

---

## 11. 硬件抖动 vs 软件 bug / Hardware chatter vs software bug

这是两件事，容易混在一起：

- **软件 bug**（本项目修的）：交叠按键时随机大小写、IME 被打断。特征是"几乎每次快速
  交叠都会发生"，且与具体按键无关。
- **硬件抖动**（蝴蝶键盘老化）：某个键（本例是 `N`）一次按下产生两次 key-down，间隔
  约 60–80 ms，导致 `zhongwen` → `zhonngwen`。这与具体按键有关。

`CapsFix` 同时处理两者：标志位修正 + 逐键去抖。但硬件抖动只是软件规避，**根本修复
仍是更换键盘**。

These are two different things:

- **Software bug** (fixed here): random case and IME breakage during rollover. It is
  reproducible on almost every fast overlap and is key-independent.
- **Hardware chatter** (aging butterfly keyboard): one physical press produces two
  key-downs ~60–80 ms apart on a specific key (`N` here), turning `zhongwen` into
  `zhonngwen`. This is key-specific.

`CapsFix` handles both: flag correction + per-key debounce. But debounce is only a
workaround; the real fix for chattering keys is **replacing the keyboard**.

---

## 12. 已知限制 / Limitations

- **需要辅助功能权限**。没有权限时 `TAP_FAILED`。
- 逐键去抖是对硬件老化的软件规避，不是硬件修复。
- 基于 CGEventTap 的方案会随系统输入栈变化而变化；未来 macOS 版本可能失效。
- 在 `MacBookPro13,3` / macOS 15.8.2（OpenCore Legacy Patcher）上验证；也收到过
  2021 款 MacBook Pro + 外接键盘的同类报告。
- 该工具只修正事件标志，不修改系统文件、不联网、不采集数据。

- **Requires Accessibility permission.** Without it: `TAP_FAILED`.
- Per-key debounce is a software workaround for aging hardware, not a hardware fix.
- The CGEventTap approach depends on the system input stack; a future macOS release
  may change it.
- Verified on `MacBookPro13,3` / macOS 15.8.2 (OpenCore Legacy Patcher); similar
  reports exist for a 2021 MacBook Pro with an external keyboard.
- It only corrects event flags. It does not modify system files, access the network,
  or collect data.

---

## 13. 许可 / License

GPL-3.0
