# Soul 标准源码：用游戏角色读懂全部 280 行

这份教程把 Soul 想象成一个可以持续成长的游戏角色，按源码顺序解释全部字段、函数和检查。你可以先读故事，再对照末尾的完整原码。实际的 Soul 是通用资产内核；游戏角色只是帮助理解的比喻，装备、技能、任务记录等业务需要由扩展模块实现。

本文对应 [soul.move](/Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard/move/soulidity_standard/sources/soul.move)，共 280 行，读取日期为 2026-10-11。源码 SHA-256：`0574d86b7d40dd42e22774b3bd68d9f5e7705fda2cf805cfe58a31d3e777c2c7`。文中的行号对应这个版本；原源码保持不变。

## 先认识这个“角色”

假设你有一个角色叫“小π”。小π有自己的唯一身份和出生记录，身上可以挂载装备、技能等扩展对象。装备可以拆下，也可以设成只能继续强化、不能整件拆走。有些扩展还可以是另一个完整角色，像跟随主角色的伙伴。

Soul 负责记录角色是谁、从哪里产生、挂着哪些对象，以及每次操作后怎样核对这些记录。它不直接规定攻击力、职业、装备效果、市场价格或游戏玩法。

| 代码里的东西 | 游戏里的比喻 | 实际含义 |
| --- | --- | --- |
| `Soul` | 角色本体 | 一个有独立 ID 的 Sui 对象 |
| `UID` / `ID` | 角色的唯一身份 / 身份号码 | UID 是对象身份资源；ID 是可复制的标识值 |
| `Origin` | 出生档案 | 来源对象、来源类型、声明的版本和摘要、创建交易发送者 |
| `Descriptor` | 装备栏里的一条登记信息 | 扩展对象的类型、ID、规则和摘要 |
| `dynamic_object_field` | 实际挂在角色身上的装备 | 保存真正的扩展对象；目录只保存登记信息 |
| `W` | 某个装备体系的类型标记 | 用来划分命名空间，并在部分操作中检查类型关系 |
| `Edit` | 装备强化时的临时交还凭条 | 约束同一对象回到原来的 Soul |
| `Manifest` | 当前角色档案快照 | 汇总角色字段及扩展目录 |
| `revision` | 角色登记的操作次数 | Soul 自己维护的计数，不是角色等级，也不是 Sui 对象版本 |
| `schema` | 档案格式版本 | 说明数据格式，不表示战斗等级 |

“私人持有”指 Sui 记录的地址所有权，链上数据仍然可以被读取。Soul 自身没有 `owner` 字段；当前持有人由 Sui 的对象所有权系统记录。

## 读这份代码需要的最少知识

### 值、引用与修改

把装备对象作为一个“值”传入函数，意味着把它交给函数处理；借一个引用，则是允许函数暂时查看或修改它。

| 写法 | 最简单的理解 |
| --- | --- |
| `s: Soul` | 把这个 Soul 值交给函数 |
| `s: &Soul` | 借给函数查看，不能通过这个引用修改 |
| `s: &mut Soul` | 借给函数修改；仍然要满足 Sui 对象输入及所有权规则 |
| `: Soul` | 函数最后交回一个 Soul 值 |
| `: &T` | 函数交回只读引用 |
| `let mut d` | 这个局部变量之后允许修改 |
| `*引用` | 访问引用指向的值；能否复制或替换还受类型能力限制 |

`&mut Soul` 不是“谁调用谁就能改”。交易首先必须合法地取得这个对象的可变访问。私人地址持有的对象有所有权检查；共享对象允许更广泛的访问，再由函数里的规则决定可做什么。

### 四种能力

| 能力 | 含义 | 在角色比喻中 |
| --- | --- | --- |
| `key` | 可以作为 Sui 对象，具有自己的身份 | 角色或装备有独立身份 |
| `store` | 可以持久存入其他值；配合 `key` 可使用公开对象转移等接口 | 允许对象参与组合及转移 |
| `copy` | 可以复制这个值 | 可以复制一份档案或登记信息 |
| `drop` | 可以丢弃这个值 | 不需要保留一份临时信息 |

Soul 具有 `key + store`，没有 `copy` 或 `drop`。你可以复制角色的档案信息，不能靠复制 Soul 值制造第二个同身份角色，也不能随手丢弃整个角色资源。

`store` 不等于“已经共享”。它是一种类型能力；地址持有、共享、冻结和对象内组合是另外一层状态或操作。

### 泛型、标记与字段

`W`、`P`、`T` 是类型占位符：W 通常是标记，P 是来源对象类型，T 是扩展对象类型。`T: key + store` 表示传入的具体 T 必须有这两种能力。

`phantom W` 表示这个类型参数参与类型身份，却没有作为字段内容存进去。即使两个键都写着“武器”，`ModuleKey<A>` 与 `ModuleKey<B>` 仍然是不同的键类型。

`public struct` 让其他模块能够使用这个类型。Move 的字段构造、拆解和直接字段访问仍由定义该结构的模块控制。公开类型并不意味着外部可以自行制造 `Edit` 或读取、修改 Soul 的全部内部字段。

### 其余常见符号

| 写法 | 意思 |
| --- | --- |
| `public fun` / `fun` | 外部模块可以调用 / 仅本模块内部使用 |
| `u8`、`u16`、`u64` | 不同范围的无符号整数 |
| `bool` | `true` 或 `false` |
| `address` | 地址 |
| `String` | UTF-8 字符串 |
| `vector<u8>` | 字节序列，可用于名称、摘要等 |
| `vector<Descriptor>` | 一组扩展登记信息 |
| `Option<T>` | 可能有一个 T，也可能没有 |
| `assert!(条件, 错误码)` | 条件不成立，就中止当前交易的业务执行 |
| `&&`、`!`、`==` | 并且、取反、相等 |
| `b"文字"` | 文字对应的字节序列 |
| `let _ = witness` | 丢弃这个具有 `drop` 能力的标记值 |
| `ctx: &mut TxContext` | 当前交易上下文，可以取得发送者、创建新对象身份 |
| 函数末尾没有分号的表达式 | 将这个表达式的结果作为返回值 |

Sui 的同一笔交易可以组合多步调用，这通常称为 PTB。正常业务状态要么一起成功，要么在失败时一起回滚；失败交易仍可能支付 Gas。后面的“取出装备—强化—交还”就是利用同一交易内的组合。

## 第 1–9 行：声明角色系统，准备工具

第 1 行说明：这是一个不依赖具体应用的资产根对象，接口不直接暴露可变 UID，也不直接返回扩展对象的可变引用。用游戏语言说，外部不能拿到一个可以随意改写角色挂载关系的底层入口。

第 2 行 `module soulidity_standard::soul;` 声明这份代码属于标准包里的 `soul` 模块。这里的 Move 模块是代码组织单位；后文“安装的扩展模块”是挂在 Soul 上的对象，两者要分清。

