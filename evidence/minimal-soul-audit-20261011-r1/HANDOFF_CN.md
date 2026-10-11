# 最小 Soul 审计交接

本次有界源码审计及报告已完成。完整产品目标和既有 CURRENT 续接指针保持原样；发布、部署和治理验收未完成。本阶段没有生产源码变更。

- 实际候选工作区：`/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard`
- HEAD：`df4bdffd252da810c278939e3f8678ba3dc77de4`
- 源码SHA256：`0574d86b7d40dd42e22774b3bd68d9f5e7705fda2cf805cfe58a31d3e777c2c7`
- 报告：[FINAL_AUDIT_CN.md](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/FINAL_AUDIT_CN.md)
- 变更范围：仅本 evidence 目录；冻结包、原源/测试、维护声明和七项参考指纹不变。
- 核验：最终构建exit0；39/39 Move测试；5个编译负例明确EC04001/EC05001，1个合法读消费者exit0；22/22完整性检查匹配。
- 失败历史：run01测试夹具EC07002已保留；run02夹具修正，生产未修复；外包原始摘要解析缺陷在foreign-validation.json规范化，原摘要保留。
- 独立性：两份独立源码报告及只读证据复核；最终报告另作只读复核。被平台限制的测试子代理未作为完成审查。
- 已确认：主动共享新root后另sender可拆内容；Origin可永久泛型容纳Soul；同对象卸载重装schema可降。均有明确前提，无现有private root无条件越权结论。
- 待讨论：私有/shared/custody承诺；原生namespace退出 vs 非原生/间接锁定；schema安装周期 vs 终身版本；hash/来源/owner/旧入口语义。
- 待补验：真实PTB/链上、实际package/Cap/Publisher、消费方组合、市场原操作、协议容量/gas压力；不能用本地PASS关闭Release。
- 原记录：DOF-001 / Rec0C78FYL0KD，C01相关附件；不更换Owner/状态，不向Slack发消息。手册v1.0适用章节见报告第8节。
- 恢复：无需源码回滚；保留全部审计材料。任何修复创建新候选并重验受影响不变量。
- 下一步：先由原产品/来源Owner决定前三项契约，再在新候选执行必要修复和来源/消费方符合性验证。

主仓 `scripts/codex/phase_handoff.py` 限制输出到其所属仓的 docs/codex/handoffs。本阶段使用该脚本 dry-run 生成并保留模板，在 canonical 标准仓保存此精简交接，没有重写主仓指针。原始模板和调用收据位于 logs/handoff-helper-*。

如另开后续任务，可用本文件作为唯一交接入口；先读取报告和candidate.json，不重放整个聊天。
