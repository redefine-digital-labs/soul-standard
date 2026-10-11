# Soul 安全与正式发布复查

日期：2026-10-11。范围：当前 280 行 Soul 标准内核、它的原有测试、此前保存的安全场景与外部消费者编译探针。

## 结论先看这里

**本轮未发现可复现的内核越权漏洞；目前还不能给出“已经没有漏洞，可以直接正式发布”的结论。**

重新构建成功，39 项本地测试全部通过，6 个外部消费者编译检查全部符合预期。当前生产源码和原有测试没有修改。

按你确认的定位，Soul 是允许组合、允许创建方选择共享变种的最小资产内核。本轮没有把这些能力本身算作漏洞，也没有建议为了审计删掉 store、伙伴嵌套或泛型组合。

目前可以继续做正式发布前的验证。真正缺的是具体发布目标、有效升级权限、实际创建交付和应用组合的验证证据，不是已经证实有人能盗走私人 Soul。

## 小π有没有被别人拿走的漏洞？

在本次审阅和本地测试范围内，未发现以下路径：

| 想尝试的操作 | 本轮结果 |
| --- | --- |
| 陌生人仅凭 ID 就取用另一地址私人持有的小π | 私人对象库存对照拒绝，未发现本内核能绕过 Sui 所有权的入口 |
| 强化时把原装备换成另一件不同 ID 的装备 | 提交时拒绝 |
| 用小π的编辑凭条，给另一个角色交还对象 | 提交时拒绝 |
| 不交还对象，复制、丢弃或保存 Edit 凭条后成功结束交易 | 对应外部代码不能通过编译；本文件的凭条消耗路径核对原角色、原对象及 revision |
| 整件拆走 removable=false 的扩展 | 拆卸时拒绝；正常同 ID 编辑仍然可用 |
| 外部直接取得根 UID，或构造原生伙伴标记 | 对应外部代码不能通过编译 |
| 修改伙伴时用新 Soul 替换原伙伴 | 提交时拒绝 |
| 使用过时 revision、错误类型、错误命名空间 | 对应操作拒绝 |

第一项本地测试使用 Sui 的 test_scenario 库存模型，没有执行真实链上的攻击交易。因此结论是“没有发现本内核的绕过路径”，不能把它写成“已经完整证明所有真实 PTB 场景都安全”。

