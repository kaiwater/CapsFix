# CapsFix

**修复 macOS 在按键交叠（rollover）时把 Caps Lock / `AlphaShift` 位错误写进按键事件，导致随机大写、中文输入法被打断/丢字的问题。**

A tiny macOS utility that fixes random uppercase letters and broken Chinese IME
input caused by the keyboard event pipeline setting `kCGEventFlagMaskAlphaShift`
on key-down during key rollover.

---

## 症状 / Symptoms

- 快速打字、两键交叠时，字母随机变大写：`cVcVcVcV...`
- 中文输入法在快速输入时被打断、回退成英文字母，或丢字母（`zhongwen` → `zhw`）
- 数字和 `[ \` 看起来正常（因为 Caps Lock 不影响它们，所以问题只在字母上暴露）
- 慢速打字正常；远程桌面注入的按键不触发

- Random mixed case when typing fast: `cVcVcVcV...`
- Chinese IME composition breaks / outputs raw Latin / drops letters when typing fast
- Digits and brackets look fine (Caps Lock does not affect them)
- Slow typing is fine; keys injected over Screen Sharing do not trigger it

## 根因 / Root cause

**不是 Caps Lock 键坏了。** 在按键交叠时，本地 HID/事件管线会给 key-down 事件置上
`AlphaShift` 标志，即使 Caps Lock 是关闭的。

**It is not the Caps Lock key.** During key rollover, the local HID/event pipeline
sets the `AlphaShift` flag on the key-down event even though Caps Lock is off.

实测证据 / Measured evidence:

- 80/80 个 key-down 事件在"已有另一个键被按住"时带 `AlphaShift`，零反例；
- 全程 0 个 Caps Lock 键码（57）事件；
- 屏幕共享注入的按键不复现（绕过了本地 HID 路径）；
- 关闭 Unshaky、通用控制、修改"用 Caps Lock 切输入源"都无效。

- 80/80 key-down events carried `AlphaShift` exactly when another key was already
  held; zero exceptions.
- Zero Caps Lock keycode (57) events.
- Keys injected over Screen Sharing do not reproduce it (they bypass the local HID path).
- Disabling Unshaky, Universal Control, or the "Use Caps Lock to switch input source"
  setting does not fix it.

## 修复原理 / How it works

`CapsFix` 在 session 层安装一个 active `CGEventTap`：

1. 跟踪当前按下的键；
2. 只在"没有任何键被按住"时采样并保存**真实的** Caps Lock 状态；
3. 把每个键盘事件的 `AlphaShift` 强制成真实状态——去掉 rollover 误置位，同时保留正常 Caps Lock；
4. 可选：对抖动的蝴蝶键盘按键做**逐键去抖**（默认 `N` 键 90ms，其余 15ms）。

**关键点：不改写字符（Unicode string）。** 改写字符会打断中文输入法的合成。

`CapsFix` installs an active `CGEventTap` at the session level:

1. Tracks pressed keys.
2. Samples the *genuine* Caps Lock state only when no key is held.
3. Forces the `AlphaShift` flag on each keyboard event to that genuine state,
   removing the rollover glitch while keeping real Caps Lock working.
4. Optionally debounces chattering keys per keycode (default: `N` 90 ms, others 15 ms).

It deliberately **does not rewrite the Unicode string**, because that breaks IME
composition.

## 构建与安装 / Build & install

需要 / Requirements: macOS + Xcode Command Line Tools (`swiftc`).

```bash
./build.sh      # 编译并生成 build/CapsFix.app
./install.sh    # 安装到 ~/Applications 并注册 LaunchAgent
```

然后授权辅助功能 / Then grant Accessibility:

**系统设置 → 隐私与安全性 → 辅助功能 → 添加 `~/Applications/CapsFix.app`**
(System Settings → Privacy & Security → Accessibility → add `~/Applications/CapsFix.app`)

LaunchAgent 会在登录时自动启动并保持运行。

The LaunchAgent starts it at login and keeps it alive.

## 卸载 / Uninstall

```bash
./uninstall.sh
```

## 调参 / Tuning

编辑 `Sources/main.swift`：

```swift
let perKey: [Int64: Double] = [45: 0.090]   // N = 90 ms
let defaultThreshold: Double = 0.015        // 其余 = 15 ms
```

然后重新 `./build.sh && ./install.sh`。

Edit and rebuild.

## 诊断脚本 / Diagnostics

`diagnostics/` 里是复现/测量这个 bug 用到的工具：

- `flagwatch.swift` – 记录 `CGEventSource.flagsState` 的变化
- `keytap.swift` – 记录键码与事件标志位

## 已知限制 / Limitations

- 需要辅助功能（Accessibility）权限。
- 逐键去抖只是对老化蝴蝶键盘的软件规避，不是硬件修复。
- 在 MacBookPro13,3 / macOS 15.8.2（OpenCore Legacy Patcher）上验证。

- Requires Accessibility permission.
- Per-key debounce is a software workaround for failing butterfly keyboards, not a hardware fix.
- Verified on MacBookPro13,3 / macOS 15.8.2 (OpenCore Legacy Patcher).

## 许可 / License

GPL-3.0
