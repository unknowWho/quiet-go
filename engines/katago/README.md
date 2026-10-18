# 本地 KataGo

双击工程根目录 `SetupAI.cmd`，下载官方 Windows OpenCL 引擎（约 6 MB）和 b18 模型（约 98 MB）。无需 Python、账号或云端服务；需要支持 OpenCL 的显卡驱动。安装文件只写入本目录，首次运行会在游戏存档目录进行显卡调优，可能需要几分钟。之后对弈与分析完全离线。

固定使用 1.18.1 OpenCL。调研时最新 1.18.2 的预编译附件仅有 CUDA 后端；1.18.1 有官方 OpenCL 版本，可直接利用本机已有驱动。b18 卷积模型兼顾下载体积、速度与棋力，并非最新最大的模型。下载地址、哈希和许可记录在 `source.json`。安装器对两份下载进行 SHA-256 校验。

游戏内“棋局设置 → KataGo 对弈”开始执黑人机局；“形势判断”也可用于同屏双人和入门陪练局。快速、标准、深入的搜索目标分别为 128 / 512 / 2048 次、时间上限 1.5 / 4 / 10 秒（先达到的限制生效，并行搜索可能略超目标次数），不声称对应任何人类段位。首次模型载入、调优不计入每步搜索时间。

请求包含初始摆子和完整真实落子序列。使用面积计分、位置禁全同、禁自杀、无双活税、无让子补偿、7.5 点贴目，与本项目规则预设一致。所有 AI 着手还必须通过游戏规则引擎。胜率、目差和地域统一为黑方视角；正目差表示黑领先；正地域值表示黑方归属。

形势是 AI 对后续双方下法的预测，已经计入贴目，单位是双方分差的“目 / 点”；2 目相当于终局胜差的 1 子。双停后的死子仍由玩家确认；分析不更改棋盘、死子或正式比分。查看教学、重开、悔棋会取消旧请求，迟到的回复不会落到新棋局。

引擎未安装、启动失败或退出时会显示原因和重试按钮，不会冒充 KataGo 静默切换为入门陪练。详细失败日志位于游戏存档目录 `katago-error.log`。关闭游戏时退出本局创建的引擎进程。

引擎与模型各自保留官方许可，见 `licenses/ENGINE.txt` 和 `licenses/NETWORK.html`。模型许可为官方 2026 年公布的宽松许可，不应把所有现有权重一概描述为 CC0。本仓库的 Go Game Guru 题库仍单独遵循 CC BY-NC-SA 4.0。

`runtime/`、`downloads/` 不纳入 Git。克隆工程后运行安装器即可复现依赖。导出游戏时，将 `engines/katago/runtime` 放在游戏可执行文件旁的同名相对目录，同时将 `engines/katago/analysis.cfg` 包含在导出资源中。

官方依据：[源码与发布](https://github.com/lightvector/KataGo)、[分析协议](https://github.com/lightvector/KataGo/blob/v1.18.1/docs/Analysis_Engine.md)、[规则参数](https://github.com/lightvector/KataGo/blob/v1.18.1/docs/GTP_Extensions.md)、[模型列表](https://katagotraining.org/networks/)、[模型许可](https://katagotraining.org/network_license/)。