| 行号 | 导入 | 用来做什么 |
| --- | --- | --- |
| 4 | `std::bcs` | 把数据按确定的格式编码为字节 |
| 5 | `std::hash` | 给字节计算 SHA3-256 摘要 |
| 6 | `String` | 保存角色名称 |
| 7 | `type_name::{Self, TypeName}` | 取得、保存和比较类型身份；`Self` 让代码使用 `type_name::...` |
| 8 | `dynamic_object_field as dof` | 用动态对象字段挂载、读取和取出扩展对象；`dof` 是简称 |
| 9 | `event` | 发出操作事件 |

源码里出现的 `UID`、`ID`、`object`、`TxContext`、`Option` 等，还使用了当前 Sui Move 环境的预置导入。

## 第 11–22 行：错误编号和容量限制

这些 `E...` 是本模块主动中止时使用的错误编号。可以把它们理解成“操作为什么没通过”的提示类别。

| 行号 | 常量 | 编号 | 自然语言 |
| --- | --- | --- | --- |
| 11 | `ERevision` | 1 | 你预期的操作次数已经不对 |
| 12 | `EEditing` | 2 | 当前不处于允许执行普通操作的状态 |
| 13 | `EAuthority` | 3 | 标记类型、来源类型或同模块关系不符合要求 |
| 14 | `EType` | 4 | 找不到这个登记项，或对象类型不对 |
| 15 | `EInput` | 5 | 输入长度、数值或摘要核对不符合要求 |
| 16 | `EDuplicate` | 6 | 这个命名空间下已经有同名扩展 |
| 17 | `ECapacity` | 7 | 扩展数量或对象编码大小超限 |
| 18 | `EPermanent` | 8 | 这个扩展不允许整件拆下 |
| 19 | `EIdentity` | 9 | 角色、对象或编辑凭条的身份对应不上 |
| 20 | `ESchema` | 10 | 格式版本不符合要求 |

这张表列的是本文件定义的编号；Sui、标准库等还可能产生它们自己的错误。

第 21 行规定一个 Soul 最多登记 **64 个直接扩展**。一个伙伴角色挂在主角色上，会占主角色的一个名额；伙伴自己的扩展属于它自己的目录。

第 22 行规定用于 `child_hash` 的扩展对象 BCS 编码最多 **245,760 字节，即 240 KiB**。这不是“递归统计角色所有装备的总大小”，也不是对整笔交易所有对象的统一限额。

## 第 24–29 行：包初始化，不是创建角色

第 24–25 行说明这部分为 Sui 的标准集成提供包发布身份，例如后续创建 `TransferPolicy<Soul>` 时使用的身份依据。本文件没有在这里安装交易规则，也没有绑定市场。

第 26 行定义空结构 `SOUL has drop {}`。大写 `SOUL` 是包初始化使用的一次性见证，和承载资产的 `Soul` 是两个不同类型。

第 27 行 `init` 在首次发布时接收见证，通过 `claim_and_keep` 创建并交付 `Publisher` 给该交易发送者。这一步登记发布身份，不会创建一个 Soul 角色。

第 28–29 行的 `#[test_only]` 与 `init_for_testing` 为测试提供初始化入口，测试构建中可以调用；它不是正式包中供普通用户重复初始化的入口。

容易混淆的三者：

| 名称 | 作用 |
| --- | --- |
| `SOUL` | 初始化时使用的一次性见证 |
| `Publisher` | 证明包／模块发布身份，供标准接口使用 |
| `UpgradeCap` | 控制包升级的能力对象；这段 `init` 不是在制造它 |

