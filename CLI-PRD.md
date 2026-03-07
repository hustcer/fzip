# fzip CLI 工具产品需求文档

## 1. 项目概述

**项目名称**: fzip CLI
**版本**: v0.1.0
**目标**: 提供一个高性能、易用的命令行压缩/解压工具，基于 fzip 库实现

### 设计理念

1. **统一接口**: 单一工具处理多种格式（参考 `bsdtar`, `7z`）
2. **直观易用**: 清晰的子命令结构（参考 `git`, `cargo`）
3. **兼容传统**: 支持常见工具的参数习惯（参考 `zip`, `tar`, `gzip`）
4. **智能默认**: 根据文件扩展名自动选择格式

## 2. 支持的格式

| 格式    | 扩展名         | 压缩 | 解压 | 多文件 | 优先级 |
| ------- | -------------- | ---- | ---- | ------ | ------ |
| ZIP     | `.zip`         | ✅   | ✅   | ✅     | P0     |
| GZIP    | `.gz`, `.gzip` | ✅   | ✅   | ❌     | P0     |
| Zlib    | `.zz`, `.zlib` | ✅   | ✅   | ❌     | P1     |
| DEFLATE | `.deflate`     | ✅   | ✅   | ❌     | P2     |

**自动检测**: 解压时自动识别格式（GZIP/Zlib/DEFLATE）

## 3. 命令行接口设计

### 3.1 总体结构

```bash
fzip <COMMAND> [OPTIONS] <ARGS>
```

### 3.2 子命令列表

| 命令       | 别名 | 功能         | 参考工具                     |
| ---------- | ---- | ------------ | ---------------------------- |
| `compress` | `c`  | 创建压缩包   | `tar -c`, `7z a`             |
| `extract`  | `x`  | 解压文件     | `tar -x`, `7z x`, `unzip`    |
| `list`     | `l`  | 列出内容     | `tar -t`, `7z l`, `unzip -l` |
| `test`     | `t`  | 测试完整性   | `7z t`, `unzip -t`           |
| `info`     | `i`  | 显示格式信息 | `file`                       |

## 4. 详细命令规范

### 4.1 `fzip compress` - 创建压缩包

**语法**:

```bash
fzip compress [OPTIONS] <INPUT>... -o <OUTPUT>
fzip c [OPTIONS] <INPUT>... -o <OUTPUT>
```

**参数**:

| 参数     | 短选项 | 长选项             | 说明                                    | 默认值      | 参考                   |
| -------- | ------ | ------------------ | --------------------------------------- | ----------- | ---------------------- |
| 输出文件 | `-o`   | `--output`         | 输出文件路径（必需）                    | -           | `tar -f`, `zip -o`     |
| 格式     | `-f`   | `--format`         | 压缩格式：`zip`/`gzip`/`zlib`/`deflate` | 根据扩展名  | `tar -z/-j`            |
| 压缩级别 | `-l`   | `--level`          | 0-9（0=不压缩，9=最高压缩）             | 6           | `gzip -1~-9`, `7z -mx` |
| 递归     | `-r`   | `--recursive`      | 递归处理目录                            | true（ZIP） | `zip -r`               |
| 详细输出 | `-v`   | `--verbose`        | 显示处理的文件                          | false       | `tar -v`, `zip -v`     |
| 保留路径 | `-p`   | `--preserve-paths` | 保留绝对/相对路径                       | false       | `zip -p`               |
| 排除     | `-e`   | `--exclude`        | 排除模式（可多次使用）                  | -           | `tar --exclude`        |
| 基础目录 | `-C`   | `--directory`      | 切换到目录后再压缩                      | -           | `tar -C`               |
| 强制覆盖 |        | `--force`          | 覆盖已存在的文件                        | false       | `zip -o`               |

**示例**:

```bash
# 创建 ZIP 归档（自动检测格式）
fzip compress file1.txt file2.txt dir/ -o archive.zip

# 创建 GZIP 文件
fzip compress large.log -o large.log.gz

# 指定压缩级别
fzip c -l 9 data/ -o data.zip

# 排除特定文件
fzip c src/ -o src.zip -e "*.tmp" -e "node_modules"

# 从特定目录压缩
fzip c -C /path/to/project src/ -o project.zip
```

### 4.2 `fzip extract` - 解压文件

**语法**:

```bash
fzip extract [OPTIONS] <ARCHIVE>
fzip x [OPTIONS] <ARCHIVE>
```

**参数**:

