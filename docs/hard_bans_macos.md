# macOS 硬禁止项清单（出现即判失败）

目标：为“SAI2 级瞬间流畅”设定不可触碰的红线；只要命中任一条，**直接判失败**，不进入“再优化一下就行”的讨论。

适用范围（重点）：
- 任意笔触的 `pointer move / drag move` 绘制期间（包含连续涂抹、喷枪、曲线工具的拖拽阶段）。
- 画画过程中 UI 线程（Dart）只允许做：输入采集、UI 状态、提交轻量命令、显示 Texture；不得做像素级搬运与合成。

## Rust / GPU 侧（绝对禁止：GPU→CPU readback）

以下任一行为出现在“绘制进行中（尤其 move）”路径里，直接判失败：

- `copy_texture_to_buffer` + `map_async`（或等价的纹理/缓冲区读回）
- `queue.read_buffer` / `read_texture` / 任何形式把 GPU 纹理内容读回到 CPU 内存
- 为等待读回而执行的阻塞轮询：`device.poll(Maintain::Wait)`（或等价阻塞）

判定原则：
- **绘制过程中**（手指/笔还在动）不得为了显示或合成而发生 readback；允许在“松手后”的离线导出/保存流程做 readback（但要与实时绘制路径严格隔离）。

## Dart / Flutter 侧（绝对禁止：整幅像素拷贝与贴图链路）

以下任一行为出现在“绘制进行中（尤其 move）”路径里，直接判失败：

- **Dart 侧整幅像素合成/拷贝**：例如以 `Uint32List(width*height)` / `Uint8List(width*height*4)` 承载“画布最终像素”并在每次 move 全量更新（含全量 `setAll`、全量 RGBA/ARGB 转换）
- **`ui.decodeImageFromPixels`**（以及任何“像素 → ui.Image → 贴到画布”的实时渲染链路）
- `ui.Image.toByteData(format: rawRgba/png/...)` 出现在实时绘制链路（这通常意味着 GPU→CPU 或 CPU 大拷贝）

判定原则：
- 实时显示必须走 **Texture / GPU 直出**；Dart 侧不得持有“整幅画布像素”的权威拷贝。

## 备注：如何快速自查

- 代码检索（出现即高风险，需确认是否在实时绘制路径）：
  - Rust：`copy_texture_to_buffer`、`map_async`、`read_texture`、`read_buffer`
  - Dart：`decodeImageFromPixels`、`toByteData(`、`Uint32List(width * height)`、`width * height * 4`
- 性能现象侧证：
  - 绘制时 CPU 飙升、FPS 波动明显、笔触跟手延迟随画布尺寸线性变差，常见于“像素搬运/解码贴图”链路命中上述禁止项。

