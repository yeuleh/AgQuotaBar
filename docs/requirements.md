# 需求确认（AgQuotaBar）

## 目标
在 macOS menubar 中展示 Google Antigravity 模型配额使用情况，支持本地模式与 Cloud Code API 模式，提供设置窗口进行账号/模型/显示配置。

## 范围与核心功能
1. **menubar 展示**
   - 以“圈型图 + 百分比数字（在图旁边）”显示当前选中模型的剩余配额。
   - 颜色阈值：
     - 剩余 < 20%：红色
     - 剩余 < 50%：黄色
     - 其他：绿色
   - 当无账号或无可用模型时：显示灰色圈型图。

2. **点击 menubar 的下拉菜单**（三段）
   - **Section A：模型列表**
     - 分层结构展示**所有账号**的模型（账号 → 模型）。
     - 每个模型显示剩余百分比。
     - 点击模型即选中，菜单项前显示勾号，menubar 仅显示当前选中模型。
     - 菜单中只展示在设置页中被勾选的模型。
     - 为避免过长：下拉菜单最多展示 7 个模型（其余需在设置中调整显示）。
   - **Section B：轮询间隔**
     - 选项包含：`30s`、`2m`、`1h`（如需更多档位，设计阶段再确认）。
     - 支持手动刷新入口（即时发起请求）。
   - **Section C：操作**
     - “设置”（打开设置窗口）
     - “退出”（彻底退出应用）

3. **设置窗口（独立 window）**
   - **Tab A：通用设置**
     - 启动时运行
     - menubar 是否显示百分比数字
     - 图标颜色设置：单色 / 彩色（单色时使用深灰色圈型图）
     - 语言：中英文切换
   - **Tab B：Antigravity 设置**
     - 支持**本地模式** + **Cloud Code API 模式**
     - 支持多个 Google 账号：列表、移除、切换默认/当前账号
     - 支持 OAuth 授权（PKCE），并可从本地 Antigravity 导入 refresh_token（可选但期望支持）
     - 账号下模型列表：可勾选“是否显示在 menubar 菜单”
   - **Tab C：关于**
     - 项目名称：AgQuotaBar
     - 作者：Leon Yeu
     - 邮箱：github@ulenium.com
     - Bundle ID：com.ulenium.agquotabar（仅开发配置使用，关于页不展示）
     - 免责声明：免除因 bug 或使用导致的任何损害责任（详细文案在设计阶段定稿）
     - 用户条款：与免责声明一起展示（详细文案在设计阶段定稿）

4. **首次启动行为**
   - 自动打开设置窗口，并定位到 Antigravity 设置 Tab。

5. **异常/过期状态**
   - menubar 圈型图灰色化。
   - 设置页面用黄色感叹号提示账号/模型异常。

## 数据来源
- **本地模式**：基于本地 Language Server 的 `GetUserStatus` 端点（参考 `docs/quota-query.md`）。
- **Cloud Code API 模式**：OAuth + `loadCodeAssist` / `fetchAvailableModels`（参考 `docs/quota-query.md`）。

## E2E 验收
- 用户可在本机运行应用，完成基本流程（账号配置 → menubar 展示 → 切换模型/轮询 → 设置窗口）作为验收。

## 待确认/待细化项（设计阶段确认）
- menubar 圈型图具体色值与交互细节。
- 是否需要更多轮询档位（例如 5m、15m）。
- 账号层级与模型菜单显示的细节（名称、排序）。
- 免责声明与 Terms 具体文案。
