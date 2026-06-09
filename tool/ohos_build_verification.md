# HarmonyOS / OpenHarmony Build Verification

This document tells agents how to verify this project with the local Flutter for OpenHarmony SDK and the local DevEco / HarmonyOS CLI tools on this machine.

## Scope

- Project root: `/Users/achilles/Documents/Harmony/kindergarten_library`
- OHOS project: `/Users/achilles/Documents/Harmony/kindergarten_library/ohos`
- Preferred verification path: use the local Flutter for OpenHarmony SDK to build a HAP.
- Harmony CLI tools (`ohpm`, `hvigorw`) are useful for environment checks and lower-level OHOS project diagnosis.

Do not use the system `flutter` from `PATH` unless it resolves to the OHOS Flutter SDK below. The normal upstream Flutter SDK may not support `flutter build hap`.

## Local Toolchain

Verified on 2026-06-09:

```text
Flutter for OpenHarmony: /Users/achilles/development/flutter_flutter_3_22_ohos
Flutter: 3.22.0
Dart: 3.4.0
DevEco Studio: /Applications/DevEco-Studio.app/Contents
HarmonyOS SDK: /Applications/DevEco-Studio.app/Contents/sdk
ohpm: 6.0.1
node: v18.20.1
hvigorw: 6.22.3
Java: DevEco JBR 21.0.8
```

Use absolute paths in automation:

```bash
export PROJECT_ROOT=/Users/achilles/Documents/Harmony/kindergarten_library
export OHOS_FLUTTER=/Users/achilles/development/flutter_flutter_3_22_ohos/bin/flutter
export DEVECO_HOME=/Applications/DevEco-Studio.app/Contents
export OHPM=$DEVECO_HOME/tools/ohpm/bin/ohpm
export HVIGORW=$DEVECO_HOME/tools/hvigor/bin/hvigorw
export DEVECO_NODE=$DEVECO_HOME/tools/node/bin/node
export DEVECO_JAVA=$DEVECO_HOME/jbr/Contents/Home/bin/java
```

## Required Environment

Before running Harmony CLI or HAP builds, export DevEco paths explicitly:

```bash
export HOS_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export OHOS_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony
export OHOS_BASE_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony
export TOOL_HOME=/Applications/DevEco-Studio.app/Contents
export JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home
export PATH=/Users/achilles/development/flutter_flutter_3_22_ohos/bin:$TOOL_HOME/tools/ohpm/bin:$TOOL_HOME/tools/hvigor/bin:$TOOL_HOME/tools/node/bin:$JAVA_HOME/bin:$PATH
```

If `hvigorw` reports `Invalid value of 'DEVECO_SDK_HOME'`, the environment above was not applied in the current shell. Re-export it and retry.

## Fast Toolchain Check

Run these first when diagnosing a machine or CI environment:

```bash
cd /Users/achilles/Documents/Harmony/kindergarten_library

/Users/achilles/development/flutter_flutter_3_22_ohos/bin/flutter --version
/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm --version
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node --version
/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home/bin/java -version

cd /Users/achilles/Documents/Harmony/kindergarten_library/ohos
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --version
```

Expected high-level result:

- Flutter reports `Flutter 3.22.0` and `Dart 3.4.0`.
- `ohpm --version` reports `6.0.1`.
- `node --version` reports `v18.20.1`.
- `hvigorw --version` reports `6.22.3`.

In Codex, prefix noisy commands with `rtk` unless exact stdout/stderr is needed.

## Recommended Build Verification

This is the main verification path. It exercises Dart compilation, Flutter OHOS assembly, and Hvigor HAP packaging.

```bash
cd /Users/achilles/Documents/Harmony/kindergarten_library

export HOS_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export OHOS_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony
export OHOS_BASE_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony
export TOOL_HOME=/Applications/DevEco-Studio.app/Contents
export JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home
export PATH=/Users/achilles/development/flutter_flutter_3_22_ohos/bin:$TOOL_HOME/tools/ohpm/bin:$TOOL_HOME/tools/hvigor/bin:$TOOL_HOME/tools/node/bin:$JAVA_HOME/bin:$PATH

/Users/achilles/development/flutter_flutter_3_22_ohos/bin/flutter pub get
/Users/achilles/development/flutter_flutter_3_22_ohos/bin/flutter build hap --debug --no-codesign --target-platform ohos-arm64
```

