# 幼儿园图书馆管理系统

Flutter 前端 + PocketBase 本地后端的幼儿园图书管理应用，支持图书、分类、学生、借阅记录、教师账号和仪表盘统计。

当前后端已从 Supabase 迁移到 PocketBase，并通过 Docker Compose 本地运行。Flutter 前端尽量保留原有界面和业务流程，数据访问层已切换到 `pocketbase` SDK。

## 技术栈

- Flutter / Dart
- PocketBase
- Docker Compose

核心依赖见 [pubspec.yaml](/Users/achilles/Documents/Harmony/kindergarten_library/pubspec.yaml)：

```yaml
pocketbase: ^0.23.3
shared_preferences: ^2.3.2
cached_network_image: ^3.3.0
image_picker: ^1.0.4
intl: ^0.18.1
```

## 本地启动

启动 PocketBase：

```bash
docker compose up -d pocketbase
```

当前 Docker Compose 使用 named volume `kindergarten-pocketbase-data`
保存 PocketBase 的 `/pb_data`，避免在 macOS Docker bind mount
文件共享层上直接读写 SQLite 数据库。`pocketbase/pb_public` 和
`pocketbase/pb_hooks` 仍以 bind mount 方式挂载，方便本地维护封面图片和 hooks。

查看实际挂载：

```bash
docker inspect kindergarten-pocketbase --format '{{range .Mounts}}{{println .Type .Name .Destination}}{{end}}'
```

手动备份运行中的 volume：

```bash
mkdir -p pocketbase/backups
docker compose stop pocketbase
docker run --rm \
  -v kindergarten-pocketbase-data:/pb_data:ro \
  -v "$PWD/pocketbase/backups:/backup" \
  alpine:3.20 \
  tar -czf /backup/pb_data-$(date +%Y%m%d%H%M%S).tgz -C /pb_data .
docker compose up -d pocketbase
```

PocketBase 后台：

```text
http://localhost:8090/_/
```

默认本地超级用户：

```text
admin@example.com / admin123456
```

创建 collection 并从 Supabase 备份导入数据：

```bash
flutter pub get
dart run tool/setup_pocketbase.dart
```

导入后的原 Supabase 用户登录密码统一为：

```text
12345678
```

### 应用登录账号

| 邮箱 | 密码 | 姓名 | 角色 | 性质 |
| --- | --- | --- | --- | --- |
| `1424408591@qq.com` | `12345678` | 奕晨司 | `teacher` | 普通教师 |
| `2633638634@qq.com` | `12345678` | 小明 | `teacher` | 普通教师 |
| `903398655@qq.com` | `12345678` | 开心逗逗儿 | `admin` | 管理员 |

说明：上表账号用于 Flutter/HarmonyOS 应用登录；`admin@example.com / admin123456` 是 PocketBase 后台超级用户，用于访问管理后台，不是应用内教师账号。

Flutter 默认连接：

```text
http://10.0.2.2:8090
```

鸿蒙模拟器访问 Mac 上的 PocketBase 时，不要使用 `127.0.0.1`；在模拟器内它指向设备自身。默认使用 `10.0.2.2` 访问宿主机。真机或其他网络环境可以传入 Mac 局域网 IP：

```bash
flutter run --dart-define=POCKETBASE_URL=http://你的Mac局域网IP:8090
```

## 数据迁移来源

迁移脚本读取：

```text
supabase_restore_work/db_cluster-16-09-2025@15-17-22.backup
```

已迁移的 Supabase 数据：

| 来源 | 行数 |
| --- | ---: |
| `auth.users` | 3 |
| `public.profiles` | 3 |
| `public.categories` | 4 |
| `public.students` | 4 |
| `public.books` | 6 |
| `public.borrow_records` | 8 |

注意：PocketBase 的 record `id` 是固定系统字段，不能创建自定义 `id` 字段，也不能保存完整 UUID。

- `categories`、`students`、`books`、`borrow_records` 使用 PocketBase 系统 `id` 保存原 Supabase 数字 id 的 15 位补零形式，例如 Supabase `6` 保存为 `000000000000006`，Flutter 模型读取时还原为 `6`。
- `profiles` 是 PocketBase auth collection，系统 `id` 保存 UUID 去横线后的 15 位兼容 id，原 Supabase UUID 保存在 `source_id`。这是唯一为兼容 PocketBase 身份认证和 UUID 长度限制而增加的业务字段。
- `books.category_id` 和 `borrow_records.student_id` 使用 PocketBase `json` 字段保存原 nullable 数字值，避免空值被 PocketBase number 字段转换成 `0`。
- `cover_image_url` 从原 Supabase 图片地址改为 `/covers/book_*.png`，图片文件放在 `pocketbase/pb_public/covers`，由 PocketBase 静态目录直接提供。

