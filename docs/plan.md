# 开发计划（Phase 切分）

## Phase 1：基础壳 + menubar 展示
**目标**：应用可运行，menubar 出现图标与基础菜单，设置窗口可打开。

**范围**
- SwiftUI App 入口 + `MenuBarExtra`
- menubar 圈型图绘制（占位/静态值）
- 菜单三段结构（A/B/C）占位
- 设置窗口（Tab A/B/C）框架
- 首次启动自动打开设置窗口并定位到 Antigravity Tab

**E2E 验收**
- 应用启动后 menubar 出现图标
- 点击 menubar 能看到三段菜单
- 点击“设置”可打开设置窗口并切换 Tab
- 首次启动自动打开设置窗口并定位到 Antigravity Tab

---

## Phase 2：本地模式配额查询
**目标**：完成本地 Language Server 配额获取与轮询，menubar 展示实时数据，便于尽早验证。

**范围**
- 端口与 CSRF 探测
- `GetUserStatus` 请求实现（HTTPS/HTTP 回退）
- 配额解析与 `QuotaSnapshot`
- 轮询与重试策略
- 异常/过期状态 UI（灰色 + 设置页黄感叹号）

**E2E 验收**
- 启动 Antigravity IDE 后可获取配额
- menubar 显示剩余百分比与颜色阈值
- 网络/接口异常时灰色显示并提示

---

## Phase 3：账号与设置持久化
**目标**：实现通用设置、账号列表、模型显示控制与偏好保存。

**范围**
- 通用设置：开机自启、显示百分比、颜色模式、语言（重启生效）
- AccountStore：账号列表（新增/移除/切换默认）与持久化
- 模型可见性管理（决定 menubar 菜单展示）
- menubar 菜单最多显示 7 个模型

**E2E 验收**
- 设置项修改后保存并重启仍生效
- 账号可新增/移除/切换默认
- 模型勾选可影响 menubar 菜单显示，且最多显示 7 个

---

## Phase 4：Cloud Code API 模式 + OAuth
**目标**：完成 OAuth 流程与 Cloud Code API 配额查询。

**范围**
- OAuth PKCE 登录 + Keychain 存储
- `loadCodeAssist` / `fetchAvailableModels` 接入
- 用户邮箱获取与账号绑定
- Token 自动刷新与错误处理

**E2E 验收**
- OAuth 登录成功后可获取账号与模型配额
- Token 过期自动刷新
- 401 需重新登录并提示

---

## Phase 5：UI 完整度与体验收尾
**目标**：补齐 UI 文案、多语言、关于页与免责声明/条款。

**范围**
- 多语言文案文件（中/英）
- 关于页内容与免责声明/Terms 文案
- 细节 UI：颜色、图标、模型排序

**E2E 验收**
- 中英文切换（重启后生效）
- 关于页文案展示正确
- menubar 显示符合规范（颜色/数字/单色模式）
