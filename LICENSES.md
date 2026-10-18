# 许可范围

本仓库包含游戏代码、原创内容与第三方素材，各部分许可分别列明。第三方题库的许可不应被其他文件中的通用软件许可覆盖。

## Go Game Guru 题库

`assets/problems/gogameguru/` 中的原始题谱和 `assets/problems/library.json` 中的转换题目及中文题面转述使用 **CC BY-NC-SA 4.0**：署名、非商业、相同方式共享。

作者／维护者：David Ormerod、An Younggil。

- [来源仓库](https://github.com/gogameguru/go-problems)
- [完整许可原文](assets/problems/gogameguru/LICENSE.txt)
- [署名、版本与改编说明](assets/problems/NOTICE.md)

本仓库作为非商业学习与交流项目公开。使用这部分题库进行商业发行需要另行取得适用授权或替换内容。改编题目继续按同一许可提供。

## CC0 素材

以下文件采用 CC0；来源和处理记录随素材保留：

| 文件 | 来源 |
| --- | --- |
| `assets/fine_wood/` | [Poly Haven / Fine Grained Wood](https://polyhaven.com/a/fine_grained_wood)，Rob Tuytel；详见目录内 `source.json`。 |
| `assets/wood/` | [Poly Haven / Wood Table 001](https://polyhaven.com/a/wood_table_001)，Dimitrios Savva、Rico Cilliers；旧版材质留存，详见目录内 `source.json`。 |
| `assets/studio/` | [Poly Haven / Studio Small 09](https://polyhaven.com/a/studio_small_09)，Sergej Majboroda；详见目录内 `source.json`。 |
| `assets/audio/` | [billhails2 / GoStoneSounds.ogg](https://freesound.org/people/billhails2/sounds/588317/) 及其截取片段；详见目录内 `source.json`。 |

[Poly Haven 许可](https://polyhaven.com/license) · [CC0 1.0 说明](https://creativecommons.org/publicdomain/zero/1.0/)。

字体通过系统字体调用，没有把本机字体文件打包到仓库。Godot 引擎二进制文件不在本仓库中。

## KataGo 本地 AI

KataGo 引擎代码采用 MIT，其上游依赖仍各自按原许可提供；完整官方声明见 [ENGINE.txt](engines/katago/licenses/ENGINE.txt)。本次选用的官方 b18 权重采用 KataGo Neural Network License，允许免费使用、复制、修改和分发，需保留版权与许可声明；官方页面快照见 [NETWORK.html](engines/katago/licenses/NETWORK.html)，[最新官方许可](https://katagotraining.org/network_license/)。

本仓库提供固定下载地址与 SHA-256 校验的安装器，不提交第三方引擎二进制或模型权重。此许可不改变 Go Game Guru 题库的非商业和相同方式共享条件。

## 游戏代码与原创内容

游戏代码、程序化棋具、界面和原有入门内容尚未指定独立的软件开源许可证。本次公开上传没有把这些内容统一改为 MIT，也没有改变上述第三方素材的既有许可。