`claim_and_keep` 的具体行为可对照 [Sui 固定版本的 package 源码](https://github.com/MystenLabs/sui/blob/2a0becb2fcc6989e492981104af67f62f2c9511a/crates/sui-framework/packages/sui-framework/sources/package.move)。

## 第 31–39 行：Soul，角色本体

`Soul has key, store` 说明它是有独立身份、可以持久组合和公开转移的对象。每个字段的作用如下。

| 行号 | 字段 | 角色比喻 | 实际作用 |
| --- | --- | --- | --- |
| 32 | `id: UID` | 角色唯一身份 | Sui 对象的身份资源 |
| 33 | `schema: u16` | 角色档案格式 | 本版创建时为 1 |
| 34 | `name: String` | 角色名字 | 创建时提供的名称 |
| 35 | `revision: u64` | 登记操作次数 | 创建时为 0；安装、拆卸、完成编辑时递增 |
| 36 | `origin: Origin` | 出生档案 | 记录角色创建的来源信息 |
| 37 | `modules: vector<Descriptor>` | 装备、技能登记列表 | 保存扩展的描述信息，实际对象通过 DOF 挂载 |
| 38 | `editing: bool` | 是否正在处理一次强化交还 | 普通状态为 false，开始编辑后临时为 true |

这份文件没有直接修改根 `name`、根 `schema` 或 `origin` 的公开函数。角色成长主要体现在扩展对象及其登记信息的变化上。

## 第 41–50 行：Origin，出生档案

第 41–42 行的注释强调：来源是交易中实际传入的对象；来源版本和来源摘要是来源模块提供的声明。Soul 内核不自行解释 Maker 或存储服务的业务。

`Origin` 具有 `copy, drop, store`：它是一份可以复制、丢弃或保存的档案，不是整个来源对象。

| 行号 | 字段 | 自然语言 |
| --- | --- | --- |
| 44 | `producer` | 使用哪个生产标记类型创建角色 |
| 45 | `source_type` | 来源对象是什么类型 |
| 46 | `source` | 实际来源对象的 ID |
| 47 | `source_version` | 来源模块声明的版本号 |
| 48 | `source_hash` | 来源模块声明的 32 字节摘要 |
| 49 | `minted_by` | 创建 Soul 的交易发送者地址 |

比如某个 Maker 对象提供创建依据，角色出生档案记录它的 ID；Maker 本身不会因此被放进角色里，因为 `new` 只借用 `&P`。

`source_version` 不会自动读取 Sui 原生对象版本；`source_hash` 也不会在 `new` 中重新计算来源对象内容。这里检查的是版本大于零、摘要长度正确。它们是否如实代表某个业务版本，由来源模块的实现负责。

`minted_by` 是当时的交易发送者，不等于永远的持有人，也不必然等于内容作者。以后转让角色，它不会自动改成新持有人。

## 第 52–61 行：Descriptor，一条装备登记

实际装备对象与“装备登记信息”分开保存。Descriptor 相当于角色界面中一条装备的记录，而不是装备对象本身。

| 行号 | 字段 | 自然语言 |
| --- | --- | --- |
| 53 | `namespace` | 这件扩展属于哪个 W 类型划分的体系 |
| 54 | `name` | 这个体系内使用什么名称定位它 |
| 55 | `value_type` | 实际扩展对象的完整类型 |
| 56 | `object` | 实际扩展对象的 ID |
| 57 | `schema` | 这个扩展的数据格式版本 |
| 58 | `removable` | 是否允许整件拆卸 |
| 59 | `body_hash` | 实际扩展对象直接 BCS 编码的摘要 |
| 60 | `semantic_hash` | 应用给出的业务摘要 |

`body_hash` 像“这件装备当前直接数据的指纹”。如果 T 自己还挂着动态字段，它们并不会被 `bcs::to_bytes(&T)` 自动递归展开。

`semantic_hash` 像“装备系统认为需要登记的业务状态指纹”。如何选择这些业务信息由应用定义；内核只检查它有 32 字节。后文原生伙伴嵌套会专门把伙伴的 `manifest_hash` 用作该摘要。

因此，这两个摘要不能简单理解成“装备及所有相关数据都已经全面核验”。

## 第 63–68 行：扩展键与伙伴专用标记

第 63–64 行定义 `ModuleKey<phantom W> { name }`。实际挂载对象时，键由 **W 的类型身份 + name** 组成。

假设“武器系统”和“技能系统”都使用 `main` 作为名称，它们使用不同的 W，就不会冲突。同一个 W 下的 `main` 只能登记一次，不能靠把剑换成弓的类型就再安装一个同名项。

构造这个键的代码留在 Soul 模块内部，外部通过标准接口使用它。

第 66–68 行定义 `NestedSoulWitness`，作为原生“角色带伙伴”功能的专用标记。它的构造留在本模块内部。伙伴仍然是具有自己 ID 的独立 Soul，不会因为挂在主角色上，就变成主角色的另一个形态。

这里的 W 标记不是角色持有人的地址，也不是所有场景通用的管理员身份。

## 第 70–77 行：Edit，必须完成的强化交还凭条

`Edit<W, T>` 故意没有 `copy/drop/store/key` 能力。它不能复制、随手丢弃或保存到下一笔交易。

| 行号 | 字段 | 凭条记录什么 |
| --- | --- | --- |
| 73 | `soul` | 从哪个角色取出的 |
| 74 | `object` | 取出的哪一个扩展对象 |
| 75 | `name` | 原来挂在哪个名称下 |
| 76 | `revision` | 取出时预期的登记操作次数 |

比喻是：把一把剑暂时交给强化系统时，同时拿到一张必须结清的凭条。成功交易中要把**同一把剑**交回**原角色**，不能换成另一把剑，也不能带着凭条结束交易、下次再交还。

W 和 T 还绑定了它所属的体系与对象类型。外部不能自行构造或拆解 Edit；本文件通过 `commit_update` 消耗它，完成交还。

第 70–71 行同时说明：不可拆卸模块可以编辑，但不能通过普通拆卸接口整件取走。“不可拆卸”不表示它的全部业务内容永远不变，也不自动限制扩展自身定义的所有内部资源操作。

## 第 79–87 行：操作事件与角色快照

`Changed` 是操作事件，便于外部记录“哪个角色的哪件扩展发生了哪种操作”。

| 字段 | 记录内容 |
| --- | --- |
| `soul` | 主 Soul 的 ID |
| `revision` | 操作完成后的登记次数 |
| `operation` | 0 安装，1 拆卸，2 完成编辑 |
| `namespace` | 扩展所属体系 |
| `name` | 扩展登记名 |
| `object` | 扩展对象 ID |

`Manifest` 是角色当前档案的快照。

| 字段 | 内容 |
| --- | --- |
| `domain` | 标明这是 Soul 标准 v1 的 manifest 数据 |
| `soul` | 角色 ID |
| `schema` | 角色档案格式 |
| `name` | 角色名字 |
| `revision` | 登记次数 |
| `origin` | 出生档案 |
| `modules` | 全部扩展描述信息 |

快照不包含当前所有者字段，也不会把每个实际装备对象的原始内容全部展开进去。它包含的是扩展描述及其中登记的摘要。

## 第 89–95 行：same_module，检查标记与对象的类型出处

这段内部函数检查 W 与 T 是否出自同一个原始包、同一个 Move 模块。

逐句翻译：

1. 第 90 行，取得 W 的原始包类型名称。
2. 第 91 行，取得 T 的原始包类型名称。
3. 第 92 行，两者都不能是 `u64` 等基础类型。
4. 第 93–94 行，两者的原始包地址和模块名必须相同。
5. 不符合就用 `EAuthority` 中止。

游戏比喻：强化系统提供的标记和这件装备，要来自同一套装备代码体系。

它检查的是包和模块，没有要求 W 与 T 是同一个结构体，也没有要求它们的泛型参数相同。这个检查本身也不等于“已经确认某个具体管理员”。使用 W 作为凭证的应用，要通过自己的构造、发放规则控制谁能取得它。

这份源码对类型身份用了两个函数：

| 函数 | 记录的包 ID | 在这里的用途 |
| --- | --- | --- |
| `with_original_ids` | 包的第一版 ID | 比较类型是否属于同一原始包和模块 |
| `with_defining_ids` | 第一次引入该类型的包版本 ID | 保存完整类型身份及命名空间 |

它们都不是“当前最新执行版本的包 ID”。已有类型不会仅因后续升级，就自动换成最新包 ID；具体定义见 [Sui 固定版本的 type_name 源码](https://github.com/MystenLabs/sui/blob/2a0becb2fcc6989e492981104af67f62f2c9511a/crates/sui-framework/packages/move-stdlib/sources/type_name.move)。

## 第 97–109 行：几个通用检查

### 第 97 行：hash32

`hash32` 只检查输入长度是不是 32 字节。

最简单地说：你交的“指纹”格式必须正确。长度正确不等于内容真实，也不等于它一定由某种特定算法生成。

### 第 98–100 行：check_name

扩展名称必须在 **1–64 字节**之间。这里限制的是 `vector<u8>` 长度，不是 64 个汉字。

这个检查用于扩展名称。它不限制根角色 `name: String` 也只能有 64 字节。

### 第 101 行：ready

同时满足两项才能通过：

- Soul 的根格式版本是 1。
- Soul 当前没有正在进行的扩展编辑。

像角色正在把装备交给强化系统时，其他需要完整装备目录的操作暂时不通过。但它不是持续很多笔交易的锁，也不是等待若干小时的时间锁。

### 第 102 行：cas

`cas` 检查 `s.revision == expected`。

假设你看到角色登记次数是 5，并据此准备操作，就提交 `expected = 5`。如果执行时已经变成 6，这次操作中止，避免继续使用过时的判断。

这个值是 Soul 自己的计数，不是 Sui 原生对象版本。

### 第 103–109 行：child_hash

第 103–104 行解释：根对象受 Sui 执行层对象大小限制，本文件没有再为根名称和根内容增加一个更小的自定义上限。

第 105–109 行依次执行：

1. 把扩展对象的直接数据按 BCS 编码。
2. 编码结果不得超过 240 KiB。
3. 返回这些字节的 SHA3-256 摘要。

BCS 可以理解成“按统一规则把数据写成字节”，哈希可以理解成“再把这些字节压成固定长度的内容指纹”。这里不会追踪对象的所有外部关联信息。

## 第 111–130 行：new，创建一个新角色

调用者提供生产标记 W、实际来源对象 P 的只读引用、来源版本、来源摘要、角色名字和交易上下文，函数返回一个新 Soul。

| 行号 | 语句的自然语言 |
| --- | --- |
| 111–114 | W 要能丢弃；P 要是有身份的对象；创建结果是 Soul |
| 115 | 检查 W 与 P 出自同一原始包、同一模块，然后消耗标记 |
| 116–118 | 额外要求 W 的数据类型名是 `SoulProducer`，这个名字检查不包含泛型参数 |
| 119 | 来源摘要必须为 32 字节 |
| 120 | 声明的来源版本必须大于零 |
| 121–122 | 生成新的 UID，设根格式为 1、登记次数为 0、扩展为空、编辑状态为 false |
| 123–127 | 写入生产标记类型、来源类型、实际来源 ID、声明的版本和摘要、交易发送者 |
| 128–129 | 完成构造，返回这个新 Soul |
| 130 | 函数结束 |

`SoulProducer` 的名字检查避免随便用同模块其他 metadata 类型作为生产标记。生产模块仍要控制这个标记的构造与发放；内核不会仅靠名字检查就保证它没有被公开发放。这个 W 也不是前面的初始化一次性见证 `SOUL`。

用游戏语言说：某个创建系统凭自己的生产标记，为实际来源建立一个有独立身份的新角色，并填写出生档案。

**这个函数只创建并返回角色。** 它没有直接转给某个地址，也没有共享或冻结角色。创建系统接下来可以在同一交易安装初始装备，再决定怎样交付。

因此：

- 创建系统把新 Soul 转给你的地址，你就地址私有持有它。
- 创建系统把新 Soul 直接共享，它就成为共享对象。
- 某个 Maker 自己是共享对象，不代表它创建并交付的 Soul 也是共享对象。

本文件没有调用 `public_share_object`。外部能对满足条件的新对象使用 Sui 接口，是当前 `new` 返回 Soul 且 Soul 具有 `key + store` 的组合结果。

按本项目固定版本，`public_share_object` 要求对象在当前交易新建；直接共享后的同一个对象不能再直接恢复为地址持有。因此“先把 Soul 共享，再直接转给私人地址”不是这里的一条交付流程。地址持有后转给另一个地址是正常转让；已有地址持有对象也不能在后续交易直接通过这个接口变成共享对象。`store` 仍允许外部组合或托管等其他设计，不能据此推导终身禁止托管。规则见 [Sui 固定版本的 transfer 源码](https://github.com/MystenLabs/sui/blob/2a0becb2fcc6989e492981104af67f62f2c9511a/crates/sui-framework/packages/sui-framework/sources/transfer.move)。

## 第 132–149 行：find 和 index，定位一件扩展

### find：按体系和名称查找

第 133 行取得 W 的完整定义类型名称，作为命名空间。

第 134–139 行从目录第一个位置开始，逐个检查。只有命名空间和名称同时相同，才返回 `Some(i)`，表示“找到了，在第 i 个位置”。

第 140 行如果全部检查后都没找到，返回 `None`。

这像在角色界面里查找“武器体系中的 main 装备”，而不是只凭 `main` 两个字跨所有体系查找。目录最多 64 项，所以这里使用直接循环。

### index：找到以后，再核对对象类型

第 144 行调用 `find<W>`。

第 145 行要求确实找到，否则用 `EType` 中止。

第 146 行取出找到的位置 i。`destroy_some` 是拆开 Option 的“有值”情况，取得里面的位置，不是销毁装备。

第 147 行检查登记的实际对象类型是否等于 T 的完整类型身份。

第 148 行返回位置。

游戏比喻：先找到“主武器”这一项，再确认你要按剑的类型处理的，确实是一把这种类型的剑。

## 第 151–157 行：changed，更新计数并记一条操作

第 152 行把 Soul 的 `revision` 加 1。

第 153–156 行发出 `Changed` 事件，带上角色 ID、增加后的次数、操作种类、扩展体系、名称和对象 ID。

这个函数在安装、拆卸、完成编辑时调用。开始编辑本身不调用它。

一笔交易中可以组合多次这些操作，所以 `revision` 也可以在一笔交易里增加多次。它不是“一笔交易一定加一”的计数。

## 第 159–174 行：install，给角色安装一个扩展

参数可以用游戏语言读成：

> 给这个角色，在指定装备体系下，用这个名称挂上这个对象；登记它的数据格式、是否可拆以及业务摘要，并要求角色仍是我预期的状态。

| 参数 | 意思 |
| --- | --- |
| `s` | 要安装到哪个 Soul |
| `witness: W` | 这次安装提供的体系标记 |
| `name` | 该体系内的登记名 |
| `value: T` | 真正要挂上去的对象 |
| `schema` | 扩展的数据格式版本 |
| `removable` | 是否允许整件拆卸 |
| `semantic_hash` | 应用声明的 32 字节业务摘要 |
| `expected` | 预期的 Soul 登记次数 |

函数按顺序做这些事：

1. **第 163 行：** 角色必须 ready，登记次数必须匹配，W 与 T 必须同原始包、同模块；消耗 W。
2. **第 164 行：** 名称为 1–64 字节，业务摘要为 32 字节，扩展格式版本大于零。
3. **第 165 行：** 同一个 W 命名空间下不能已有这个名字。
4. **第 166 行：** 直接扩展数量还没到 64。
5. **第 167–171 行：** 创建描述信息，记录真实类型、真实对象 ID、规则以及两个摘要；body_hash 在这里实际计算。
6. **第 172 行：** 把真正的对象 T 挂到 Soul 的动态对象字段下，使用 `ModuleKey<W>{name}` 作键。
7. **第 173 行：** 把描述加入目录，增加一次 revision，并发出“安装”事件。

安装的是 `T` 的值，它不只是把对象 ID 记在目录里。完成后，对象实际挂在 Soul 下，不再是单独交给某个地址的那个状态。

`removable=false` 表示本标准不允许通过 `uninstall` 整件取走该对象。它仍可以通过规定的编辑流程更新。业务代码如果还有内部转移、提取资源等功能，要按那些函数自己的规则理解。

## 第 176–179 行：borrow_module，只读查看扩展

第 177 行先检查角色 ready，然后核对命名空间、名称和实际类型。

第 178 行按相同的动态字段键读取对象，返回 `&T`。

像在角色面板查看装备属性。你拿到的是只读引用，不能通过它修改装备，也没有把装备从角色身上拆走。

这里不要求再传一个 W 标记值，因为它只是查看；W 类型参数仍然用来定位具体命名空间。

## 第 181–188 行：uninstall，整件拆下扩展

第 182 行检查角色 ready、登记次数正确。

第 183 行找到指定扩展，复制一份描述信息供核对。

第 184 行要求 `removable=true`；不可拆的扩展在这里中止。

第 185 行从动态对象字段中取出真实对象 T。

第 186 行核对取出的对象 ID 必须等于描述中记录的 ID。

第 187 行删除目录项，增加 revision，发出“拆卸”事件，并返回对象 T。

游戏语言：拆下你登记的那件装备，确认没有取错，删除角色装备栏的登记，把原装备交给后续调用处理。

返回 T 不等于已经自动转到钱包。交易接下来还要按合法方式处理它，例如交给地址、安装到另一个 Soul，或者进行其他允许的组合。

**这条函数没有额外要求 W 标记值或创建者地址。** 是否能拆，首先取决于交易能否取得该 Soul 的合法可变访问，再检查 `removable` 等条件。对地址持有 Soul，陌生人不能仅凭知道 ID 就取得这样的对象输入；如果创建系统选择把 Soul 共享，这条接口也没有另加“只有某个玩家可拆”的检查。

“共享可拆”是这份通用接口在共享状态下的行为。是否需要限制特定玩家，由使用它的产品规则决定。

## 第 190–199 行：begin_update，暂时取出装备用于强化

这个函数返回一对值：真实对象 T 和 `Edit<W,T>` 临时凭条。

| 行号 | 自然语言 |
| --- | --- |
| 193 | 检查 ready、预期次数以及 W 与 T 的同模块关系，消耗 W |
| 194 | 找到扩展，记录它原来的对象 ID |
| 195 | 从动态字段取出这个对象 |
| 196 | 确认它就是登记的同一个对象 |
| 197 | 把角色标记为正在编辑 |
| 198 | 返回对象及绑定原角色、原对象、原名称、原 revision 的凭条 |

目录项此时仍然保留，真实对象暂时取出来了。因此代码设置 `editing=true`，让依赖完整目录的普通操作不能继续运行。

接下来，应用自己的函数可以修改 T 的业务字段，比如强化这把剑。它必须具备修改该类型字段的合法接口，不是拿到 T 就能绕过字段访问规则。

开始编辑不会增加 revision。成功完成编辑才增加。

## 第 201–215 行：commit_update，交回同一件装备并更新记录

参数包括角色、凭条、W 标记、更新后的同一个对象、格式版本和新的业务摘要。

逐句翻译：

1. **第 205 行：** 再次检查 W 与 T 的出处关系，消耗标记，要求新业务摘要为 32 字节。
2. **第 206 行：** 拆开凭条，读取原角色 ID、原对象 ID、原名称和原 revision；凭条在这里被消耗。
3. **第 207 行：** 角色确实在编辑中；凭条对应这个角色；交回对象仍是凭条中的那个 ID。
4. **第 208 行：** 角色 revision 仍然等于凭条记录的次数。
5. **第 209–210 行：** 按原命名空间、原名称和类型找到描述，复制出来修改。
6. **第 211 行：** 描述中的对象 ID 也必须匹配；新的扩展 schema 不能小于原 schema。
7. **第 212 行：** 保存新 schema，重算对象的直接 body_hash，保存调用者提供的新 semantic_hash。
8. **第 213 行：** 把同一对象重新挂回同一键。
9. **第 214 行：** 替换描述，结束编辑，增加 revision，发出“完成编辑”事件。

游戏比喻：剑可以强化，剑的身份不能换；凭条属于小π，就不能拿去结清另一个角色的编辑。

`removable` 没有在这段代码中重新赋值，所以原来的可拆／不可拆设置保持不变。

schema 可以保持相同，也可以增加；它表示格式版本，强化数值变化不必然要求 schema 增加。这项“不能降低”的要求针对当前持续安装的登记项。如果可拆扩展被卸下再重新安装，原描述已删除，新安装只检查 schema 大于零，不能据此说整个对象终身不允许使用较小格式编号。

### 一次强化的完整流程

`begin_update → 应用修改 T → commit_update` 必须在同一笔成功交易里完成。

编辑凭条不能持久保存，也不能直接丢弃。如果修改或交还过程中中止，整个交易的业务状态回滚，角色不会留下这次交易造成的“装备已取出但凭条未结清”状态。

`editing` 是配合这套流程的临时一致性标记。它不是管理员暂停开关，也不是链上对象交易锁或资产锁仓。

## 第 217–237 行：读取角色、来源和扩展目录

### 第 217–226 行：基本信息 getter

getter 就是“读一个字段”的小函数。它们不修改 Soul，也不增加 revision。

| 行号 | 函数 | 返回什么 |
| --- | --- | --- |
| 217 | `revision` | Soul 的登记操作次数 |
| 218 | `schema` | Soul 根档案格式版本 |
| 219 | `name` | 根名称的只读引用 |
| 220 | `origin` | 一份出生档案 |
| 221 | `source` | Origin 中的来源对象 ID |
| 222 | `source_type` | 来源对象完整类型 |
| 223 | `producer` | 生产标记完整类型 |
| 224 | `source_version` | 声明的来源版本 |
| 225 | `source_hash` | 声明的来源摘要 |
| 226 | `minted_by` | 创建交易的发送者 |

第 221–226 行的参数是 `&Origin`，通常先调用 `origin(s)` 得到档案，再读取里面的字段。

这些基本 getter 不调用 `ready`，所以在同一交易的编辑过程中仍然可以读取它们。它们不会把临时取出的扩展当作已完成的新档案。

### 第 227 行：module_count

先检查 ready，再返回直接扩展的登记数量。

角色有 3 个普通扩展和 1 个伙伴，主 Soul 的数量就是 4；不会自动累加伙伴自己挂载的全部扩展。

### 第 228–230 行：descriptor

按 W 和名称查找一条扩展描述。找到就返回 `Some(Descriptor)`，没有就返回 `None`。

`map!(|i| s.modules[i])` 可以读成：“如果找到了位置 i，就把该位置的描述作为结果。”

它只查描述，没有额外传 T 去核对具体对象类型；实际类型已经包含在返回的 Descriptor 中。这个函数先检查 ready。

### 第 231–237 行：module_page

分页返回一部分扩展描述，适合界面分批展示角色装备。

1. 第 232 行，先要求 ready，limit 不超过 64，offset 不超过目录长度。
2. 第 233 行，算出最后读取到的位置，不超过目录末尾。先比较剩余数量，再进行加法。
3. 第 234 行，准备空结果，从 offset 开始。
4. 第 235 行，逐个把描述加入结果，直到结束位置。
5. 第 236 行，返回结果。

例如 `offset=2, limit=3`，表示跳过前两个，最多读取第 3、4、5 项。

limit 为 0 时返回空列表；offset 正好等于目录长度时也返回空列表。超过目录长度的 offset 会中止。

目录按当前 vector 顺序返回，没有按名称或类型排序。拆卸会移除一项，后面的项随之移动，所以分页位置不是某件装备的永久身份；对象 ID 才是身份。

## 第 238–245 行：读取一条装备描述

这些函数接收 `&Descriptor`，返回对应字段，不修改对象。

| 行号 | 函数 | 自然语言 |
| --- | --- | --- |
| 238 | `module_id` | 这条描述对应的真实扩展对象 ID |
| 239 | `namespace` | 哪个 W 类型划分的体系 |
| 240 | `module_name` | 体系内登记的名字 |
| 241 | `value_type` | 真实扩展对象的类型 |
| 242 | `module_schema` | 扩展格式版本 |
| 243 | `removable` | 是否允许整件拆卸 |
| 244 | `body_hash` | 已登记的直接对象摘要 |
| 245 | `semantic_hash` | 已登记的业务摘要 |

注意两个同名概念：`name(s)` 读角色根名字，`module_name(d)` 读扩展名字；`schema(s)` 读根格式，`module_schema(d)` 读扩展格式。

这些描述 getter 只是读传入的描述。若你持有的是以前复制的描述，它们返回的也只是那份旧记录，不会自动向链上刷新。

## 第 246–256 行：manifest，为当前角色档案做整体核对

### 第 246–251 行：manifest

先检查 ready，再创建当前快照：

- 第 248 行，写入固定 domain、角色 ID 和根 schema。
- 第 249 行，复制根名称、revision、Origin 和全部 Descriptor。
- 第 250–251 行，完成并返回 Manifest。

domain 的文字是 `soulidity/standard/manifest/v1`，帮助区分这类数据摘要的用途和格式。它不是持有人地址，也不是额外权限。

### 第 252 行：manifest_hash

`manifest_hash` 先取得完整 Manifest，按 BCS 编码，再计算 SHA3-256。

游戏语言：给“当前角色档案”生成一个指纹。档案中的任何编码字段变化，核对时都会体现在相应的摘要计算中。

这份档案包括装备描述及其已登记的摘要；它没有递归展开所有动态子对象的实际内容，也没有包含当前地址所有者。因此，单纯转让 Soul 地址所有权不会自动改变这些根字段、revision 或 manifest_hash。

### 第 253–256 行：assert_manifest

第 254 行要求角色 ready、revision 等于预期、预期摘要长度为 32。

第 255 行要求重新计算的当前 manifest_hash 等于传入的预期摘要。

最简单的用途：交易开始处理之前，确认“我准备操作的，仍是我先前看到的那份角色档案”。

它核对的是这份标准档案，没有重新审核出生来源的业务真实性，也没有重新计算每个外部或深层动态对象的全部数据。

## 第 258–280 行：让一个完整角色作为另一个角色的伙伴

这部分是当前原源码保留的原生嵌套功能。可以理解成“主角色带着一个完整伙伴角色”；伙伴有自己的名字、出生档案、ID 和扩展。

嵌套不是复制、合并身份，也不是把两者自动变成一个角色。

### 第 258–265 行：nest，挂载伙伴

第 258–259 行的注释说明：原生嵌套把整个子 Soul 作为一个组合资产；这个专用命名空间里，伙伴被设为可拆卸。

函数做四步：

1. 第 261 行取得伙伴的 ID。
2. 第 262 行要求伙伴 ID 不等于主角色 ID。
3. 第 263 行取得伙伴当前 manifest_hash。
4. 第 264 行调用 `install`：使用 `NestedSoulWitness`，把伙伴 ID 的 BCS 字节当作登记名，格式版本为 1，可拆卸为 true，业务摘要为伙伴档案摘要。

`install` 的全部 ready、revision、数量和大小检查仍然适用。名字由 ID 自动生成，调用者不必再取一个字符串名称。

这里的“可拆卸”意味着通过原生 nest 安装的伙伴可以走原生 unnest 路径；操作仍须能合法取得主 Soul 的可变访问，并满足预期次数等条件。它不是绕过 Sui 所有权的一项许可。

### 第 266–268 行：nested，查看伙伴

根据伙伴 ID 生成相同的键，再调用：

`borrow_module<NestedSoulWitness, Soul>`。

返回的是伙伴的 `&Soul` 只读引用。你可以读取伙伴档案，不能通过这个引用直接修改它。

### 第 269–271 行：unnest，取出伙伴

根据伙伴 ID 生成键，再调用：

`uninstall<NestedSoulWitness, Soul>`。

完成后主角色目录移除伙伴、revision 增加，函数返回原来的伙伴 Soul。它的 ID 和独立身份保留，接下来可以合法转给地址或继续组合。

### 第 272–276 行：begin_nested_update，暂时取出伙伴修改

第 272–273 行说明这是一条可以在 PTB 中组合的值路径，不直接暴露可变子引用或根 UID。

函数调用 `begin_update`，返回：

- 原来的伙伴 Soul 值。
- `Edit<NestedSoulWitness, Soul>` 凭条。

这像让伙伴暂时离开主角色队伍去进行一次成长操作，同时登记“必须回到原队伍”的凭条。

因为拿到的是伙伴 Soul 值，调用者可以继续对它调用标准接口。最后必须在同一成功交易交回同 ID 的伙伴。

### 第 277–280 行：commit_nested_update，交回成长后的伙伴

第 278 行重新取得伙伴的 manifest_hash。

第 279 行调用 `commit_update`，以格式版本 1 和新的伙伴摘要交还；主角色上这条伙伴描述的 body_hash 与 semantic_hash 同时更新，主角色 revision 增加。

若伙伴自己也包含其他伙伴，需要按内到外完成编辑：

`先完成最里面角色 → 更新其所在角色 → 最后更新最外面的主角色`。

父角色描述中的伙伴摘要不是自动实时监听器。它通过这些明确的提交步骤刷新。

### 原生 nest 的规则适用在哪里

`nest` 固定使用专用命名空间，并设置 `removable=true`。这是这条原生路径的约定。

通用 `install` 接口并没有排除 `T=Soul`。例如 `Origin` 也定义在本 soul 模块，且有 `drop`，可以作为符合 `same_module<Origin,Soul>` 的标记类型使用；经通用接口在其他命名空间安装 Soul 时，`removable` 是那次调用传入的值。

因此“原生 nest 的伙伴可拆卸”不能扩展成“所有通过任意通用组合方式保存的 Soul 都一定可拆卸”。先看使用了哪个入口和命名空间，再看它登记的规则。`store` 允许组合，也不表示一个 Soul 必须安装到另一个 Soul 中。

## 用一次角色成长串起全部关键逻辑

下面的小π和剑都是教学例子，不代表内核已经实现了具体游戏玩法。

| 步骤 | 角色或装备发生什么 | Soul revision |
| --- | --- | --- |
| 创建小π | 新身份、出生档案、空目录 | 0 |
| 安装一把可拆的剑 | 挂上真实剑对象，登记类型、ID、规则和摘要 | 1 |
| 开始强化 | 暂时取出同一把剑，产生 Edit，editing=true | 仍为 1 |
| 装备应用强化剑 | 应用修改这把剑的业务字段 | 仍为 1 |
| 完成交还 | 同 ID 的剑回到原角色，更新摘要，editing=false | 2 |
| 拆下剑 | 删除挂载与目录，返回原剑对象 | 3 |
| 把小π从 A 地址转给 B 地址 | Sui 记录的持有人变化 | 标准字段不因此自动变化 |

第三至第五步必须在同一笔成功交易里完成。如果中途失败，那次强化流程的业务状态回滚。

如果创建系统把新小π直接交给 B，B 就按 Sui 地址所有权控制该资产。B 再转给 C 后，A 或 B 的旧持有关系不能使它们继续取得这个私人对象的可变输入。应用另外设计的业务资格或授权，要看该应用自己的代码。

## 这 280 行表达的设计理念

**身份稳定，成长可组合。** 角色始终有自己的 ID。装备可以增加、更新或拆下，伙伴也保留自己的身份。

**根对象只管理共同规则。** Soul 记录身份、来源、目录、摘要和变化，不把某个游戏、Maker、市场或存储服务的业务塞进核心。

**真实对象与登记信息互相对应。** 扩展对象保存实际状态，Descriptor 保存类型、ID、规则和摘要；取出、交还时反复核对对象身份。

**修改要结清。** 不把一个可随意修改的子引用直接交出去，而是取出值、修改、用不能丢弃的 Edit 交回同一对象。

**对旧状态的操作要显式核对。** 调用者提供 expected revision；需要更完整核对时提供 manifest_hash。

**把格式检查与业务事实分开。** 内核确认摘要长度、类型关系、身份和格式版本等。业务摘要代表什么、生产标记怎么发放、共享状态应该由谁操作，仍由使用它的系统决定。

## 推荐的阅读顺序

第一次读，先理解 `Soul → Origin → Descriptor`：角色本体、出生档案、装备登记。

第二遍看 `new → install → borrow_module → uninstall`：创建角色、挂上装备、查看、拆下。

第三遍看 `begin_update → Edit → commit_update`：同一件装备怎样安全地完成一次修改。

最后看 `revision / manifest` 和五个嵌套函数，把“核对当前档案”与“伙伴成长后逐层更新”串起来。

如果需要补基础，优先学习 Move 的值与引用、四种 abilities、字段访问、泛型、Sui 对象所有权以及 PTB。BCS、哈希、类型身份和动态对象字段可以结合本源码再学，不必先学习完整 DeFi 或 Solidity 体系。

## 附录：本次讲解对应的完整原源码

以下是直接读取的 280 行原文。空行用于排版，注释用于说明；正文已经按源码顺序覆盖全部字段、函数和实际语句。

```move
/// Application-independent asset root. No mutable UID or mutable-child escape.
module soulidity_standard::soul;

use std::bcs;
use std::hash;
use std::string::String;
use std::type_name::{Self, TypeName};
use sui::dynamic_object_field as dof;
use sui::event;

const ERevision: u64 = 1;
const EEditing: u64 = 2;
const EAuthority: u64 = 3;
const EType: u64 = 4;
const EInput: u64 = 5;
const EDuplicate: u64 = 6;
const ECapacity: u64 = 7;
const EPermanent: u64 = 8;
const EIdentity: u64 = 9;
const ESchema: u64 = 10;
const MAX_MODULES: u64 = 64;
const MAX_CHILD_BYTES: u64 = 245760;

/// Package ownership proof for standard Sui integrations such as a real
/// TransferPolicy<Soul>. The kernel does not install rules or depend on a market.
public struct SOUL has drop {}
fun init(w: SOUL, ctx: &mut TxContext) { sui::package::claim_and_keep(w, ctx) }
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) { init(SOUL {}, ctx) }

public struct Soul has key, store {
    id: UID,
    schema: u16,
    name: String,
    revision: u64,
    origin: Origin,
    modules: vector<Descriptor>,
    editing: bool,
}

/// Source identity is an actual object input. Version/hash are its module's
/// attestation, not a kernel interpretation of a Maker or a storage service.
public struct Origin has copy, drop, store {
    producer: TypeName,
    source_type: TypeName,
    source: ID,
    source_version: u64,
    source_hash: vector<u8>,
    minted_by: address,
}

public struct Descriptor has copy, drop, store {
    namespace: TypeName,
    name: vector<u8>,
    value_type: TypeName,
    object: ID,
    schema: u16,
    removable: bool,
    body_hash: vector<u8>,
    semantic_hash: vector<u8>,
}

/// Private constructor and typed DOF keys isolate every application namespace.
public struct ModuleKey<phantom W> has copy, drop, store { name: vector<u8> }

/// Canonical native nesting namespace. A nested Soul remains a distinct asset,
/// never a new form of its parent. Constructor stays inside this module.
public struct NestedSoulWitness has drop {}

/// No abilities: successful transactions must restore this exact child into
/// this exact Soul. Permanent modules can be edited but cannot be withdrawn.
public struct Edit<phantom W, phantom T> {
    soul: ID,
    object: ID,
    name: vector<u8>,
    revision: u64,
}

public struct Changed has copy, drop {
    soul: ID, revision: u64, operation: u8,
    namespace: TypeName, name: vector<u8>, object: ID,
}

public struct Manifest has copy, drop, store {
    domain: vector<u8>, soul: ID, schema: u16, name: String,
    revision: u64, origin: Origin, modules: vector<Descriptor>,
}

fun same_module<W, T>() {
    let w = type_name::with_original_ids<W>();
    let t = type_name::with_original_ids<T>();
    assert!(!w.is_primitive() && !t.is_primitive(), EAuthority);
    assert!(w.address_string() == t.address_string()
        && w.module_string() == t.module_string(), EAuthority);
}

fun hash32(value: &vector<u8>) { assert!(value.length() == 32, EInput) }
fun check_name(value: &vector<u8>) {
    assert!(value.length() > 0 && value.length() <= 64, EInput)
}
fun ready(s: &Soul) { assert!(s.schema == 1 && !s.editing, EEditing) }
fun cas(s: &Soul, expected: u64) { assert!(s.revision == expected, ERevision) }
// Root contents use Sui's execution-level Move object size bound. Imposing a
// smaller name/root ceiling here changes the original native metadata domain.
fun child_hash<T>(value: &T): vector<u8> {
    let bytes = bcs::to_bytes(value);
    assert!(bytes.length() <= MAX_CHILD_BYTES, ECapacity);
    hash::sha3_256(bytes)
}

public fun new<W: drop, P: key>(
    witness: W, source: &P, source_version: u64,
    source_hash: vector<u8>, name: String, ctx: &mut TxContext,
): Soul {
    same_module<W, P>(); let _ = witness;
    // Same-module public metadata values also have drop. Only the producer's
    // designated marker may attest issuance; its constructor must remain private.
    assert!(*type_name::with_original_ids<W>().datatype_string().as_bytes()==b"SoulProducer",EAuthority);
    hash32(&source_hash);
    assert!(source_version > 0, EInput);
    let s = Soul {
        id: object::new(ctx), schema: 1, name, revision: 0, modules: vector[], editing: false,
        origin: Origin {
            producer: type_name::with_defining_ids<W>(),
            source_type: type_name::with_defining_ids<P>(), source: object::id(source),
            source_version, source_hash, minted_by: ctx.sender(),
        },
    };
    s
}

fun find<W>(s: &Soul, name: &vector<u8>): Option<u64> {
    let namespace = type_name::with_defining_ids<W>();
    let mut i = 0;
    while (i < s.modules.length()) {
        if (s.modules[i].namespace == namespace && s.modules[i].name == *name)
            return option::some(i);
        i = i + 1
    };
    option::none()
}

fun index<W, T>(s: &Soul, name: &vector<u8>): u64 {
    let found = find<W>(s, name);
    assert!(found.is_some(), EType);
    let i = found.destroy_some();
    assert!(s.modules[i].value_type == type_name::with_defining_ids<T>(), EType);
    i
}

fun changed(s: &mut Soul, operation: u8, d: &Descriptor) {
    s.revision = s.revision + 1;
    event::emit(Changed {
        soul: object::id(s), revision: s.revision, operation,
        namespace: d.namespace, name: d.name, object: d.object,
    })
}

public fun install<W: drop, T: key + store>(
    s: &mut Soul, witness: W, name: vector<u8>, value: T,
    schema: u16, removable: bool, semantic_hash: vector<u8>, expected: u64,
) {
    ready(s); cas(s, expected); same_module<W, T>(); let _ = witness;
    check_name(&name); hash32(&semantic_hash); assert!(schema > 0, ESchema);
    assert!(find<W>(s, &name).is_none(), EDuplicate);
    assert!(s.modules.length() < MAX_MODULES, ECapacity);
    let d = Descriptor {
        namespace: type_name::with_defining_ids<W>(), name,
        value_type: type_name::with_defining_ids<T>(), object: object::id(&value),
        schema, removable, body_hash: child_hash(&value), semantic_hash,
    };
    dof::add(&mut s.id, ModuleKey<W> { name }, value);
    s.modules.push_back(d); changed(s, 0, &d)
}

public fun borrow_module<W, T: key + store>(s: &Soul, name: vector<u8>): &T {
    ready(s); let _ = index<W, T>(s, &name);
    dof::borrow(&s.id, ModuleKey<W> { name })
}

public fun uninstall<W, T: key + store>(s: &mut Soul, name: vector<u8>, expected: u64): T {
    ready(s); cas(s, expected);
    let i = index<W, T>(s, &name); let d = s.modules[i];
    assert!(d.removable, EPermanent);
    let value = dof::remove<ModuleKey<W>, T>(&mut s.id, ModuleKey<W> { name });
    assert!(object::id(&value) == d.object, EIdentity);
    s.modules.remove(i); changed(s, 1, &d); value
}

public fun begin_update<W: drop, T: key + store>(
    s: &mut Soul, witness: W, name: vector<u8>, expected: u64,
): (T, Edit<W, T>) {
    ready(s); cas(s, expected); same_module<W, T>(); let _ = witness;
    let i = index<W, T>(s, &name); let id = s.modules[i].object;
    let value = dof::remove<ModuleKey<W>, T>(&mut s.id, ModuleKey<W> { name });
    assert!(object::id(&value) == id, EIdentity);
    s.editing = true;
    (value, Edit { soul: object::id(s), object: id, name, revision: expected })
}

public fun commit_update<W: drop, T: key + store>(
    s: &mut Soul, ticket: Edit<W, T>, witness: W, value: T,
    schema: u16, semantic_hash: vector<u8>,
) {
    same_module<W, T>(); let _ = witness; hash32(&semantic_hash);
    let Edit { soul, object: id, name, revision } = ticket;
    assert!(s.editing && soul == object::id(s) && id == object::id(&value), EIdentity);
    cas(s, revision);
    let i = index<W, T>(s, &name);
    let mut d = s.modules[i];
    assert!(d.object == id, EIdentity); assert!(schema >= d.schema, ESchema);
    d.schema = schema; d.body_hash = child_hash(&value); d.semantic_hash = semantic_hash;
    dof::add(&mut s.id, ModuleKey<W> { name }, value);
    *s.modules.borrow_mut(i) = d; s.editing = false; changed(s, 2, &d)
}

public fun revision(s: &Soul): u64 { s.revision }
public fun schema(s: &Soul): u16 { s.schema }
public fun name(s: &Soul): &String { &s.name }
public fun origin(s: &Soul): Origin { s.origin }
public fun source(o: &Origin): ID { o.source }
public fun source_type(o: &Origin): TypeName { o.source_type }
public fun producer(o: &Origin): TypeName { o.producer }
public fun source_version(o: &Origin): u64 { o.source_version }
public fun source_hash(o: &Origin): vector<u8> { o.source_hash }
public fun minted_by(o: &Origin): address { o.minted_by }
public fun module_count(s: &Soul): u64 { ready(s); s.modules.length() }
public fun descriptor<W>(s: &Soul, name: vector<u8>): Option<Descriptor> {
    ready(s); find<W>(s, &name).map!(|i| s.modules[i])
}
public fun module_page(s: &Soul, offset: u64, limit: u64): vector<Descriptor> {
    ready(s); assert!(limit <= MAX_MODULES && offset <= s.modules.length(), EInput);
    let end = if (limit < s.modules.length() - offset) offset + limit else s.modules.length();
    let mut result = vector[]; let mut i = offset;
    while (i < end) { result.push_back(s.modules[i]); i = i + 1 };
    result
}
public fun module_id(d: &Descriptor): ID { d.object }
public fun namespace(d: &Descriptor): TypeName { d.namespace }
public fun module_name(d: &Descriptor): vector<u8> { d.name }
public fun value_type(d: &Descriptor): TypeName { d.value_type }
public fun module_schema(d: &Descriptor): u16 { d.schema }
public fun removable(d: &Descriptor): bool { d.removable }
public fun body_hash(d: &Descriptor): vector<u8> { d.body_hash }
public fun semantic_hash(d: &Descriptor): vector<u8> { d.semantic_hash }
public fun manifest(s: &Soul): Manifest {
    ready(s); Manifest {
        domain: b"soulidity/standard/manifest/v1", soul: object::id(s), schema: s.schema,
        name: s.name, revision: s.revision, origin: s.origin, modules: s.modules,
    }
}
public fun manifest_hash(s: &Soul): vector<u8> { hash::sha3_256(bcs::to_bytes(&manifest(s))) }
public fun assert_manifest(s: &Soul, expected_revision: u64, expected_hash: vector<u8>) {
    ready(s); cas(s, expected_revision); hash32(&expected_hash);
    assert!(manifest_hash(s) == expected_hash, EInput)
}

/// Native whole-asset composition. Unnesting is always available to the actual
/// parent holder; no application can turn this namespace into a permanent lock.
public fun nest(s: &mut Soul, child: Soul, expected: u64) {
    let id = object::id(&child);
    assert!(id != object::id(s), EIdentity);
    let semantic = manifest_hash(&child);
    install(s, NestedSoulWitness {}, bcs::to_bytes(&id), child, 1, true, semantic, expected)
}
public fun nested(s: &Soul, child: ID): &Soul {
    borrow_module<NestedSoulWitness, Soul>(s, bcs::to_bytes(&child))
}
public fun unnest(s: &mut Soul, child: ID, expected: u64): Soul {
    uninstall<NestedSoulWitness, Soul>(s, bcs::to_bytes(&child), expected)
}
/// PTB-compatible value path. No mutable child/root UID or reference escapes;
/// edited child must return under the same parent with the same object ID.
public fun begin_nested_update(s: &mut Soul, child: ID, expected: u64): (Soul, Edit<NestedSoulWitness, Soul>) {
    begin_update(s, NestedSoulWitness {}, bcs::to_bytes(&child), expected)
}
public fun commit_nested_update(s: &mut Soul, ticket: Edit<NestedSoulWitness, Soul>, child: Soul) {
    let semantic = manifest_hash(&child);
    commit_update(s, ticket, NestedSoulWitness {}, child, 1, semantic)
}
```