| 参数       | 短选项 | 长选项            | 说明                              | 默认值   | 参考                 |
| ---------- | ------ | ----------------- | --------------------------------- | -------- | -------------------- |
| 输出目录   | `-d`   | `--output-dir`    | 解压到指定目录                    | `.`      | `unzip -d`, `tar -C` |
| 输出文件   | `-o`   | `--output`        | 输出文件名（单文件格式）          | 自动推断 | `gunzip -c`          |
| 格式       | `-f`   | `--format`        | 强制指定格式                      | 自动检测 | -                    |
| 详细输出   | `-v`   | `--verbose`       | 显示解压的文件                    | false    | `unzip -v`           |
| 覆盖模式   |        | `--overwrite`     | 覆盖已存在文件                    | 询问     | `unzip -o`           |
| 跳过已存在 |        | `--skip-existing` | 跳过已存在文件                    | false    | `unzip -n`           |
| 仅列出     |        | `--list`          | 仅列出不解压（等同于 `list`）     | false    | `unzip -l`           |
| 测试       |        | `--test`          | 测试完整性不解压（等同于 `test`） | false    | `unzip -t`           |

**示例**:

```bash
# 解压到当前目录
fzip extract archive.zip

# 解压到指定目录
fzip x archive.zip -d /tmp/output

# 解压 GZIP 文件
fzip x file.gz -o file.txt

# 自动检测格式解压
fzip x unknown.bin -d output/

# 强制覆盖
fzip x archive.zip --overwrite
```

### 4.3 `fzip list` - 列出内容

**语法**:

```bash
fzip list [OPTIONS] <ARCHIVE>
fzip l [OPTIONS] <ARCHIVE>
```

**参数**:

| 参数     | 短选项 | 长选项      | 说明                         | 默认值   | 参考                  |
| -------- | ------ | ----------- | ---------------------------- | -------- | --------------------- |
| 详细模式 | `-v`   | `--verbose` | 显示详细信息（大小、日期等） | false    | `unzip -l`, `tar -tv` |
| 格式     | `-f`   | `--format`  | 强制指定格式                 | 自动检测 | -                     |

**输出格式**:

```
# 简洁模式
file1.txt
dir/file2.txt
dir/subdir/

# 详细模式（-v）
  Length      Date    Time    Name
---------  ---------- -----   ----
     1234  2026-03-07 10:30   file1.txt
     5678  2026-03-07 10:31   dir/file2.txt
        0  2026-03-07 10:29   dir/subdir/
---------                     -------
     6912                     3 files
```

**示例**:

```bash
# 简洁列表
fzip list archive.zip

# 详细列表
fzip l -v archive.zip
```

### 4.4 `fzip test` - 测试完整性

**语法**:

```bash
fzip test [OPTIONS] <ARCHIVE>
fzip t [OPTIONS] <ARCHIVE>
```

**参数**:

| 参数     | 短选项 | 长选项      | 说明           | 默认值   | 参考               |
| -------- | ------ | ----------- | -------------- | -------- | ------------------ |
| 详细输出 | `-v`   | `--verbose` | 显示测试的文件 | false    | `7z t`, `unzip -t` |
| 格式     | `-f`   | `--format`  | 强制指定格式   | 自动检测 | -                  |

**输出**:

```
Testing archive.zip...
  file1.txt ... OK
  dir/file2.txt ... OK
All files OK (2 files tested)
```

**示例**:

```bash
# 测试 ZIP 文件
fzip test archive.zip

# 详细测试
fzip t -v archive.zip
```

### 4.5 `fzip info` - 显示信息

**语法**:

```bash
fzip info <FILE>
fzip i <FILE>
```

**输出**:

```
File: archive.zip
Format: ZIP
Compressed size: 1.2 MB
Uncompressed size: 3.5 MB
Compression ratio: 65.7%
Files: 42
Directories: 5
```

**示例**:

```bash
fzip info archive.zip
fzip i file.gz
```

## 5. 全局选项

| 参数     | 短选项 | 长选项      | 说明             |
| -------- | ------ | ----------- | ---------------- |
| 帮助     | `-h`   | `--help`    | 显示帮助信息     |
| 版本     | `-V`   | `--version` | 显示版本信息     |
| 安静模式 | `-q`   | `--quiet`   | 不输出非错误信息 |
| 详细模式 | `-v`   | `--verbose` | 输出详细信息     |

## 6. 智能特性

### 6.1 格式自动检测

**压缩时**（根据输出文件扩展名）:

