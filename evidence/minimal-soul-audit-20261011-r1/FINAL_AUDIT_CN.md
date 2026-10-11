# 最小 Soul 标准审计归档报告

日期：2026-10-11。范围：当前 280 行 Sui Move Soul 内核及冻结的测试/依赖输入。报告用于长期留档，结论绑定下列版本；源码、依赖、发行路径、升级权限或消费者改变后，需要重新核验相关结论。

## 1. 结论

**这份代码实现了边界清楚的最小资产内核。在本次源码审阅和本地测试范围内，未发现陌生人绕过 Sui 私有对象所有权、替换受保护子对象 ID、伪造原生嵌套命名空间或让未完成编辑成功落盘的路径。**

但不能把这个结论扩大为“所有 Soul 永远私有”“所有 Soul 内含关系随时可退出”“schema 在对象整个生命周期内只能上升”或“manifest 证明所有外部权利和当前持有人”。本次确认了三项实际行为：

1. **创建当次主动共享的 Soul，允许另一地址取走可拆卸模块或原生嵌套 Soul。** 对共享状态具有高影响；对已经正确私有持有的 Soul 未证明越权。当前产品校准说的是“默认地址私有，可选托管/共享另行说明”，因此这是必须处理的所有权状态边界，不能直接归类为默认私有 Soul 的无条件高危漏洞。
2. **公开的 `Origin` 元数据可以作为泛型见证，把另一枚 Soul 永久安装在非原生命名空间。** 不会伪造 `NestedSoulWitness`；它说明原生 `nest/unnest` 的退出保证不能自动覆盖所有泛型容纳关系。
3. **可拆卸模块卸载后，同一个对象重新安装时，schema 可以从 2 改为 1。** 更新时的单调检查仍有效；卸载/重装开始了新的描述记录，root revision 继续上升。

本地构建 exit 0，最终合并测试 **39/39** 通过；外部消费者编译探针为 **5 个按预期拒绝 + 1 个合法消费者成功**。这些通过结果包含“确认边界行为存在”的测试，不表示三个讨论项已经修复。生产源码未修改。

发布资格仍待核验：实际 package/type origins、所有有效 UpgradeCap/Publisher 路径、消费方版本组合和原业务操作没有被本次本地审计证明。报告完成与产品放行是两个状态。

## 2. 精确候选与方法

| 项目 | 固定值 |
| --- | --- |
| 仓库 | `/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard` |
| HEAD | `df4bdffd252da810c278939e3f8678ba3dc77de4` |
| 生产模块 | [soul.move](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/move/soulidity_standard/sources/soul.move:1)，280 行、11,430 bytes |
| 源码 SHA256 | `0574d86b7d40dd42e22774b3bd68d9f5e7705fda2cf805cfe58a31d3e777c2c7` |
| Sui 依赖 revision | `2a0becb2fcc6989e492981104af67f62f2c9511a` |
| CLI | `/opt/homebrew/bin/sui`，`sui 1.78.1-homebrew` |
| CLI SHA256 | `59838401ed487fc0c3aeeb1f4a0f47c2d0b3a564d1945d6f2d4c3e79af966354` |
| 构建/最终测试环境 | `-e mainnet`；本地 Move VM，未执行链上交易；没有 gas-limit override |
| 冻结记录 | [candidate.json](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/candidate.json) |
| 完整性复验 | [integrity.json](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/integrity.json)：22/22 哈希检查匹配，HEAD、CLI 未变 |

方法：逐段源码/权限/状态机审阅；独立源码与维护契约审阅；原有测试复验；隔离副本上的场景与边界测试；独立外部消费者包的编译负例；独立只读证据核验。所有执行与新增文件位于本报告的 evidence 目录。原生产文件、原测试、冻结快照、维护声明和受保护 CURRENT 指针均保持不变。

独立审阅原件：[source_review.md](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/reviews/source_review.md)、[contract_review.md](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/reviews/contract_review.md)。它们记录的是审阅当时的源码证据，其中 `not_run` 测试向量由本报告的实际执行结果补充；未运行的项目继续保留。

## 3. 已验证的内核设计

可以把 Soul 理解为“有固定身份证的资产本体”。Origin 是来源记录；Descriptor 是可选内含对象的目录；typed DOF 是实际存放对象的位置；Edit 是必须在同一成功交易内归还原对象的编辑凭条；revision 是内容变动计数；manifest 是这一刻的目录快照。

