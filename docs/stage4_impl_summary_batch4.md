# 阶段4 批次4 实现摘要

> 实现人：寇豆码（Kou, software-engineer-2）
> 实现时间：阶段4批次4收尾
> 基于事实表：docs/stage4_facts_table_batch4.md
> 主理人决策：5项疑问全部确认

---

## 实现概览

| 子项 | 状态 | 说明 |
|---|---|---|
| 4.7.1 Autopilot改纯SSE | **不需要做** | 事实表确认iOS轮询是对齐原版useAssistedAutopilotStatus.ts+autopilotStatus.ts:112-120的合理设计 |
| 4.7.2 CharacterSchedulerSimulator | **已完成** | 纯前端mock，3角色+排序算法+上下文生成+Token估算+算法说明 |
| 4.7.3 KnowledgeJsonView | **已完成** | JSON编辑子组件+APIEndpoint.Knowledge端点+StoryKnowledge memberwise init |
| 4.7.4 单元测试 | **不执行** | 主理人决策A，建议独立阶段规划 |

---

## 文件清单

### 新建（2个）

1. **`Cangjie/Views/Debug/CharacterSchedulerSimulatorView.swift`**（~600行）
   - 纯前端Debug工具，对齐原版 components/debug/CharacterSchedulerSimulator.vue:1-810
   - 无API调用，3个硬编码角色mock数据（林羽/艾达/苏晴）
   - 控制面板：2个Toggle（大纲提及艾达/苏晴）+ 1个Slider（最大角色数1-3）
   - 角色卡片网格：名称+重要性badge+活动度+心理状态+待机动作+badges
   - 排序算法：mentioned优先 → importance优先级(protagonist=0/major=1/minor=2) → activityCount降序 → 截断
   - 上下文Prompt生成：角色/描述/心理状态/待机动作 + activityCount<=1时加连续性约束
   - Token估算：ceil(context.count / 4)
   - 算法说明面板：4步静态UI

2. **`Cangjie/Views/Knowledge/KnowledgeJsonView.swift`**（~290行）
   - JSON编辑子组件，对齐原版 components/knowledge/KnowledgeJsonView.vue:1-136
   - 接收 novelId 参数 + onReload 回调（可独立运行子组件）
   - 工具栏：保存JSON按钮(loading状态) + 格式化按钮
   - TextEditor：JSON文本编辑，等宽字体
   - 加载：GET /novels/{id}/knowledge → 提取facts → JSON序列化显示
   - 格式化：JSONSerialization解析→重新序列化
   - 保存：校验数组 → CangjieDecoder解码[KnowledgeTriple] → PUT /novels/{id}/knowledge → onReload回调
   - 错误提示：红色文本
   - 成功提示：2秒自动消失的绿色banner

### 修改（4个）

3. **`Cangjie/Networking/APIEndpoint.swift`**
   - 新增 `enum Knowledge`（get/update/search/generate 4个case）
   - 新增 `extension APIEndpoint.Knowledge: APIEndpoint.EndpointInfo`（path/method/queryItems）
   - 对齐原版 api/knowledge.ts:71-106

4. **`Cangjie/Models/KnowledgeGraphModels.swift`**
   - StoryKnowledge 补 memberwise init（教训8：自定义init(from:)的struct需补memberwise init）
   - 参数：version=1, premiseLock="", chapters=[], facts=[] 均有默认值

5. **`Cangjie/App/AppState.swift`**
   - SidebarDestination 新增 `.debug = "调试工具"` case
   - iconName 新增 `.debug → "ladybug.fill"`

6. **`Cangjie/Views/Root/RootView.swift`**
   - contentColumn switch 新增 `.debug → CharacterSchedulerSimulatorView()`
   - Debug工具不需要选中小说，直接渲染

7. **`Cangjie/Views/Root/SidebarView.swift`**
   - 工具分组 toolItems 新增 `.debug`
   - 原有 `[.export, .snapshot, .trace]` → `[.export, .snapshot, .trace, .debug]`

---

## 关键设计决策

### 1. CharacterSchedulerSimulatorView 排序算法的 Swift 适配
原版Vue在sort闭包中直接设置reason字段（`a.reason = ...`），Swift的sort闭包无法修改元素。解决方案：排序后遍历notMentioned，根据notMentioned范围内是否有同优先级角色推断reason（同优先级→"活动度"，否则→"重要性"），功能等价。

