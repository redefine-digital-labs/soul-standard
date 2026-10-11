# Soul 与 Sui 开源资产方案对照检查

日期：2026-10-11。检查对象：当前 280 行 Soul，生产源码未修改。

## 先看结论

**当前设计适合“可转让、可成长、可组合的独立角色资产”。本轮未发现可复现的私人资产越权漏洞，但不能据此保证零漏洞或直接批准正式发布。**

对照官方与第三方源码，没有找到需要为了模仿其他标准而删除 `store`、伙伴嵌套或编辑机制的理由。新增 7 项组合测试后，隔离副本构建成功，**46/46 项本地测试通过**。

目前最需要讲清的三件事：

1. **能组合，不等于任何现成 NFT 都能直接安装。** 有些资产需要应用编写包装模块。
2. **有交易政策，不等于每次普通转账都被政策拦截。** 强制版税、指定地址才能转让等承诺，需要另外设计。
3. **指纹有明确范围。** 不自动证明全部深层内容、来源声明的真实性或当前持有人。

这些是应用接入和产品承诺的边界；在你认可的最小资产内核定位下，本轮没有把它们直接归为漏洞。

## 与哪些源码比较了？

| 参照 | 它解决什么问题 | 对 Soul 的实际启示 |
| --- | --- | --- |
| Sui 官方 Coin | 可拆分、可合并的同质货币，带余额和供给控制 | `Coin<T>` 也有 `key + store`。Soul 不必复制货币余额和供给逻辑 |
| Sui 官方 NFT 示例 | 独立对象的创建、转让、描述修改和销毁 | NFT 同样可以有 `key + store`；修改依赖取得对象的可变访问 |
| Sui 官方 Kiosk | 资产存放、挂牌、买卖及受权限控制的操作 | 用凭条保证临时借出的对象原样归还；Soul 的 Edit 属于同类设计 |
| Sui 官方 Token | 操作受政策控制的闭环代币 | `Token<T>` 有 `key` 而无 `store`；与 Soul 的自由转让目标不同 |
| Sui 官方 TransferPolicy | 检查交易请求是否完成所需规则 | 需要接入具体交易流程，不会自动包办所有转账 |
| OriginByte NFT / NftBag / Witness | NFT 类型、组合容器和模块授权 | 组合与标记授权有其他开源实例；它们的权限粒度与 Soul 不完全相同 |