Sui 对地址持有对象的交易输入实施所有权规则，说明见 [Sui 地址持有对象文档](https://docs.sui.io/develop/objects/object-ownership/address-owned)。这份内核要求调用者实际取得 `&mut Soul`，而不是只提交角色 ID。

## 这些行为要理解清楚，但不能直接叫漏洞

### 1. 共享的小π允许公开拆卸可拆内容

创建方可以在创建交易中把新 Soul 直接共享。共享后，本文件的 `uninstall` 和 `unnest` 没有另外检查玩家地址，因此其他人可以取走可拆扩展或原生伙伴。

如果产品允许这种开放玩法，这就是使用规则。如果应用承诺“共享养成，但只有指定玩家可以拆装备”，它还需要自己的权限设计；当前内核没有作出这个承诺。

私人地址持有的小π没有因此自动变成共享对象。共享 Maker 再创建并交付私人 Soul，也不等于共享 Soul。固定版本的共享条件见 [Sui transfer 源码](https://github.com/MystenLabs/sui/blob/2a0becb2fcc6989e492981104af67f62f2c9511a/crates/sui-framework/packages/sui-framework/sources/transfer.move)。

### 2. 原生伙伴可拆，其他组合要看各自规则

`nest` 固定把伙伴设成可拆。通用 `install` 也允许把 Soul 装到其他命名空间，并选择不可拆。

此前测试确认，可以用 `Origin` 值作为同模块标记完成这种非原生安装。这要求调用者已经能合法使用父 Soul 的可变访问，并控制要安装的子 Soul，没有证明陌生人能够锁住别人的私人角色。

所以，原生伙伴的可拆保证只覆盖原生路径。接收一个组合角色时，应该读取全部描述和 removable 设置，而不只检查原生伙伴列表。

### 3. schema 是登记的格式编号

持续安装期间，`commit_update` 不允许降低扩展 schema。可拆对象卸下再重新安装，旧描述已经删除，新安装可以使用较小的正数编号。

这个行为不改变对象 ID，也不绕过 revision。如果应用把它当作“对象终身不可逆的迁移版本”，该应用需要额外维护和验证自己的版本规则。

### 4. 指纹不是所有业务事实的证明

body_hash 只覆盖直接对象的 BCS 数据；semantic_hash 通常是应用提交的 32 字节。它们不自动证明所有深层动态对象、版权、外部资源或业务资格。

manifest_hash 汇总根字段和已登记的描述，包含 revision，但不包含当前持有人。正常转让之后，manifest_hash 和 minted_by 可以保持原值。

因此，应用不能只凭一个旧 manifest_hash 判断“这个玩家现在仍持有小π”。应按当前对象所有权及应用自己的授权规则核对。

这些范围在源码中是明确的最小内核边界。本轮没有确认它们违反当前已经认可的产品要求；它们会影响应用怎样正确使用标准。

## 实际重新执行的检查

| 检查 | 本次实际结果 |
| --- | --- |
| 隔离副本的生产构建 | exit 0 |
| 原有测试 + 已有安全场景 + 已有边界场景 | 39/39，通过，0 失败，39 个唯一测试 |
| 外包访问私有根 UID | 编译按预期拒绝，EC04001 |
| 外包构造原生嵌套标记 | 编译按预期拒绝，EC04001 |
| 外包复制 Edit | 编译按预期拒绝，EC05001 |
| 外包丢弃 Edit | 编译按预期拒绝，EC05001 |
| 外包存储 Edit | 编译按预期拒绝，EC05001 |
| 合法外部只读消费者 | 编译成功 |
| 原生产文件、原测试和所用场景文件的完整性 | 输入字节全部保持不变 |
| module.json 完整性 | 保持不变 |

39 项由原有 26 项、此前 10 项安全场景和 3 项边界场景组成。这次是重新执行已有场景，没有声称新增了 39 项测试。部分测试是在确认共享拆卸、非原生不可拆安装、重装降低 schema 等行为存在；通过不表示这些行为被删除或修复。

所有命令都在本地编译／Move 测试 VM 中执行。`-e mainnet` 指构建环境，不代表已经在主网上执行了交易。未提高 gas-limit，未发送交易，未签名或花费资金，未提交、推送或发布代码。本轮为执行者复查，不是合格独立人员的发布验收，也不是外部审计认证。

可读回的原始材料：

- [输入与版本记录](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-release-recheck-20261011-r2/inputs.json)
- [本次命令及结果](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-release-recheck-20261011-r2/checks.json)
- [39 项测试原始日志](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-release-recheck-20261011-r2/logs/combined-tests.log)
- [生产构建日志](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-release-recheck-20261011-r2/logs/production-build.log)
- [原件完整性检查](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-release-recheck-20261011-r2/integrity.json)
- [此前完整审计及行为说明](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/FINAL_AUDIT_CN.md)

## 为什么现在还不能直接正式放行？

当前 [module.json](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/module.json) 的发布相关记录仍是：

| 记录 | 当前值 | 缺的实际信息 |
| --- | --- | --- |
| release_units | 空列表 | 哪个确切包／产物是本次发布或升级单位 |
| production_targets | 空列表 | 拟发布到哪条网络，针对哪个包或部署目标 |
| compatibility.consumers | 空列表 | 哪些实际创建系统、扩展或应用使用这一版本及其组合验证 |
| release_readiness.status | pending | 发布候选、验证与验收证据 |
| release_readiness.candidate_identity | null | 被正式放行的确切版本 |
| agent_contract.acceptor.actual_identity | null | 实际独立验收人及其验收证据 |

空记录不能证明没有部署、没有消费者或没有升级能力；它说明本次标准候选还缺少可核查的发布材料。这份判断不覆盖其他包或旧产品的上线状态。

发布前需要完成三组具体工作：

1. **固定发布版本与权限。** 确定是首次发布还是已有包升级，固定目标网络、源码／字节码、依赖和类型身份。首次发布要明确 Publisher、UpgradeCap 的交付与控制方案；已有包升级要核对真实包和全部有效升级路径。UpgradeCap 控制后续代码升级，与玩家当前对象所有权分属不同的权限。[Sui 升级文档](https://docs.sui.io/develop/publish-upgrade-packages/upgrade)
2. **验证实际使用流程。** 在测试环境用真实 PTB 跑创建及交付、A 转给 B、旧持有人与陌生人尝试取用、安装／编辑／交还／拆卸、伙伴组合与退出。核对实际创建入口和使用这一版的扩展，而不只运行示例测试。
3. **完成适用边界测试与独立验收。** 本次没有新增容量 64/65 项、240 KiB 精确字节边界、深层组合、实际 Gas／协议限制或跨版本测试。按实际使用范围补上这些检查，并由具备相应能力的独立验收人核对同一候选。若已有发布记录，应一并读回；首次部署后的产物和权限读回另作为部署验收。

并不要求把 Maker、市场或收费逻辑加进 Soul。对没有使用的业务和不存在的升级迁移，不应虚构测试需求；实际用到的入口与版本组合则需要验证。

## 本轮候选与后续边界

- 源码：[soul.move](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/move/soulidity_standard/sources/soul.move)，280 行。
- 源码 SHA-256：`0574d86b7d40dd42e22774b3bd68d9f5e7705fda2cf805cfe58a31d3e777c2c7`。
- 仓库 HEAD：`df4bdffd252da810c278939e3f8678ba3dc77de4`。
- Sui 依赖：`2a0becb2fcc6989e492981104af67f62f2c9511a`。
- CLI：`sui 1.78.1-homebrew`，与此前审计的 CLI 二进制哈希一致。
- 检查方式：重新源码审阅、现有证据核对、隔离输入构建与测试、外部消费者编译检查。
- 本轮没有新的独立人员审阅；以前的内部 AI 审阅是历史材料，不能冒充本轮独立发布批准。
- 适用项目手册 v1.0：Sui 权限、abilities、PTB、版本／升级和完成判断；未执行的发布及真实权限检查仍为待核验。
- 原业务记录和 Owner 沿用 module.json；original_record_ref 仍未确定，不自行建立另一个看板，也不写入外部系统。

源码、依赖、生产入口或升级权限发生变化后，需要复查受影响部分。下一步是固定具体发布候选和实际创建／交付流程，完成缺失的验证；本轮没有授权或执行正式发布。
