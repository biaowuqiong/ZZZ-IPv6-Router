# ZZZ IPv6 Router

为《绝区零》国服 PC 启动器选择并固化一个经过验证的 IPv6 下载 CDN 路由。适用于 IPv4 下载受到明显限速、但 IPv6 连接更快的 Windows 网络环境。

它不是代理、VPN 或“IPv4 转 IPv6”隧道。工具会测速候选 IPv6 CDN，并且只有在原始下载域名的 TLS 证书校验和 HTTP Range 请求均通过后，才写入 Windows `hosts`。VPN/TUN 模式可以保持开启。

## 最简单的用法（推荐）

1. 打开 [Releases](https://github.com/biaowuqiong/ZZZ-IPv6-Router/releases)，下载名称以 `windows.exe` 结尾的文件。
2. 双击 EXE，并在 Windows 用户账户控制窗口中选择“是”。
3. 点击蓝色的“**一键启用 IPv6 加速**”，等待状态显示“IPv6 加速已启用”。

无需安装 PowerShell 模块、.NET SDK 或其他软件。测速、计划任务和后续维护都会自动完成，也可以在同一个窗口中重新测速或卸载。

> 当前 EXE 没有商业代码签名证书，因此 Windows SmartScreen 可能显示“未知发布者”。请只从本仓库 Release 下载，并可使用同名 `.sha256` 文件核对完整性。EXE 完全由仓库中的公开源码构建，不会从互联网下载可执行代码。

## 特性

- 首次运行对候选 IPv6 节点测速，选择当前网络下最快的有效节点
- 每 6 小时检查一次；健康节点直接复用，默认每 7 天重新测速
- 节点失效且没有替代节点时，删除托管映射并自动回退默认 DNS
- 只管理 `autopatchcn.juequling.com`，不改系统 IPv4/IPv6 优先级
- 不安装驱动、证书、代理或第三方二进制文件
- 提供单文件图形界面，无需使用命令行
- 提供完整卸载脚本，并尽量恢复安装前已有的同域名记录

## 系统要求

- Windows 10 或 Windows 11
- 可用的公网 IPv6 连接
- Windows PowerShell 5.1 或 PowerShell 7
- 管理员权限（修改 `hosts` 和创建计划任务所必需）

## PowerShell 安装（高级用户）

下载或克隆本仓库，检查脚本内容后，以管理员身份打开 PowerShell，在项目目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Install.ps1
```

安装后会立即测速并应用路由，同时创建计划任务 `ZZZ-IPv6-Router`。运行以下命令查看最近一次结果：

```powershell
powershell -ExecutionPolicy Bypass -File .\Get-Status.ps1
```

强制重新测速：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Program Files\ZZZIPv6Router\Update-ZZZIPv6Route.ps1" -ForceBenchmark
```

## 卸载

以管理员身份在项目目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

卸载只删除本项目管理的 `hosts` 区块、计划任务和安装目录，不会用旧备份覆盖整个 `hosts` 文件，因此不会抹掉安装后由其他软件或用户添加的记录。

## 配置与工作原理

默认配置位于 `config.default.json`。安装时它会复制到：

```text
C:\ProgramData\ZZZIPv6Router\settings.json
```

之后重复安装默认保留本地配置；如需用仓库默认值覆盖，请执行 `Install.ps1 -ReplaceSettings`。

验证流程如下：

1. 使用候选 IPv6 地址连接 CDN，但保留原始 HTTPS 主机名。
2. 校验证书必须匹配原始域名。
3. 请求少量官方公开下载文件，确认服务器支持有效的 `206 Partial Content`。
4. 按实际下载速度选择节点，将单条映射写入带明确标记的 `hosts` 区块。
5. 后续定期健康检查；全部失败时移除该区块，让系统恢复正常 DNS 解析。

状态文件位于 `C:\ProgramData\ZZZIPv6Router\status.json`。最近一次修改前的 `hosts` 副本保存在同一目录，仅用于故障排查；卸载不会整文件回滚。

## 已知限制

- 当前版本只针对《绝区零》国服启动器目前使用的下载域名。米哈游改变域名或下载路径后，配置可能需要更新。
- 实际速度取决于运营商、校园网出口、Wi-Fi、CDN 负载和本机磁盘速度，不能保证提速。
- 候选地址是公开网络端点，可能随时变化；所有地址在采用前都会重新进行 TLS 与内容请求验证。
- 请遵守所在地网络及校园网使用规定。本项目只改变合规 IPv6 路由选择，不绕过登录、计费或访问控制。

## 隐私

工具不会上传日志、设备标识或账号信息。网络请求仅用于访问游戏官方下载对象，以及在静态候选全部失效时通过 Google Public DNS 查询公开 AAAA 记录。

## 免责声明

本项目与米哈游、HoYoverse 或《绝区零》官方无关联。“绝区零”等名称及商标归其权利人所有。使用前请自行审查脚本并承担风险。

## License

[MIT](LICENSE)