Expected artifact:

```text
/Users/achilles/Documents/Harmony/kindergarten_library/ohos/entry/build/default/outputs/default/entry-default-unsigned.hap
```

Check it:

```bash
test -f /Users/achilles/Documents/Harmony/kindergarten_library/ohos/entry/build/default/outputs/default/entry-default-unsigned.hap
ls -lh /Users/achilles/Documents/Harmony/kindergarten_library/ohos/entry/build/default/outputs/default/entry-default-unsigned.hap
```

`--no-codesign` only skips signing. A successful command still validates Dart compile, Flutter OHOS assemble, and Hvigor packaging. Installing to a simulator or device still requires a signed HAP.

## Build With PocketBase URL

For emulator use, the project default is `http://10.0.2.2:8090`, because `127.0.0.1` inside an emulator points to the device itself.

For a real device on the same network as the Mac, pass the Mac LAN IP:

```bash
cd /Users/achilles/Documents/Harmony/kindergarten_library

/Users/achilles/development/flutter_flutter_3_22_ohos/bin/flutter build hap \
  --debug \
  --no-codesign \
  --target-platform ohos-arm64 \
  --dart-define=POCKETBASE_URL=http://192.168.x.x:8090
```

Replace `192.168.x.x` with the Mac's actual LAN address.

## Harmony CLI Diagnostics

Use these when Flutter HAP build fails inside the OHOS layer.

Install or refresh OHOS module dependencies:

```bash
cd /Users/achilles/Documents/Harmony/kindergarten_library/ohos

export HOS_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export OHOS_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony
export OHOS_BASE_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony
export TOOL_HOME=/Applications/DevEco-Studio.app/Contents
export JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home
export PATH=/Users/achilles/development/flutter_flutter_3_22_ohos/bin:$TOOL_HOME/tools/ohpm/bin:$TOOL_HOME/tools/hvigor/bin:$TOOL_HOME/tools/node/bin:$JAVA_HOME/bin:$PATH

/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm install --all
```

List Hvigor tasks:

```bash
cd /Users/achilles/Documents/Harmony/kindergarten_library/ohos
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw tasks --no-daemon
```

Low-level app package build:

```bash
cd /Users/achilles/Documents/Harmony/kindergarten_library/ohos
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleApp --no-daemon --parallel --incremental
```

Prefer `flutter build hap` for final verification, because Flutter generates and wires the OHOS build artifacts before Hvigor packages them. Use direct `hvigorw` commands to isolate OHOS dependency, SDK, signing, or packaging issues.

## Optional Full Local Quality Gate

Before or after HAP verification, run the normal Flutter checks with the OHOS Flutter SDK:

```bash
cd /Users/achilles/Documents/Harmony/kindergarten_library

/Users/achilles/development/flutter_flutter_3_22_ohos/bin/flutter analyze --no-fatal-infos
/Users/achilles/development/flutter_flutter_3_22_ohos/bin/flutter test
dart analyze tool/setup_pocketbase.dart
```

These commands are not a substitute for `flutter build hap`; they catch Dart and test regressions before packaging.

## Signing And Installation

The unsigned debug HAP is enough for build verification. To install or run on a HarmonyOS simulator/device:

1. Open `ohos/` in DevEco Studio.
2. Go to `File -> Project Structure -> Signing Configs`.
3. Enable automatic signature generation.
4. Build or run from DevEco Studio, or rerun the relevant signed build flow.

Do not treat a `--no-codesign` HAP as install-ready.

## Agent Rules

- Use `/Users/achilles/development/flutter_flutter_3_22_ohos/bin/flutter`, not the default `flutter`.
- Export DevEco/Harmony environment variables in every new shell before running `hvigorw`.
- Do not run `dart run tool/setup_pocketbase.dart` as part of build verification; it resets PocketBase collections.
- Do not delete `ohos/oh_modules`, `ohos/node_modules`, or build outputs unless the user explicitly asks for a clean rebuild.
- If the worktree is dirty, do not revert unrelated changes. Build verification can run with a dirty worktree, but report that state in the final answer.
