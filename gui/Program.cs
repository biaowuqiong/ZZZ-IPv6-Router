using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

[assembly: AssemblyTitle("ZZZ IPv6 Router")]
[assembly: AssemblyDescription("TLS-validated IPv6 routing for Zenless Zone Zero downloads")]
[assembly: AssemblyCompany("biaowuqiong")]
[assembly: AssemblyProduct("ZZZ IPv6 Router")]
[assembly: AssemblyCopyright("Copyright © 2026 biaowuqiong")]
[assembly: AssemblyVersion("0.2.0.0")]
[assembly: AssemblyFileVersion("0.2.0.0")]

namespace ZZZIPv6Router
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }
    }

    internal sealed class MainForm : Form
    {
        private const string Version = "0.2.0";
        private const string RepositoryUrl = "https://github.com/biaowuqiong/ZZZ-IPv6-Router";

        private readonly Label statusTitle;
        private readonly Label statusDetail;
        private readonly TextBox outputBox;
        private readonly Button installButton;
        private readonly Button benchmarkButton;
        private readonly Button refreshButton;
        private readonly Button uninstallButton;
        private string extractedPackageDirectory;

        internal MainForm()
        {
            Text = "ZZZ IPv6 Router";
            Icon = SystemIcons.Shield;
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = true;
            ClientSize = new Size(720, 570);
            AutoScaleMode = AutoScaleMode.Dpi;
            Font = new Font("Microsoft YaHei UI", 9F, FontStyle.Regular, GraphicsUnit.Point);
            BackColor = Color.FromArgb(245, 247, 250);

            Panel header = new Panel();
            header.Dock = DockStyle.Top;
            header.Height = 112;
            header.BackColor = Color.FromArgb(35, 67, 135);
            Controls.Add(header);

            Label title = new Label();
            title.Text = "绝区零 IPv6 下载加速";
            title.ForeColor = Color.White;
            title.Font = new Font(Font.FontFamily, 20F, FontStyle.Bold);
            title.AutoSize = true;
            title.Location = new Point(24, 20);
            header.Controls.Add(title);

            Label subtitle = new Label();
            subtitle.Text = "自动选择并保持经过 HTTPS 证书验证的 IPv6 CDN 路由";
            subtitle.ForeColor = Color.FromArgb(220, 230, 250);
            subtitle.Font = new Font(Font.FontFamily, 10F);
            subtitle.AutoSize = true;
            subtitle.Location = new Point(27, 68);
            header.Controls.Add(subtitle);

            Panel statusPanel = new Panel();
            statusPanel.Location = new Point(24, 132);
            statusPanel.Size = new Size(672, 92);
            statusPanel.BackColor = Color.White;
            statusPanel.BorderStyle = BorderStyle.FixedSingle;
            Controls.Add(statusPanel);

            statusTitle = new Label();
            statusTitle.Text = "正在读取状态…";
            statusTitle.Font = new Font(Font.FontFamily, 13F, FontStyle.Bold);
            statusTitle.AutoSize = true;
            statusTitle.Location = new Point(18, 14);
            statusPanel.Controls.Add(statusTitle);

            statusDetail = new Label();
            statusDetail.Text = "";
            statusDetail.ForeColor = Color.DimGray;
            statusDetail.AutoEllipsis = true;
            statusDetail.Location = new Point(20, 52);
            statusDetail.Size = new Size(630, 25);
            statusPanel.Controls.Add(statusDetail);

            installButton = CreateButton("一键启用 IPv6 加速", new Point(24, 244), new Size(276, 52), true);
            installButton.Click += InstallButtonClick;
            Controls.Add(installButton);

            benchmarkButton = CreateButton("重新测速并选择", new Point(316, 244), new Size(184, 52), false);
            benchmarkButton.Click += BenchmarkButtonClick;
            Controls.Add(benchmarkButton);

            refreshButton = CreateButton("刷新状态", new Point(516, 244), new Size(86, 52), false);
            refreshButton.Click += delegate { RefreshStatus(); };
            Controls.Add(refreshButton);

            uninstallButton = CreateButton("卸载", new Point(610, 244), new Size(86, 52), false);
            uninstallButton.Click += UninstallButtonClick;
            Controls.Add(uninstallButton);

            Label outputLabel = new Label();
            outputLabel.Text = "运行信息";
            outputLabel.Font = new Font(Font.FontFamily, 10F, FontStyle.Bold);
            outputLabel.AutoSize = true;
            outputLabel.Location = new Point(24, 318);
            Controls.Add(outputLabel);

            outputBox = new TextBox();
            outputBox.Location = new Point(24, 344);
            outputBox.Size = new Size(672, 148);
            outputBox.Multiline = true;
            outputBox.ReadOnly = true;
            outputBox.ScrollBars = ScrollBars.Vertical;
            outputBox.BackColor = Color.White;
            outputBox.Text = "首次使用请点击“一键启用 IPv6 加速”。程序会测速约 10–60 秒。";
            Controls.Add(outputBox);

            Label safety = new Label();
            safety.Text = "仅修改一个带标记的 hosts 区块；不安装驱动、证书、代理或 VPN。";
            safety.ForeColor = Color.DimGray;
            safety.AutoSize = true;
            safety.Location = new Point(24, 510);
            Controls.Add(safety);

            LinkLabel repositoryLink = new LinkLabel();
            repositoryLink.Text = "查看开源代码";
            repositoryLink.AutoSize = true;
            repositoryLink.Location = new Point(24, 540);
            repositoryLink.LinkClicked += delegate { OpenRepository(); };
            Controls.Add(repositoryLink);

            Label versionLabel = new Label();
            versionLabel.Text = "v" + Version;
            versionLabel.ForeColor = Color.Gray;
            versionLabel.AutoSize = true;
            versionLabel.Location = new Point(654, 540);
            Controls.Add(versionLabel);

            Shown += delegate { RefreshStatus(); };
            FormClosed += delegate { CleanupExtractedPackage(); };
        }

        private Button CreateButton(string text, Point location, Size size, bool primary)
        {
            Button button = new Button();
            button.Text = text;
            button.Location = location;
            button.Size = size;
            button.FlatStyle = FlatStyle.Flat;
            button.Cursor = Cursors.Hand;
            if (primary)
            {
                button.BackColor = Color.FromArgb(40, 105, 210);
                button.ForeColor = Color.White;
                button.FlatAppearance.BorderSize = 0;
                button.Font = new Font(Font.FontFamily, 11F, FontStyle.Bold);
            }
            else
            {
                button.BackColor = Color.White;
                button.ForeColor = Color.FromArgb(35, 67, 135);
                button.FlatAppearance.BorderColor = Color.FromArgb(175, 185, 205);
            }
            return button;
        }

        private async void InstallButtonClick(object sender, EventArgs e)
        {
            await RunScriptAction("正在安装并测速，请稍候…", "Install.ps1", "");
        }

        private async void BenchmarkButtonClick(object sender, EventArgs e)
        {
            string updater = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                "ZZZIPv6Router", "Update-ZZZIPv6Route.ps1");
            if (!File.Exists(updater))
            {
                MessageBox.Show(this, "请先点击“一键启用 IPv6 加速”。", "尚未安装",
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            await RunExternalScriptAction("正在重新测速，请稍候…", updater, "-ForceBenchmark");
        }

        private async void UninstallButtonClick(object sender, EventArgs e)
        {
            DialogResult answer = MessageBox.Show(this,
                "确定卸载并恢复 Windows 默认 DNS 路由吗？\r\n\r\n不会覆盖 hosts 中其他软件或用户添加的记录。",
                "确认卸载", MessageBoxButtons.YesNo, MessageBoxIcon.Question,
                MessageBoxDefaultButton.Button2);
            if (answer != DialogResult.Yes)
            {
                return;
            }
            await RunScriptAction("正在卸载…", "Uninstall.ps1", "");
        }

        private async Task RunScriptAction(string busyMessage, string relativeScript, string arguments)
        {
            string packageDirectory = EnsureExtractedPackage();
            string scriptPath = Path.Combine(packageDirectory, relativeScript);
            await RunExternalScriptAction(busyMessage, scriptPath, arguments);
        }

        private async Task RunExternalScriptAction(string busyMessage, string scriptPath, string arguments)
        {
            SetBusy(true, busyMessage);
            ProcessResult result = await Task.Run(delegate { return RunPowerShell(scriptPath, arguments); });
            outputBox.Text = BuildDisplayOutput(result);
            SetBusy(false, "");
            RefreshStatus();

            if (result.ExitCode != 0)
            {
                MessageBox.Show(this,
                    "操作没有成功完成。请查看窗口中的运行信息。\r\n如果所有 IPv6 节点都不可用，程序会自动保持默认 DNS，不会阻断下载。",
                    "操作未完成", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private static ProcessResult RunPowerShell(string scriptPath, string extraArguments)
        {
            string powerShell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),
                "WindowsPowerShell", "v1.0", "powershell.exe");
            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName = powerShell;
            startInfo.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"" +
                scriptPath + "\" " + extraArguments;
            startInfo.WorkingDirectory = Path.GetDirectoryName(scriptPath);
            startInfo.UseShellExecute = false;
            startInfo.CreateNoWindow = true;
            startInfo.RedirectStandardOutput = true;
            startInfo.RedirectStandardError = true;

            using (Process process = Process.Start(startInfo))
            {
                Task<string> standardOutput = process.StandardOutput.ReadToEndAsync();
                Task<string> standardError = process.StandardError.ReadToEndAsync();
                process.WaitForExit();
                Task.WaitAll(standardOutput, standardError);
                return new ProcessResult(process.ExitCode, standardOutput.Result, standardError.Result);
            }
        }

        private string EnsureExtractedPackage()
        {
            if (!String.IsNullOrEmpty(extractedPackageDirectory) && Directory.Exists(extractedPackageDirectory))
            {
                return extractedPackageDirectory;
            }

            extractedPackageDirectory = Path.Combine(Path.GetTempPath(),
                "ZZZIPv6Router-GUI-" + Process.GetCurrentProcess().Id.ToString());
            Directory.CreateDirectory(extractedPackageDirectory);
            Directory.CreateDirectory(Path.Combine(extractedPackageDirectory, "src"));

            ExtractResource("ZZZIPv6Router.Install.ps1", Path.Combine(extractedPackageDirectory, "Install.ps1"));
            ExtractResource("ZZZIPv6Router.Uninstall.ps1", Path.Combine(extractedPackageDirectory, "Uninstall.ps1"));
            ExtractResource("ZZZIPv6Router.GetStatus.ps1", Path.Combine(extractedPackageDirectory, "Get-Status.ps1"));
            ExtractResource("ZZZIPv6Router.Config", Path.Combine(extractedPackageDirectory, "config.default.json"));
            ExtractResource("ZZZIPv6Router.Update.ps1",
                Path.Combine(extractedPackageDirectory, "src", "Update-ZZZIPv6Route.ps1"));
            return extractedPackageDirectory;
        }

        private static void ExtractResource(string resourceName, string destination)
        {
            using (Stream source = Assembly.GetExecutingAssembly().GetManifestResourceStream(resourceName))
            {
                if (source == null)
                {
                    throw new InvalidOperationException("Embedded resource is missing: " + resourceName);
                }
                using (FileStream target = new FileStream(destination, FileMode.Create, FileAccess.Write, FileShare.None))
                {
                    source.CopyTo(target);
                }
            }
        }

        private void RefreshStatus()
        {
            string dataDirectory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
                "ZZZIPv6Router");
            string statusPath = Path.Combine(dataDirectory, "status.json");
            if (!File.Exists(statusPath))
            {
                string legacyStatus = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
                    "Codex", "ZZZIPv6Router", "status.json");
                if (File.Exists(legacyStatus))
                {
                    statusTitle.Text = "检测到早期测试版";
                    statusTitle.ForeColor = Color.FromArgb(190, 115, 0);
                    statusDetail.Text = "点击“一键启用 IPv6 加速”即可迁移到公开版。";
                }
                else
                {
                    statusTitle.Text = "尚未启用";
                    statusTitle.ForeColor = Color.FromArgb(90, 100, 115);
                    statusDetail.Text = "点击下方蓝色按钮，程序会自动测速、安装并定期维护。";
                }
                return;
            }

            try
            {
                JavaScriptSerializer serializer = new JavaScriptSerializer();
                Dictionary<string, object> status = serializer.Deserialize<Dictionary<string, object>>(
                    File.ReadAllText(statusPath, Encoding.UTF8));
                string state = ReadValue(status, "state");
                string selected = ReadValue(status, "selectedIPv6");
                string updated = ReadValue(status, "updatedAt");

                if (String.Equals(state, "IPv6Ready", StringComparison.OrdinalIgnoreCase))
                {
                    statusTitle.Text = "IPv6 加速已启用";
                    statusTitle.ForeColor = Color.FromArgb(15, 130, 80);
                    statusDetail.Text = "当前节点：" + selected + "    最近检查：" + updated;
                }
                else
                {
                    statusTitle.Text = "当前使用默认 DNS";
                    statusTitle.ForeColor = Color.FromArgb(190, 115, 0);
                    statusDetail.Text = "暂未找到通过验证的 IPv6 节点；计划任务稍后会自动重试。";
                }
            }
            catch (Exception exception)
            {
                statusTitle.Text = "状态文件无法读取";
                statusTitle.ForeColor = Color.Firebrick;
                statusDetail.Text = exception.Message;
            }
        }

        private static string ReadValue(Dictionary<string, object> values, string key)
        {
            object value;
            if (values.TryGetValue(key, out value) && value != null)
            {
                return Convert.ToString(value);
            }
            return "—";
        }

        private void SetBusy(bool busy, string message)
        {
            installButton.Enabled = !busy;
            benchmarkButton.Enabled = !busy;
            refreshButton.Enabled = !busy;
            uninstallButton.Enabled = !busy;
            UseWaitCursor = busy;
            if (busy)
            {
                outputBox.Text = message;
            }
        }

        private static string BuildDisplayOutput(ProcessResult result)
        {
            StringBuilder builder = new StringBuilder();
            if (!String.IsNullOrWhiteSpace(result.StandardOutput))
            {
                builder.AppendLine(result.StandardOutput.Trim());
            }
            if (!String.IsNullOrWhiteSpace(result.StandardError))
            {
                builder.AppendLine(result.StandardError.Trim());
            }
            if (builder.Length == 0)
            {
                builder.AppendLine(result.ExitCode == 0 ? "操作已完成。" : "操作未完成。退出代码：" + result.ExitCode);
            }
            return builder.ToString();
        }

        private static void OpenRepository()
        {
            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName = RepositoryUrl;
            startInfo.UseShellExecute = true;
            Process.Start(startInfo);
        }

        private void CleanupExtractedPackage()
        {
            if (String.IsNullOrEmpty(extractedPackageDirectory) || !Directory.Exists(extractedPackageDirectory))
            {
                return;
            }
            try
            {
                string tempRoot = Path.GetFullPath(Path.GetTempPath());
                string candidate = Path.GetFullPath(extractedPackageDirectory);
                if (candidate.StartsWith(tempRoot, StringComparison.OrdinalIgnoreCase) &&
                    Path.GetFileName(candidate).StartsWith("ZZZIPv6Router-GUI-", StringComparison.Ordinal))
                {
                    Directory.Delete(candidate, true);
                }
            }
            catch
            {
            }
        }

        private sealed class ProcessResult
        {
            internal readonly int ExitCode;
            internal readonly string StandardOutput;
            internal readonly string StandardError;

            internal ProcessResult(int exitCode, string standardOutput, string standardError)
            {
                ExitCode = exitCode;
                StandardOutput = standardOutput;
                StandardError = standardError;
            }
        }
    }
}
