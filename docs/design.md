# 设计方案（AgQuotaBar）

## 总体目标
构建一个 **原生 macOS menubar 应用**（无主窗口，仅设置窗口），在菜单栏展示 Antigravity 模型配额，并支持本地模式与 Cloud Code API 模式、多账号与多模型选择。

## 技术选型（Native macOS）
- **语言/框架**：Swift + SwiftUI（原生），配合 AppKit 小范围桥接（状态栏绘制与菜单）。
- **menubar**：使用 `MenuBarExtra`（最低 macOS 13+）。必要时可用 `NSStatusItem` 进行更细粒度绘制控制（圈型图）。
- **设置窗口**：SwiftUI `Settings` Scene + `TabView`（独立窗口）。
- **系统集成**：
  - 开机自启：`SMAppService`（macOS 13+）。
  - Keychain：存储 OAuth token。 
  - 本地存储：`UserDefaults`（偏好与 UI 状态）。

> 备注：`MenuBarExtra` 与 `openSettings` 的配合在 menubar app 场景存在限制，建议通过 AppDelegate/状态控制可靠打开设置窗口。

## 运行时架构

### 模块划分
1. **App 层**
   - `AgQuotaBarApp`：App 入口，注册 `MenuBarExtra` 与 `Settings` Scene。
   - `AppState`（ObservableObject）：全局状态（当前账号、当前模型、配额快照、刷新状态、设置窗口显示）。

2. **UI 层**
   - `MenuBarView`： menubar 图标与数字渲染。
   - `MenuMenuView`：下拉菜单（Section A/B/C）。
   - `SettingsView`：Tab A/B/C（通用/Antigravity/关于）。

3. **数据层**
   - `QuotaService`（Facade）：统一接口，基于当前账号模式（本地/Cloud Code API）返回 `QuotaSnapshot`。
   - `LocalQuotaProvider`：对接本地 Language Server 的 `GetUserStatus`。
   - `CloudQuotaProvider`：OAuth + Cloud Code API（`loadCodeAssist`/`fetchAvailableModels`）。
   - `AccountStore`：账号管理（列表、删除、切换、导入 token）。

4. **存储层**
   - Keychain：OAuth refresh/access token、账号标识。
   - UserDefaults：
     - 选中模型（accountId + modelId）
     - 模型可见性（每个账号可勾选）
     - 轮询间隔
     - UI 偏好（显示百分比、图标颜色模式、语言）

### 数据流（简化）
1. App 启动 → 读取本地设置与账号 → 初始化 `QuotaService`
2. 定时轮询 → 获取 `QuotaSnapshot` → 更新 `AppState` → UI 刷新
3. 用户切换模型 → 更新选中模型 → menubar 显示变化
4. 用户切换账号或重新授权 → 更新账号状态 → 重新拉取配额

## 关键功能设计

### 1. menubar 圈型图显示
- **颜色规则**：
  - <20%：红色
  - <50%：黄色
  - 其他：绿色
  - 无账号/无模型/异常：灰色
- **单色模式**：强制使用深灰色圈型图。
- **显示百分比数字**：紧挨圈型图显示（可关）。
- **尺寸**：根据 menubar 实际高度自适应，保持清晰可读（无需固定 18/20）。

实现方式：
- SwiftUI Canvas 或 NSImage 绘制圆环（推荐 Canvas 便于主题适配）。
- 结合 `MenuBarExtra` label 或 `NSStatusItem.button.image`。

### 2. 菜单结构
- **Section A**：账号分组模型列表（最多显示 7 个模型），显示百分比，支持勾选。
- **Section B**：轮询间隔选项（30s/2m/1h）+ 手动刷新。
- **Section C**：设置 / 退出。

### 3. 设置窗口（独立窗口）
- **Tab A**：
  - 启动时运行
  - 是否显示百分比数字
  - 图标颜色模式（单色 / 彩色）
  - 语言（中/英，重启生效）
- **Tab B**：
  - 账号列表（新增 / 移除 / 切换默认账号）
  - OAuth 登录（PKCE）
  - 从本地 Antigravity 导入 refresh_token（可选）
  - 每个账号下模型可见性管理（决定 menubar 菜单展示）
- **Tab C**：关于与免责声明/条款

### 4. 首次启动行为
- 若无账号配置：自动打开设置窗口并定位到 Antigravity Tab。

### 5. 异常与过期
- menubar 灰色圈型图。
- 设置页显示黄色感叹号提示（账号或模型层级）。

## OAuth 与本地模式支持
- OAuth PKCE 流程：本地回调服务器，获得 refresh_token 并保存 Keychain。
  - **端口策略建议**：默认使用随机可用端口（系统分配），回调地址固定 `http://127.0.0.1:{port}/callback`；必要时可提供 3 个备用端口范围（例如 27100-27120）作为失败回退。
- 账号来源：
  - OAuth 直接登录
  - 从本地 Antigravity 数据库导入 refresh_token
- 本地模式：自动检测 language_server 进程，获取端口与 CSRF token，调用 `GetUserStatus`。

## 多语言策略（中/英）
- 使用 `Localizable.strings` 管理 UI 文案。
- 语言切换为 App 内设置，**重启生效**。
- 文案管理：按模块划分 key（Menu, Settings, Errors, About）。

## E2E 验收建议（每个 Phase 的共用标准）
- 应用可启动，menubar 出现图标。
- 设置窗口可打开、切换 Tab。
- 轮询间隔生效（可观察到日志或 UI 更新时间）。
- 手动刷新立即生效。
- OAuth 登录完成后能显示模型列表。

## 设计阶段确认结果
1. **最低支持 macOS 版本**：13+。
2. **圈型图尺寸**：自适应 menubar 高度，保持清晰可读。
3. **语言切换**：重启生效。
4. **OAuth 回调端口**：建议默认随机端口，必要时提供固定范围回退。
5. **账号显示名称**：使用邮箱，不提供自定义别名。

## 可扩展性（面向多模型/多平台）
为未来接入其他模型（例如 Codex、Gemini 等）预留扩展点：
- **Provider 抽象**：
  - 定义 `QuotaProvider` 协议（`fetchQuota()` / `getModels()` / `authState()`），每个服务实现独立 Provider。
  - `QuotaService` 只负责调度与合并结果。
- **账号与模型命名空间**：
  - `accountId` 包含 provider 前缀（如 `antigravity:email`）。
  - `modelId` 同样包含 provider 前缀，避免跨平台冲突。
- **设置页面结构**：
  - Tab B 使用可扩展 Provider 列表（左侧 provider 切换，右侧账号/模型配置）。
- **UI 统一展示**：
  - menubar 菜单统一展示（账号 → 模型），但保留 provider 标识或图标以便区分。
- **鉴权扩展**：
  - 将 OAuth / API Key / 本地进程等授权方式抽象为 `AuthStrategy`。
