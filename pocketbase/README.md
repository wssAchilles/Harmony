# PocketBase 本地后端

启动 PocketBase：

```bash
docker compose up -d pocketbase
```

后台：

```text
http://localhost:8090/_/
```

默认本地超级用户由 `docker-compose.yml` 创建：

```text
admin@example.com / admin123456
```

创建 collection 并导入 Supabase 备份数据：

```bash
flutter pub get
dart run tool/setup_pocketbase.dart
```

脚本读取：

```text
supabase_restore_work/db_cluster-16-09-2025@15-17-22.backup
```

导入内容：

```text
auth.users -> profiles auth collection
public.profiles -> profiles
public.categories -> categories
public.students -> students
public.books -> books
public.borrow_records -> borrow_records
```

原 Supabase 用户无法直接迁移密码哈希，导入后的统一登录密码是：

```text
PocketBase123456
```

字段约束：

- 不创建 `users`、`book_cover_files`、`legacy_id`、`category_name` 等原库不存在的 collection 或字段。
- PocketBase 的 `id` 是系统字段，不能再创建自定义 `id` 字段；数字 id 使用 15 位补零形式保存到系统 `id`。
- `profiles.source_id` 保存原 Supabase `profiles.id` UUID；这是 PocketBase auth collection 无法保存完整 UUID 系统 id 时的唯一兼容字段。
- `books.category_id`、`borrow_records.student_id` 使用同名 `json` 字段保存原 nullable 数字值，避免空值变成 `0`。
- `books.cover_image_url` 原样保留 Supabase storage URL，不额外创建文件 collection。

鸿蒙模拟器或真机访问时，Flutter 不能使用 `127.0.0.1`，需要传 Mac 局域网 IP：

```bash
flutter run --dart-define=POCKETBASE_URL=http://你的Mac局域网IP:8090
```