- `.zip` → ZIP
- `.gz`, `.gzip` → GZIP
- `.zz`, `.zlib` → Zlib
- `.deflate` → DEFLATE
- 其他 → 默认 ZIP

**解压时**（根据文件头魔数）:

- `1f 8b` → GZIP
- `78 01/78 9c/78 da` → Zlib
- 其他 → 尝试 DEFLATE

### 6.2 输出文件名推断

**GZIP 压缩**:

```bash
fzip c file.txt -o file.txt.gz  # 显式指定
fzip c file.txt                  # 自动生成 file.txt.gz
```

**GZIP 解压**:

```bash
fzip x file.txt.gz -o file.txt  # 显式指定
fzip x file.txt.gz               # 自动生成 file.txt
```

### 6.3 进度显示

对于大文件（>10MB）自动显示进度条:

```
Compressing... [████████████████░░░░] 78% (3.2 MB / 4.1 MB)
```

## 7. 错误处理

### 7.1 退出码

| 退出码 | 含义          |
| ------ | ------------- |
| 0      | 成功          |
| 1      | 一般错误      |
| 2      | 参数错误      |
| 3      | 文件不存在    |
| 4      | 权限错误      |
| 5      | 格式错误/损坏 |
| 6      | 磁盘空间不足  |

### 7.2 错误信息

```bash
# 文件不存在
Error: File not found: 'archive.zip'

# 格式不支持
Error: Unsupported format: '.rar'
Supported formats: zip, gzip, zlib, deflate

# 损坏的归档
Error: Corrupted archive: CRC32 mismatch in 'file.txt'
```

## 8. 参考工具对比

| 功能      | fzip | tar | zip/unzip | 7z  | gzip |
| --------- | ---- | --- | --------- | --- | ---- |
| 统一接口  | ✅   | ❌  | ❌        | ✅  | ❌   |
| 子命令    | ✅   | ❌  | ❌        | ✅  | ❌   |
| 自动检测  | ✅   | ❌  | ❌        | ✅  | ❌   |
| ZIP 支持  | ✅   | ❌  | ✅        | ✅  | ❌   |
| GZIP 支持 | ✅   | ✅  | ❌        | ✅  | ✅   |
| 进度显示  | ✅   | ❌  | ❌        | ✅  | ❌   |

**主要参考**:

- **7z**: 子命令设计（`a`, `x`, `l`, `t`）
- **tar**: 参数命名（`-C`, `-f`, `--exclude`）
- **zip/unzip**: 常用选项（`-r`, `-d`, `-o`）
- **bsdtar**: 统一接口理念
- **cargo/git**: 现代 CLI 设计

## 9. 实现优先级

### Phase 1: MVP（最小可行产品）

- [x] 基础框架（参数解析）
- [ ] `compress` 命令（ZIP + GZIP）
- [ ] `extract` 命令（ZIP + GZIP + 自动检测）
- [ ] `list` 命令（ZIP）
- [ ] 错误处理

### Phase 2: 完善功能

- [ ] `test` 命令
- [ ] `info` 命令
- [ ] Zlib/DEFLATE 支持
- [ ] 进度显示
- [ ] 详细模式（`-v`）

### Phase 3: 高级特性

- [ ] 排除模式（`--exclude`）
- [ ] 增量压缩
- [ ] 并行压缩
- [ ] 配置文件支持

## 10. 技术栈

- **语言**: MoonBit
- **核心库**: fzip
- **参数解析**: 待定（可能需要实现或移植）
- **进度条**: 待定
- **测试**: moon test

## 11. 使用示例集

```bash
# 场景1: 备份项目
fzip c -r project/ -o backup.zip -e "target" -e ".git"

# 场景2: 压缩日志
fzip c app.log -o app.log.gz -l 9

# 场景3: 解压到临时目录
fzip x archive.zip -d /tmp/extract

# 场景4: 查看压缩包内容
fzip l archive.zip -v

# 场景5: 验证下载的文件
fzip t downloaded.zip

# 场景6: 批量压缩
for file in *.log; do
  fzip c "$file" -o "$file.gz"
done

# 场景7: 管道操作（未来）
cat data.txt | fzip c -f gzip > data.gz
fzip x data.gz -o - | grep "pattern"
```

## 12. 文档计划

- [ ] README.md（快速开始）
- [ ] man page（详细手册）
- [ ] 在线文档（示例和教程）
- [ ] `--help` 输出（内置帮助）

---

**文档版本**: v1.0
**最后更新**: 2026-03-08
**作者**: Claude + hustcer