主证据：[Coin](https://github.com/MystenLabs/sui/blob/2a0becb2fcc6989e492981104af67f62f2c9511a/crates/sui-framework/packages/sui-framework/sources/coin.move)、[官方 NFT 示例](https://github.com/MystenLabs/sui/blob/2a0becb2fcc6989e492981104af67f62f2c9511a/examples/move/nft/sources/testnet_nft.move)、[Kiosk](https://github.com/MystenLabs/sui/blob/2a0becb2fcc6989e492981104af67f62f2c9511a/crates/sui-framework/packages/sui-framework/sources/kiosk/kiosk.move)、[Token](https://github.com/MystenLabs/sui/blob/2a0becb2fcc6989e492981104af67f62f2c9511a/crates/sui-framework/packages/sui-framework/sources/token.move)、[TransferPolicy](https://github.com/MystenLabs/sui/blob/2a0becb2fcc6989e492981104af67f62f2c9511a/crates/sui-framework/packages/sui-framework/sources/kiosk/transfer_policy.move)、[OriginByte NftBag](https://github.com/Origin-Byte/protocol/blob/e8e8efd77ab15d7b2cf30958fd748dbb3afbdaab/contracts/nft_protocol/sources/standards/composability/nft_bag.move)。

官方参照固定为本包依赖的 Sui 提交 `2a0becb…`，用来检查同版本机制。OriginByte 固定为 `e8e8efd…`，提交日期为 2024-03-13，作为历史设计参照；没有编译或全面审计该项目，也不代表它现在适配本工具链或安全。没有覆盖所有 Sui 开源项目，没有仅按代码行数、知名度给安全排名。

## Soul 哪些设计有合理依据？

**私人持有依赖 Sui 所有权，是正常做法。** 拆卸、安装和编辑都需要实际取得 `&mut Soul`，不是知道小π的 ID 就能操作。Sui 官方 NFT 的描述修改也依赖可变对象输入。本轮没有找到把别人的地址持有 Soul 作为可变输入的内核绕过入口。[Sui 地址持有对象规则](https://docs.sui.io/develop/objects/object-ownership/address-owned)

**保留 store 有明确用途。** Coin、官方 NFT 示例和 OriginByte 的 `Nft<C>` 都使用 `key + store`，用来支持转让和组合。它不代表陌生人可以操作别人的私人对象。[OriginByte NFT](https://github.com/Origin-Byte/protocol/blob/e8e8efd77ab15d7b2cf30958fd748dbb3afbdaab/contracts/nft_protocol/sources/collection/nft_wrapper.move)

**编辑凭条不是随意发明的权限办法。** Kiosk 的 `Borrow` 没有可复制、可丢弃或可存储能力，并检查原 Kiosk 与原对象 ID。Soul 的 `Edit` 同样不能被随意处理，还核对父 Soul、子对象和 revision。新增测试确认，两种凭条能在同一流程中配合使用。[Kiosk borrow_val / return_val](https://github.com/MystenLabs/sui/blob/2a0becb2fcc6989e492981104af67f62f2c9511a/crates/sui-framework/packages/sui-framework/sources/kiosk/kiosk.move#L590-L608)

**限制可变访问有利于保持登记一致。** Soul 没有把根 UID 或子模块的可变引用公开给外部；更新通过取出、交还、刷新描述完成。OriginByte 采用更开放的组合访问路径。两者是不同取舍，不能由此笼统宣布哪个项目全面更安全。[OriginByte 组合访问](https://github.com/Origin-Byte/protocol/blob/e8e8efd77ab15d7b2cf30958fd748dbb3afbdaab/contracts/nft_protocol/sources/standards/composability/nft_bag.move)、[标记授权](https://github.com/Origin-Byte/protocol/blob/e8e8efd77ab15d7b2cf30958fd748dbb3afbdaab/contracts/permissions/sources/permissions/witness.move)

## 查出的限制和待讨论项

### 1. 其他 Coin / NFT 不一定能直接挂载

Soul 的 `install<W,T>` 除了要求 `T: key + store`，还要求 W 与 T 来自同一原始包和模块。**光有 store 不够。**

实际测试：用我们自己的 Witness 安装框架 `Coin<SUI>`，按预期报 EAuthority。用我们自己的 CoinModule 包装 Coin，再用同模块 Witness 安装，则安装、余额变化、交还、拆卸全部成功，包装对象 ID 保持不变。

对小π而言：外来的装备可能要先接好标准接口，才能登记到角色身上。不是改掉 Soul，也不是凭空获得该资产发行方权限。

需要讨论：是否提供应用层适配示例；宣传应写“支持符合接口的扩展与适配组合”，而不是“任意 NFT 都能直接安装”。本轮没有证明所有第三方资产都不能直接装；它们是否提供可用标记，需要逐个检查。

### 2. 交易规则需要明确接入方式

**普通转账不会自动经过 TransferPolicy。** 新测试创建了带规则的 `TransferPolicy<Soul>`，小π仍能通过 `public_transfer` 正常交给另一地址，没有生成或确认交易请求。

而 Kiosk 的购买流程返回不可随意丢弃的 TransferRequest，调用者需要完成该流程的政策检查。新增购买测试通过的是空规则政策，未测试真实版税规则或锁定规则。[TransferPolicy 源码](https://github.com/MystenLabs/sui/blob/2a0becb2fcc6989e492981104af67f62f2c9511a/crates/sui-framework/packages/sui-framework/sources/kiosk/transfer_policy.move)

另一个接入点：所有生产方创建的对象都是同一个 Soul 类型。`TransferPolicy<Soul>` 的构造检查属于 Soul 包的 Publisher，Maker 自己包的 Publisher 不会自动获得该权限。已有两个 Publisher 测试已再次通过。多个政策或按 Origin 区分规则，需要应用明确选择、验证；不能默认“每个 Maker 自带独立集合政策”。

需要讨论：是否只是普通自由交易，还是承诺强制版税／转让限制。前者与现有内核吻合；后者不能仅依靠当前 Soul 与一份政策实现。

### 3. 共享玩法要区分两种情况

| 使用方式 | 谁能拆可拆内容？ |
| --- | --- |
| 小π交给私人地址 | 正常情况下由实际持有人取得可变访问后操作 |
| 共享 Maker 创建小π，再交给私人地址 | Maker 共享不改变小π的私人持有状态 |
| 新的小π本身直接共享 | 当前内核允许其他人拆卸可拆模块和原生伙伴 |
| 小π存放在共享 Kiosk | 由 Kiosk 入口和对应 OwnerCap 等规则控制取用 |

本轮错误 Kiosk 凭证测试按预期拒绝。Kiosk 共享，不等于其内部资产允许任何人直接拆卸。

你认可开放共享变种，因此“允许共享”本身不是漏洞。如果未来承诺“大家能养成，但只有指定人能拆装备”，则需要应用层加对应权限。

### 4. 永久装备、伙伴和版本的承诺不要扩大

- `removable=false` 保证不能用内核拆卸入口取走整个模块；不自动冻结模块内容，也不保证模块里所有资金永远不能通过合法编辑取出。
- 原生 `nest` 的伙伴固定可拆。通用安装路径还能形成不同命名空间的 Soul 组合；已有测试确认 Origin 值可作为同模块标记形成不可拆的非原生 Soul 安装。
- 持续安装期间，编辑不允许降低 schema；卸下再装会创建新描述，可使用较低的正整数 schema。它不是对象终身版本锁。

这些行为要求调用者合法取得父角色的可变访问，没有证明陌生人能锁住私人角色。需要讨论的是标准的承诺范围，不能只看“原生伙伴可拆”便假设全部组合都可拆。

### 5. 指纹与来源是有范围的记录

- `body_hash` 覆盖直接对象 BCS，不递归包含该对象全部动态子对象。
- 通用 `semantic_hash` 是应用提交的 32 字节；应用需要定义和计算其业务含义。原生伙伴路径会计算子 Soul 的 manifest_hash。
- `source_version / source_hash` 是发行方提供的声明，不自动验证真实源对象的版本或内容哈希。
- `minted_by` 记录创建交易发送者，不是当前持有人；转让可不改变 manifest_hash。

所以，买家不能仅凭“哈希没变”就认定所有深层物品没变，也不能用旧 manifest_hash 代替当前所有权检查。若产品没有承诺这些更强保证，它们是明确的适用边界；若承诺了，就会形成业务安全问题。

## 本轮实际验证

| 新增对照场景 | 结果 |
| --- | --- |
| 外部 Witness 直接安装框架 Coin | 按预期拒绝，Soul abort 3 |
| Coin 包装模块安装、编辑、拆卸 | 成功；对象 ID 与剩余余额符合预期 |
| Kiosk 临时借出 Soul，再用 Edit 更新模块并交还 | 成功；原角色和原装备 ID 保持不变 |
| 用另一 Kiosk 的 OwnerCap 借出 Soul | 按预期拒绝，Kiosk abort 0 |
| 对已挂牌 Soul 取得可变借用 | 按预期拒绝，Kiosk abort 9 |
| 存在带规则政策时直接转给另一地址 | 成功；确认政策不会自动拦截该路径 |
| 从 Kiosk 买下带伙伴 Soul，再由买家拆出原伙伴 | 成功；购买金额、销售收益、角色指纹和伙伴 ID 符合预期 |

这轮完整运行 **46 个唯一测试**：原有 26 项 + 前轮 13 项审计场景 + 本轮 7 项。通过的负面场景表示“在预期位置拒绝”；确认边界行为的场景通过，不表示该行为已被修复或禁止。

构建与测试在隔离副本中进行，生产文件、原测试与 module.json 保持不变。使用 `sui 1.78.1-homebrew`，依赖与原包一致；没有提高 gas-limit。Coin 和政策使用官方 test_only 构造帮助，运行于本地 Move 测试 VM；`-e mainnet` 不代表主网执行。这轮没有运行真实链上 PTB、真实币支付、实际商业版税或全套第三方协议。

[新测试源码](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/soul-open-source-comparison-20261011-r3/package/tests/comparison_integration.move) · [命令和结果](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/soul-open-source-comparison-20261011-r3/checks.json) · [46 项测试日志](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/soul-open-source-comparison-20261011-r3/logs/tests.log) · [上游版本及文件哈希](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/soul-open-source-comparison-20261011-r3/upstream_sources.json)

前轮 5 个编译拒绝探针和 1 个合法消费者编译检查的成功结果见 [前轮复查](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-release-recheck-20261011-r2/REPORT_CN.md)；本轮未重复运行它们，也没有把它们算作新增测试。

## 是否足够适合，是否足够安全？

**适合当前定位：** 独立身份、自由转让、装备／伙伴组合、同 ID 成长更新、登记与指纹校验。这些功能有合理的 Sui 机制基础，本轮没有发现必须重写内核的证据。

**目前没有证实的攻击：** 陌生人拿走地址私有 Soul；编辑时替换原对象；凭条交给另一角色；复制／丢弃／保存 Edit 绕过交还；用拆卸入口取走不可拆模块。这里是限定检查范围内的“未发现”，不等于全面证明不存在。

**不直接满足的更强承诺：** 任意第三方 NFT 无适配直接安装、全部转让强制版税、共享后只有指定人能拆内容、永久模块等于内容永久冻结、完整递归状态证明、来源声明自动验证、终身 schema 不可回退。

**正式发布仍缺：** 对同一候选的真实创建／交付与交易验证、适用容量和深度／Gas 边界、实际依赖及升级类型组合、Publisher 与 UpgradeCap 权限方案，以及合格独立验收。不要把未使用的市场功能硬加到内核；验证应覆盖真正准备使用的入口。

当前发布记录仍为 pending，具体目标、消费者与实际验收人未在本候选记录中确定。记录缺失不证明没有旧部署，但不足以批准这个候选正式发布。本轮属于源码比较和执行者检查，没有外部审计认证或新一轮独立人员验收。

## 输入和交付记录

- Soul 源码：[soul.move](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/move/soulidity_standard/sources/soul.move)，280 行。
- SHA-256：`0574d86b7d40dd42e22774b3bd68d9f5e7705fda2cf805cfe58a31d3e777c2c7`。
- HEAD：`df4bdffd252da810c278939e3f8678ba3dc77de4`。
- Sui：`2a0becb2fcc6989e492981104af67f62f2c9511a`。
- 阶段：本轮比较审阅与本地 Build / Test 已完成；Release / Deploy 未批准、未执行。
- 适用手册：Sui 所有权、abilities、交易组合、版本／升级及证据范围；不变更原 Owner、发布权限或业务里程碑。
- 原记录入口沿用 module.json；original_record_ref 尚未确认，本轮证据留在此仓库，不另建看板或向外部系统发送。
- 没有修改生产合约，没有提交、推送、签名、花费资金或部署。新增文件限于本轮证据目录。