| 设计约束 | 源码与验证结论 |
| --- | --- |
| 资产身份与来源 | `new` 使用实际 `&P` 和同模块 `SoulProducer`，记录真实 source ID、完整类型和 sender；来源业务真实性另由来源验证 |
| 模块隔离 | 私有 `ModuleKey<W>` 构造器、完整 namespace、标签和 value type 隔离实际 DOF；跨模块/错误类型/重名拒绝测试通过 |
| 修改 authority | 取得实际 `&mut Soul` 是核心权限边界；私有 root 依赖 Sui 所有权，托管/共享需要相应控制 |
| 编辑原子性 | Edit 无 copy/drop/store；开始编辑锁住目录证明与其他修改；提交绑定原 root、原 child ID 和 revision |
| 永久直接容纳 | `removable=false` 禁止直接卸载；合法更新保留原 ID/不可拆标志；替换 ID、换 root、schema 倒退拒绝 |
| 原生嵌套 | 私有 `NestedSoulWitness`；child ID 为实际键；原生安装 removable=true；更新传播 child manifest；多层转移和原 ID 退出通过 |
| 一致性 | install/uninstall/commit 增加 revision；CAS 拒绝旧 revision；编辑中不能签发 manifest；分页范围拒绝溢出输入 |
| 最小标准 | 一个生产模块；没有 Maker/市场/渠道/社区/收费/平台注册业务依赖；零模块 Soul 有效；外部关系和凭证无需强制装入 root |

以上是在冻结代码与本地测试条件下的结果，不包含升级后代码、任意来源模块或生产托管入口的行为。

## 4. 三项确认行为

### A-01：直接共享的新 Soul 不再具备私有持有人权限边界

**分类：条件性高影响所有权风险。** 源码位置：`Soul` 第 31 行；`new` 第 111 行；`uninstall` 第 181 行；`unnest` 第 269 行。