### 2. KnowledgeJsonView 的 JSON 编辑与编解码
- 加载：GET → StoryKnowledge → JSONEncoder序列化facts数组 → 显示
- 格式化：JSONSerialization解析 → 重新序列化（prettyPrinted + sortedKeys）
- 保存：JSONSerialization校验数组 → CangjieDecoder解码[KnowledgeTriple] → 构造StoryKnowledge → PUT
- 使用CangjieDecoder.shared解码（铁律3：处理Python datetime.isoformat微秒6位）

### 3. StoryKnowledge memberwise init
StoryKnowledge原有自定义init(from:)导致编译器不生成memberwise init。补上后KnowledgeJsonView可用`StoryKnowledge(version:premiseLock:chapters:facts:)`构造PUT请求体。参数均有默认值，不影响现有代码。

### 4. APIEndpoint.Knowledge 端点设计
对齐原版 api/knowledge.ts:71-106 的5个方法：
- `get(novelId:)` → GET /novels/{id}/knowledge
- `update(novelId:)` → PUT /novels/{id}/knowledge  
- `search(novelId:query:k:)` → GET /novels/{id}/knowledge/search?q=...&k=...
- `generate(novelId:)` → POST /novels/{id}/knowledge/generate
全部挂载于默认前缀 /api/v1（NOVELS_API_PREFIX）

---

## 全局一致性审查

### IS_PASS: YES

#### 检查项1：跨文件导入一致性
- CharacterSchedulerSimulatorView.swift：仅 import SwiftUI，无外部依赖 ✓
- KnowledgeJsonView.swift：仅 import SwiftUI，APIClient/APIEndpoint/StoryKnowledge/CangjieDecoder/Theme均为同模块 ✓
- 无循环依赖 ✓

#### 检查项2：接口契约合规
- APIEndpoint.Knowledge 实现 EndpointInfo 协议（path/method/queryItems 全覆盖）✓
- KnowledgeJsonView 调用 `APIClient.shared.request(APIEndpoint.Knowledge.get(novelId:))` 签名匹配 ✓
- KnowledgeJsonView 调用 `APIClient.shared.request(APIEndpoint.Knowledge.update(novelId:), body: StoryKnowledge)` 签名匹配 ✓
- StoryKnowledge memberwise init 参数与 CodingKeys 对齐（premiseLock → premise_lock）✓

#### 检查项3：数据流正确性
- GET → StoryKnowledge → 提取 version/premiseLock/chapters → 序列化 facts → 显示
- 保存 → 解析JSON → [KnowledgeTriple] → StoryKnowledge(version, premiseLock, chapters, facts) → PUT → onReload → reload
- 数据流完整，无类型不匹配 ✓

#### 检查项4：SidebarDestination 枚举完整性
- `.debug` case 已添加到枚举定义 ✓
- iconName switch 已添加 `.debug` case ✓
- RootView contentColumn switch 已添加 `.debug` case ✓
- SidebarView toolItems 已包含 `.debug` ✓
- 无遗漏的 switch 语句 ✓

#### 检查项5：iOS 16 兼容性
- 无 @Observable/@Bindable ✓
- 无 NavigationSplitView ✓
- 无 .scrollContentMargins 等 iOS 17+ API ✓
- Toggle/Slider/TextEditor 均为 iOS 16 原生组件 ✓

#### 检查项6：技术约定遵守
- 零新SPM依赖 ✓
- Store用ObservableObject+@Published（本批次无新Store）✓
- 日期解码用CangjieDecoder.shared ✓
- APIEndpoint.defaultPrefix = /api/v1 ✓
- 输入框用TextField/TextEditor（不用SecureField）✓

---

## 对齐度自报

| 子项 | 对齐原版 | 对齐度 |
|---|---|---|
| 4.7.1 | 事实表确认不需要改 | 100%（无需改动） |
| 4.7.2 CharacterSchedulerSimulator | 逐条对齐原版:1-810 | 100% |
| 4.7.3 KnowledgeJsonView | 逐条对齐原版:1-136 | 100% |
| 4.7.4 单元测试 | 主理人决策不执行 | N/A |

**总体对齐度：100%**

---

## 未完成/后续工作

1. **KnowledgePanel 宿主**：KnowledgeJsonView 设计为可独立运行子组件，未来嵌入KnowledgePanel时直接使用（主理人决策Q1-A）
2. **单元测试**：建议作为独立阶段统一规划（主理人决策Q4-A）
3. **交接文档v9**：可将"单元测试"和"KnowledgePanel宿主"记入"未来工作"