## PocketBase Collection 字段

### `profiles`

PocketBase 类型：`auth`

业务字段：

```text
source_id text
full_name text
updated_at date
role text
```

Auth 系统字段包括 `id`、`email`、`password`、`tokenKey`、`emailVisibility`、`verified`。

### `categories`

```text
id system text
name text
created_at date
```

### `students`

```text
id system text
created_at date
full_name text
class_name text
```

### `books`

```text
id system text
created_at date
title text
author text
location text
cover_image_url text
status text
last_updated_by text
total_quantity number
available_quantity number
category_id json
```

### `borrow_records`

```text
id system text
created_at date
book_id number
student_id json
profile_id text
borrow_date date
due_date date
return_date date
borrowed_by_user_id text
quantity number
```

借阅人关系沿用 Supabase 原语义：

- `student_id` 与 `profile_id` 二选一，分别表示学生借阅和老师/管理员借阅。
- `borrowed_by_user_id` 表示经办老师。
- 当前迁移备份里的 8 条 `borrow_records` 都是 `profile_id` 老师/管理员借阅，`student_id` 均为空；因此学生详情页没有历史借阅记录是源数据事实，不是学生关系丢失。

## 验证命令

```bash
dart analyze tool/setup_pocketbase.dart
flutter analyze --no-fatal-infos
flutter test
flutter build web --no-tree-shake-icons
```

当前迁移还做了 API 级全量比对：5 个 public collection 的 25 行数据与 Supabase 备份逐行匹配，3 个 `auth.users` 用户映射到 `profiles`。

## HarmonyOS / OpenHarmony 状态

已使用 Flutter for OpenHarmony 3.22 生成并校准 `ohos/` 工程：

```bash
/Users/achilles/development/flutter_flutter_3_22_ohos/bin/flutter create --platforms ohos --project-name kindergarten_library --no-pub .
```

当前用于鸿蒙构建的 Flutter SDK：

```text
Flutter 3.22.0
Dart 3.4.0
/Users/achilles/development/flutter_flutter_3_22_ohos
```

本机 DevEco / HarmonyOS CLI 工具链已识别：

```text
HarmonyOS SDK: /Applications/DevEco-Studio.app/Contents/sdk
API: 22:default
ohpm: 6.0.1
node: v18.20.1
hvigorw: /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
```

鸿蒙 CLI 构建需要显式设置 DevEco 环境变量：

```bash
export HOS_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export OHOS_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony
export OHOS_BASE_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony
export TOOL_HOME=/Applications/DevEco-Studio.app/Contents
export JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home
export PATH=/Users/achilles/development/flutter_flutter_3_22_ohos/bin:$TOOL_HOME/tools/ohpm/bin:$TOOL_HOME/tools/hvigor/bin:$TOOL_HOME/tools/node/bin:$JAVA_HOME/bin:$PATH
```

验证通过的 HAP 构建命令：

```bash
/Users/achilles/development/flutter_flutter_3_22_ohos/bin/flutter pub get
/Users/achilles/development/flutter_flutter_3_22_ohos/bin/flutter build hap --debug --no-codesign --target-platform ohos-arm64
```

构建产物：

```text
ohos/entry/build/default/outputs/default/entry-default-unsigned.hap
```

说明：`--no-codesign` 只跳过签名，Dart 编译、Flutter OHOS assemble、Hvigor 打包均已通过。安装到模拟器前仍需要签名；用 DevEco Studio 打开 `ohos/` 后，在 `File -> Project Structure -> Signing Configs` 勾选 `Automatically generate signature`，再运行到模拟器。

如果真机访问 Mac 上的 PocketBase，构建或运行时请把 `POCKETBASE_URL` 改成 Mac 局域网 IP，例如：

```bash
--dart-define=POCKETBASE_URL=http://192.168.x.x:8090
```

如果仍想让已安装的旧包继续访问 `127.0.0.1:8090`，可以临时给当前模拟器加反向端口：

```bash
hdc rport tcp:8090 tcp:8090
```

## 项目结构

```text
lib/
  config/backend_config.dart
  models/
  screens/
  services/
    backend/pocketbase_client.dart
    backend/pb_mapper.dart
tool/setup_pocketbase.dart
docker-compose.yml
pocketbase/
supabase_restore_work/
ohos/
```