`Soul` 有 `key + store`，`new` 返回新对象值。Sui 允许同一交易中新建的这类对象调用公开共享接口。共享后的任何交易都能按共享输入规则取得 root 的可变访问。`uninstall/unnest` 没有 sender/持有人凭证要求，拆卸只验证类型、当前 revision 和 removable。因此共享方实际上公开了可拆内容的控制入口。[固定版本 Sui transfer 源码](https://github.com/MystenLabs/sui/blob/2a0becb2fcc6989e492981104af67f62f2c9511a/crates/sui-framework/packages/sui-framework/sources/transfer.move)

本地测试分别确认：A 新建并共享含模块的 root，B 取走原模块；A 共享含原生 child Soul 的 parent，B 取走原 child。返回的是原 ID。另有对照：已在前一交易地址持有的 root 不能后来直接共享；陌生 sender 的私有对象库存中不存在 A 的 root；真正持有人正常拆卸成功。

**限制：** 私有对照是 `test_scenario` 库存验证，未执行真实链上/PTB 输入权限试验。没有证明陌生人能把 A 已有的私有 Soul 变为共享，或仅凭 object ID/revision 就操作它。风险触发需要创建/托管方主动选择危险的共享状态。

需要明确普通发行、接收和交易是否只接受私有 root，以及可选容器允许哪种实际 custody。若承诺从创建起始终排除直接共享，需要审查所有可达创建/交付路径，公开返回原始值的入口仍会留下这种选择；只新增一个安全 wrapper 并不会关闭其他入口。若支持直接共享 root，需要对所有修改/拆卸入口建立真实 authority。限制 `store` 会影响公开转移和当前泛型/原生容纳设计，不能当作无兼容成本的修复。

简单比喻：私有 Soul 的可变访问像“只有房主才能打开的门”；直接共享把门交给了所有人。目录里的“可拆卸”规则不会再区分谁是房主。

### A-02：Origin 可用于非原生、永久的 whole-Soul 容纳

**分类：已确认设计边界；若产品承诺所有 whole-Soul 组合均可退出，则为条件性中等影响问题。** 源码位置：第 43、89、159、184、220、260 行。

`origin()` 返回可 copy/drop/store 的 `Origin`。泛型 `install<W,T>` 只要求 W 与 T 的原始包/模块相同；`Origin` 与 `Soul` 恰好定义在同一模块。实际持有 parent 和 child 的调用方因此可以用 `Origin` 作为 W，把 child 装入自选标签，设置 `removable=false`。本次测试已确认安装、合法同 ID 更新和永久卸载拒绝。

这个描述项属于 `Origin` namespace，`unnest` 查询的则是 `NestedSoulWitness` namespace。原生构造器仍然私有，原生 nest 仍然 removable=true。源码第 258–259 行保证的是“this namespace”；这个窄保证成立，不能读成所有泛型包裹都可退出。

没有证明陌生人可锁住另一地址私有 Soul；调用方必须已经能使用 parent 的可变值并控制 child。一般目录能发现真实 value type/removable，单独扫描 `nested()` 会漏掉这种关系。

讨论选择：允许并明确披露非原生锁定关系；或规定直接 whole-Soul 容纳必须走原生关系并设计相应 type/namespace 保留规则。仅禁止泛型 `T=Soul` 仍无法排除自定义扩展对象内部另包一个 Soul，不能宣称由此禁止一切间接锁定。

简单比喻：`nest` 提供可打开的原生盒子，泛型 install 也允许主人自己选用封死的盒子。需要说明哪些盒子在退出承诺之内。

### A-03：schema 单调性仅覆盖一次持续安装

**分类：已确认生命周期/兼容边界；若要求同对象终身单调，则为 P2 契约问题。** 源码位置：第 164、187、211 行。

`commit_update` 拒绝 schema 下降；`uninstall` 删除描述记录；再次 `install` 仅要求 schema>0，没有历史最低值。本次测试用同 namespace/name、同对象 ID 执行 schema 2 安装 → 卸载 → schema 1 重装，成功，root revision 变为 3，manifest 变化。

这需要合法 root 可变访问和同模块见证；没有绕过永久模块卸载检查，也没有保留旧 root snapshot。消费者若把 descriptor.schema 理解为不可逆对象迁移版本，必须补上自己的生命周期规则。

优先明确“持续安装期间单调”。若来源需要不可逆迁移，可在 T 或来源权威状态维护最低版本，并检查所有重装/旧入口。只有明确要求标准维护终身最低值时才设计历史记录；其容量、同标签换对象和保留期限也要一并定义。

## 5. 需要讨论的其他边界

| 编号 | 实际保证 | 不能自动推出的保证 | 需讨论/补验 |
| --- | --- | --- | --- |
| D-01 哈希覆盖 | body_hash 是直接 T 的 BCS 哈希；semantic_hash 是来源提交的 32 bytes；原生嵌套另计算 child manifest | 自动遍历任意动态子对象、外部引用、内容服务、余额或业务权利 | 每个来源声明并验证 semantic 覆盖范围；消费方读取实际权威状态 |
| D-02 来源证明 | 实际 source 对象 ID、同模块 marker/type；版本>0、hash 长度32 | 正确供给/付款/版权/许可、源码内容正确、source 持有人或持续存活 | marker 是否公开暴露、接受哪些确切 producer/types、version/hash 意义及使用时验证 |
| D-03 所有权与授权 | manifest 是有顺序的 root/descriptor 状态快照；minted_by 是铸造交易 sender | 当前持有人、作者、授权代际、出售时撤销旧权限；相同集合必有相同哈希 | 授权按当前 holder/稳定Soul ID/来源代际/custody 中哪项生效；转移与 A→B→A 行为 |
| D-04 升级与旧写入口 | original/defining TypeName 表示类型谱系；CAS 表示当前 root revision；descriptor schema 表示声明版本 | 最新代码、最新发行者、旧版本入口已拒绝、不可升级 | 固定真实版本对，验证旧入口/迁移 guard 和所有有效 UpgradeCap 路径 |
| D-05 容量 | 每 root 最多64项；被安装的直接 child BCS 最多245760 bytes；失败交易原子回滚 | 无限安装、永久槽位可回收、任意有效大root都可嵌套、任意深度消费成本有界 | 64/65项、字节边界、失败回读、深度/gas与来源增长预算仍未精确测量 |
| D-06 冻结/托管 | 本地测试确认新 root 可公开冻结，陌生 sender 可读；标准不暴露 root UID/可变 child 引用 | 永远地址持有、被冻结后仍能拆卸、引用对象都随售 | 接收规则识别 immutable/shared/object-owned；可选容器的退出限制披露 |
| D-07 永久与源权限 | 冻结代码中不可直接卸载永久模块，编辑必须归还原 ID | 内部资金锁定、永久不可升级、可用性/源方永远提供编辑、全部内部资产不能退出 | 来源公开 API、内部可变 UID/子对象控制和有效升级策略分别核验 |
| D-08 标准集成 | init 可在本地构造标准 Publisher，允许相应 TransferPolicy 构造；独立类型检查通过 | 真实部署已有 Publisher、Publisher=UpgradeCap、所有 public_transfer 自动执行政策 | 初次发布 effects、实际 Publisher ID/owner、升级不重跑 init、实际市场 transfer 路径 |

D-01 的测试确实改变了扩展的动态 Leaf，同时 child BCS/body_hash 和来源提交的 semantic_hash 保持相同。**该次合法 commit 已使 root revision 增加、root manifest 改变**；不能表述为“root manifest 不变即可悄悄改变”。独立变化的外部共享引用是另外的语义边界，本轮未执行其场景。

D-03 的测试确认转移到 B 后 revision/manifest 不变、minted_by 仍为 A。旧 holder 因此没有继续取得私有 root 可变访问的权限；问题在于应用把快照误当成授权证明。目录顺序也是 v1 哈希语义的一部分，不能随意更改后宣称兼容。

D-04 中 `with_defining_ids` 指类型**首次被引入**的包，`with_original_ids` 指谱系原始包；不是每次升级的最新调用包。当前设计有意保持命名空间身份稳定，未发现“每次兼容升级都会造成 namespace 漂移”。[固定版本 TypeName 定义](https://github.com/MystenLabs/sui/blob/2a0becb2fcc6989e492981104af67f62f2c9511a/crates/sui-framework/packages/move-stdlib/sources/type_name.move)

## 6. 验证证据与可复现性

| 检查 | 实际结果 | 日志/收据 |
| --- | --- | --- |
| 原冻结包基线 | 26/26（24 kernel +2 Publisher） | [baseline-tests.log](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/logs/baseline-tests.log) |
| 第一组新增场景 | 10/10 | [adversarial-run-02.log](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/logs/adversarial-run-02.log)、[收据](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/logs/adversarial-run-02.json) |
| 最终 staged production build | exit0，未改生产源 | [combined-build.log](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/logs/combined-build.log)、[收据](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/logs/combined-build.json) |
| 最终 staged suite | **39/39**，原26+第一组10+边界3；不重复累计为75 | [combined-tests.log](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/logs/combined-tests.log)、[收据](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/logs/combined-tests.json) |
| 外包私有root UID/嵌套见证构造 | 2项因 `EC04001` 按预期拒绝 | [foreign-validation.json](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/foreign-validation.json) |
| 外包 copy/drop/store Edit | 3项因 `EC05001` 按预期拒绝 | 同上，保留各自原始日志和源哈希 |
| 外包合法读取 | exit0 | 同上，`valid_read_consumer` |

新增场景源：[audit_adversarial.move](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/probes/adversarial-kernel/tests/audit_adversarial.move)、[audit_boundaries.move](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/probes/adversarial-kernel/tests/audit_boundaries.move)。反例的 abort code 与 location 均明确匹配；编译负例有合法消费者作依赖/工具对照，不把任意构建失败当成功。

执行历史保留：run01 因测试夹具同一参数列表的借用冲突 `EC07002` 编译失败。run02 仅将 revision 提前读为局部变量，生产源未变，旧夹具与失败日志未删除。外包原始摘要的 ANSI 解析导致 `first_error=null`，规范化诊断另外写入 foreign-validation.json，原摘要保留。

一个测试子代理返回平台内容限制提示，未作为完成的独立测试审查计算。协调代理完成本地执行；另有完成的独立源码审阅与只读证据核验。独立证据核验当时确认26+10、六编译探针与原件完整性；后来新增的3项由最终39项收据证明，不能假称其已被该早期核验覆盖。 最终报告另经新的只读核验，确认39个唯一PASS、两份新增夹具及六外包源哈希、新3项行为与源码一致，无必须修正项；见[final_verification.json](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/reviews/final_verification.json)。

复现最终套件：

```sh
/opt/homebrew/bin/sui move build --path /Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/probes/adversarial-kernel -e mainnet
/opt/homebrew/bin/sui move test --path /Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/evidence/minimal-soul-audit-20261011-r1/probes/adversarial-kernel -e mainnet
```

## 7. 未覆盖与放行条件

本轮没有执行链上发布/升级、钱包交易、实际 PTB client 调用、主网 gas 测量、跨版本消费者组合、市场挂牌/取消/成交、来源业务授权/资金/内容/密钥交接、外部共享引用变化、精确容量/大小压力、真实 Cap 或治理托管读回。这些项目不能从39项本地测试推出通过。

`module.json` 的 release_units/production_targets/actual consumers 为空，release readiness 和实际维护/验收/authority 映射待补。空数组表示该声明还不完整，不表示生态没有消费者或没有有效升级权。源码不存在平台运行管理员，不等于已部署的包永久不可升级；升级 authority 与别人的私有对象输入 authority 也必须分开。

下一步讨论顺序：

1. 确认发行/消费允许的所有权状态，封住或明确拒绝 A-01 的危险使用方式。
2. 确认退出承诺仅限原生 namespace，还是覆盖 A-02 非原生/间接容纳。
3. 确认 A-03 schema 是安装版本还是对象终身迁移版本。
4. 给实际消费者写清 hash、owner、来源、旧入口、容量、随售/退出责任；按真实依赖组合验收。
5. 固定真实发布与有效权限，完成适用 release/部署读回后再谈放行。

无需为了以上讨论把 Maker、统一管理员、全平台白名单或所有外部资格放进最小核心。每一项保证由真正掌握相关状态的来源/消费入口证明。

## 8. 原记录的产品工程评审附件

本报告作为既有 DOF-001（`Rec0C78FYL0KD`）、标准核心 C01 相关审计附件使用，不创建新看板，不代改原 Owner、验收者或状态。canonical 模块的 current/original acceptance record 映射仍待明确；该引用不是声称已写入外部记录。用户授权为审阅自己代码并输出报告。

手册：v1.0，2026-10-06；适用章节1–4、5、7、8.3–8.4、9、12；按原 Plan → Code → Build → Test → Release → Deploy → Operate → Monitor 区分阶段与完成状态。本轮为源码审阅/Build/Test 证据产出，产品 Release/Deploy/Operate/Monitor 未由此关闭。

| 检查域 | 结论与证据 | 剩余责任 |
| --- | --- | --- |
| 管理/产品/敏捷 | 最小核心与可选外部能力方向一致；A-01/02/03 契约决定待核验 | 原来源 Owner 与实际验收者确认，不替代历史职责 |
| DevOps/恢复 | 冻结输入、失败历史、最终日志/收据、完整性通过；没有生产载荷变更 | 新候选需新哈希/回归；生产恢复未执行 |
| 支付/资金/金融 | 不适用：内核没有支付和金融公式 | Maker/市场/来源原资金义务仍由原责任方验收 |
| 合约安全/Sui | 本地39项及6编译探针通过；shared风险有条件确认 | 实际 custody/旧入口/协议压力/真实PTB待核验 |
| Ethereum/EVM | 不适用：本次仅 Sui Move | 不引入新的 EVM 路线 |
| 治理/升级/锁 | 冻结代码的直接永久容纳通过；实际升级权限待核验 | Release/Deploy Owner 固定 Cap、政策、治理、转移/恢复路径 |
| 运行/监控/退出 | 原生退出本地通过；非原生和冻结状态边界明确 | 实际交易、暂停/恢复、告警/对账与退出责任待核验 |

| 权力及入口 | 冻结代码的控制对象 | 实际部署持有人/限制 |
| --- | --- | --- |
| 地址-owned/custodian root 的可变输入 | install/uninstall/update/nest/unnest | 具体 wallet/container 与入口待核验；直接共享没有此私有边界 |
| 来源 W/P/T 与公开发行函数 | 来源身份/安装/编辑见证 | 来源构造器与业务资格由来源维护；不是标准平台管理员 |
| 标准 Publisher | package-origin 集成/相关政策构造 | 本地构造通过；实际 ID、owner、政策未读回 |
| 有效 UpgradeCap 及治理 wrapper | 可允许的后续代码/依赖升级 | 实际 Cap、policy、多签、时间锁、转移/恢复待核验；无证据时不填已部署 |

本轮没有设计或实施暂停、时间锁、多签、永久不可升级、迁移或链上权限变更；这些不同机制不能互相代称。放行责任、风险接受者与生产地址不代填。完整报告和证据留在 canonical 标准仓，本次仅新增审计材料，未 commit/push/发布。
