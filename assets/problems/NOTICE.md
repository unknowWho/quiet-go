# Go Game Guru 题库署名与改编说明

来源：[Go Game Guru / Go Problem Collections](https://github.com/gogameguru/go-problems)。
作者／维护者：David Ormerod、An Younggil（原仓库介绍为职业八段）。

使用版本：`eee12b2e39d59dbe81a8b9eaa7d4f103978d9224`，获取日期：2026-10-14。

原题以及本目录 `library.json` 中的转换题目、题面中文转述，均按 **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International（CC BY-NC-SA 4.0）** 提供。保留署名、来源和改编说明；许可包含非商业与相同方式共享条件。商业发行前须取得适用授权或替换这部分题库。

- [原仓库许可](https://github.com/gogameguru/go-problems/blob/eee12b2e39d59dbe81a8b9eaa7d4f103978d9224/LICENSE)
- [CC 许可说明](https://creativecommons.org/licenses/by-nc-sa/4.0/)
- 完整许可原文：`gogameguru/LICENSE.txt`。
- 上游介绍：`gogameguru/UPSTREAM_README.md`。
- 上游提交与目录记录：`gogameguru/commit.json`、`gogameguru/tree.json`。

## 收录与处理

收录每周题集的 easy、intermediate、hard 三组，各 140 道，共 420 道。三组题面均不相同（未进行旋转或镜像扩充数量）。另有 10 道本项目原有入门练习，不来自本题集。

题集包含死活、劫争、对杀、连接及其他手筋，不把全部题目标成无条件做活／杀棋。难度保留上游主观分级，不映射职业或业余段位。

原始 SGF 文件保存在 `gogameguru/sgf`，字节不变。生成数据保留 19 路原盘面、坐标、先行方、合法变化、作者评注、A/B 等字母与三角标记。游戏放大局部使用镜头，不裁切规则棋盘或增加棋盘边界。

转换由 `tools/build_puzzles.py` 完成；每题记录稳定编号、原始文件 SHA-256、来源网页及许可。以作者明确的 `Correct` / `Also correct` 结论标记识别成功，反向标出通向正确结论的分支；不会把未标记的叶节点自动当作正确答案。英文评注未批量翻译或另编结论。若作者在中间节点已标明正确，允许在那里完成题目，后续原谱节点仍保留。

已记录的兼容处理：

1. `ggg-intermediate-50.sgf` 原文末尾多一个右括号，仅在解析副本中忽略它，不改写源文件。
2. `ggg-easy-102.sgf` 一条未通向正确结论的旁支会重复历史盘面，游戏采用位置禁全同，故从可操作树移除此分支。没有删除任何作者标注的正确结论。
3. `other/ggg-eternal-life.sgf` 为涉及不同规则的循环演示，`other/heart-go-problem.sgf` 没有明确正确标记；两文件保留作来源记录，未计入可答题目数量。

原始题谱标注的规则为 Japanese；本软件检查棋步合法性使用现有禁自杀、位置禁全同引擎。练习按原题局部参考解结束，不调用中国数子评分来猜测生死，不把劫活等结论解释成无条件活棋。自动化检查证明已收录着手可合法重放，不能证明作者解答穷尽所有可能着手。

转换报告见 `evidence/puzzle-import.json`；引擎复核报告见 `evidence/puzzles-results.json`。可用 Python 标准库重新运行导入，不需要联网。
