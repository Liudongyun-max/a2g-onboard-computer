param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\ground_station.json"),
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -ReferencedAssemblies @("System.Windows.Forms", "System.Drawing", "System.Net") -TypeDefinition @"
using System;
using System.Drawing;
using System.IO;
using System.Net;
using System.Threading;
using System.Windows.Forms;

public static class A2GMjpegViewer
{
    private static Thread worker;
    private static volatile bool running;
    private static PictureBox target;

    public static void Start(PictureBox box, string url)
    {
        Stop();
        target = box;
        running = true;
        worker = new Thread(() => ReadLoop(url));
        worker.IsBackground = true;
        worker.Start();
    }

    public static void Stop()
    {
        running = false;
        try
        {
            if (worker != null && worker.IsAlive)
            {
                worker.Join(500);
            }
        }
        catch { }
        worker = null;
    }

    private static void ReadLoop(string url)
    {
        while (running)
        {
            try
            {
                HttpWebRequest request = (HttpWebRequest)WebRequest.Create(url);
                request.Timeout = 5000;
                request.ReadWriteTimeout = 5000;
                request.AllowReadStreamBuffering = false;
                using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
                using (Stream stream = response.GetResponseStream())
                {
                    MemoryStream frame = new MemoryStream();
                    bool inFrame = false;
                    int previous = -1;
                    int current;

                    while (running && (current = stream.ReadByte()) != -1)
                    {
                        if (!inFrame)
                        {
                            if (previous == 0xFF && current == 0xD8)
                            {
                                inFrame = true;
                                frame.SetLength(0);
                                frame.WriteByte(0xFF);
                                frame.WriteByte(0xD8);
                            }
                        }
                        else
                        {
                            frame.WriteByte((byte)current);
                            if (previous == 0xFF && current == 0xD9)
                            {
                                byte[] bytes = frame.ToArray();
                                ShowFrame(bytes);
                                inFrame = false;
                                frame.SetLength(0);
                            }
                        }
                        previous = current;
                    }
                }
            }
            catch
            {
                Thread.Sleep(1000);
            }
        }
    }

    private static void ShowFrame(byte[] bytes)
    {
        if (target == null || target.IsDisposed) return;

        try
        {
            using (MemoryStream ms = new MemoryStream(bytes))
            using (Image decoded = Image.FromStream(ms))
            {
                Image frame = new Bitmap(decoded);
                target.BeginInvoke((MethodInvoker)(() =>
                {
                    Image old = target.Image;
                    target.Image = frame;
                    if (old != null) old.Dispose();
                }));
            }
        }
        catch { }
    }
}
"@

function Get-ProjectRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Get-AppConfig {
    param([string]$Path)
    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Get-Urls {
    param($Config)
    $base = "{0}://{1}:{2}" -f $Config.jetson.dashboard.scheme, $Config.jetson.host, $Config.jetson.dashboard.port
    return [pscustomobject]@{
        Base       = $base
        Status     = "{0}{1}" -f $base, $Config.jetson.dashboard.statusPath
        Stream     = "$base/stream"
        CommandApi = "{0}{1}" -f $base, $Config.jetson.commandApi.path
    }
}

function Add-Log {
    param(
        [System.Windows.Forms.TextBox]$LogBox,
        [string]$Message
    )
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message
    $LogBox.AppendText($line + [Environment]::NewLine)
}

function Set-EmbeddedStream {
    param(
        [System.Windows.Forms.PictureBox]$PictureBox,
        [string]$StreamUrl
    )

    [A2GMjpegViewer]::Start($PictureBox, $StreamUrl)
}

function Invoke-Background {
    param(
        [scriptblock]$Action,
        [scriptblock]$OnDone
    )

    try {
        $result = & $Action
        $eventArgs = [pscustomobject]@{
            Error  = $null
            Result = $result
        }
    } catch {
        $eventArgs = [pscustomobject]@{
            Error  = $_.Exception
            Result = $null
        }
    }

    & $OnDone $eventArgs
}

function Test-ToolPath {
    param(
        [string]$Command,
        [string[]]$KnownPaths
    )
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    foreach ($path in $KnownPaths) {
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }
    return $null
}

function Send-GroundCommand {
    param(
        $Config,
        [string]$Command,
        [string]$Note
    )

    $urls = Get-Urls $Config
    $tokenName = $Config.jetson.commandApi.tokenEnv
    $token = [Environment]::GetEnvironmentVariable($tokenName, "User")
    if (-not $token) {
        $token = [Environment]::GetEnvironmentVariable($tokenName, "Machine")
    }
    if (-not $token) {
        $token = [Environment]::GetEnvironmentVariable($tokenName, "Process")
    }

    $payload = [pscustomobject]@{
        command     = $Command
        params      = [pscustomobject]@{ note = $Note }
        client_time = (Get-Date).ToString("o")
        client      = "windows-ground-console"
    } | ConvertTo-Json -Depth 5

    $headers = @{ "Content-Type" = "application/json" }
    if ($token) {
        $headers["X-A2G-Token"] = $token
    }

    return Invoke-RestMethod -Method Post -Uri $urls.CommandApi -Headers $headers -Body $payload -TimeoutSec ([int]$Config.jetson.commandApi.timeoutSeconds)
}

function New-Button {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$W = 170,
        [int]$H = 34
    )
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.SetBounds($X, $Y, $W, $H)
    return $button
}

$root = Get-ProjectRoot
$config = Get-AppConfig $ConfigPath
$urls = Get-Urls $config

if ($SelfTest) {
    [pscustomobject]@{
        root       = $root
        dashboard  = $urls.Base
        status     = $urls.Status
        stream     = $urls.Stream
        commandApi = $urls.CommandApi
    } | ConvertTo-Json -Depth 4
    exit 0
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "A2G Windows Ground Station Console"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(1080, 680)
$form.MinimumSize = New-Object System.Drawing.Size(1040, 640)

$font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Font = $font

$title = New-Object System.Windows.Forms.Label
$title.Text = "A2G Ground Station Console"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$title.SetBounds(16, 12, 420, 30)
$form.Controls.Add($title)

$safety = New-Object System.Windows.Forms.Label
$safety.Text = "Safety: monitor-only; Jetson MAVLink control disabled; commands are whitelisted signals."
$safety.ForeColor = [System.Drawing.Color]::DarkGreen
$safety.SetBounds(16, 45, 760, 24)
$form.Controls.Add($safety)

$mainSplit = New-Object System.Windows.Forms.SplitContainer
$mainSplit.Orientation = [System.Windows.Forms.Orientation]::Horizontal
$mainSplit.SetBounds(16, 82, 1010, 540)
$mainSplit.Anchor = "Top,Bottom,Left,Right"
$mainSplit.FixedPanel = [System.Windows.Forms.FixedPanel]::Panel2
$form.Controls.Add($mainSplit)

$topSplit = New-Object System.Windows.Forms.SplitContainer
$topSplit.Orientation = [System.Windows.Forms.Orientation]::Vertical
$topSplit.Dock = [System.Windows.Forms.DockStyle]::Fill
$topSplit.FixedPanel = [System.Windows.Forms.FixedPanel]::Panel2
$mainSplit.Panel1.Controls.Add($topSplit)

$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$topSplit.Panel1.Controls.Add($statusPanel)

$displayTabs = New-Object System.Windows.Forms.TabControl
$displayTabs.Dock = [System.Windows.Forms.DockStyle]::Fill
$statusPanel.Controls.Add($displayTabs)

$videoTab = New-Object System.Windows.Forms.TabPage
$videoTab.Text = "Live Video"
$displayTabs.TabPages.Add($videoTab) | Out-Null

$statusTab = New-Object System.Windows.Forms.TabPage
$statusTab.Text = "Status JSON"
$displayTabs.TabPages.Add($statusTab) | Out-Null

$videoBox = New-Object System.Windows.Forms.PictureBox
$videoBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$videoBox.BackColor = [System.Drawing.Color]::Black
$videoBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
$videoTab.Controls.Add($videoBox)

$statusBox = New-Object System.Windows.Forms.TextBox
$statusBox.Multiline = $true
$statusBox.ScrollBars = "Both"
$statusBox.WordWrap = $false
$statusBox.ReadOnly = $true
$statusBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$statusTab.Controls.Add($statusBox)
$statusBox.BringToFront()

$controlPanel = New-Object System.Windows.Forms.Panel
$controlPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$controlPanel.AutoScroll = $true
$topSplit.Panel2.Controls.Add($controlPanel)

$logPanel = New-Object System.Windows.Forms.Panel
$logPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$mainSplit.Panel2.Controls.Add($logPanel)

$logLabel = New-Object System.Windows.Forms.Label
$logLabel.Text = "Message log"
$logLabel.Dock = [System.Windows.Forms.DockStyle]::Top
$logLabel.Height = 22
$logPanel.Controls.Add($logLabel)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Both"
$logBox.WordWrap = $false
$logBox.ReadOnly = $true
$logBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$logPanel.Controls.Add($logBox)
$logBox.BringToFront()

$noteLabel = New-Object System.Windows.Forms.Label
$noteLabel.Text = "Command note"
$controlPanel.Controls.Add($noteLabel)

$noteBox = New-Object System.Windows.Forms.TextBox
$noteBox.Text = "ground test"
$controlPanel.Controls.Add($noteBox)

$btnRefresh = New-Button "Refresh /status" 0 0 100 34
$btnDashboard = New-Button "Open Dashboard" 0 0 100 34
$btnStream = New-Button "Load /stream" 0 0 100 34
$btnQgc = New-Button "Open QGC" 0 0 100 34
$btnSsh = New-Button "Open SSH" 0 0 100 34
$btnVlc = New-Button "Open VLC UDP 5600" 0 0 100 34
$btnCheck = New-Button "Run Ground Check" 0 0 100 34

$controlPanel.Controls.AddRange(@($btnRefresh, $btnDashboard, $btnStream, $btnQgc, $btnSsh, $btnVlc, $btnCheck))

$commandGroup = New-Object System.Windows.Forms.GroupBox
$commandGroup.Text = "Ground Command Signals"
$controlPanel.Controls.Add($commandGroup)

$commands = @(
    @{Text="Ping"; Command="ping"; X=12; Y=24},
    @{Text="Status Snapshot"; Command="status_snapshot"; X=178; Y=24},
    @{Text="Mark Event"; Command="mark_event"; X=12; Y=64},
    @{Text="Start Record"; Command="start_record"; X=178; Y=64},
    @{Text="Stop Record"; Command="stop_record"; X=12; Y=104},
    @{Text="Shadow Start"; Command="shadow_start"; X=178; Y=104},
    @{Text="Shadow Stop"; Command="shadow_stop"; X=12; Y=134}
)

$commandButtons = @{}
foreach ($item in $commands) {
    $button = New-Button $item.Text $item.X $item.Y 150 28
    $cmdName = $item.Command
    $commandButtons[$cmdName] = $button
    $button.Add_Click({
        $note = $noteBox.Text
        Add-Log $logBox "Sending command signal: $cmdName"
        Invoke-Background -Action {
            Send-GroundCommand -Config $config -Command $cmdName -Note $note
        } -OnDone {
            param($eventArgs)
            if ($eventArgs.Error) {
                Add-Log $logBox "Command $cmdName failed: $($eventArgs.Error.Message)"
            } else {
                $json = $eventArgs.Result | ConvertTo-Json -Depth 6
                Add-Log $logBox "Command $cmdName response: $json"
            }
        }
    }.GetNewClosure())
    $commandGroup.Controls.Add($button)
}

function Layout-ControlPanel {
    $margin = 10
    $gap = 8
    $w = [Math]::Max(330, $controlPanel.ClientSize.Width - 20)
    $col = [int](($w - (2 * $margin) - $gap) / 2)
    if ($col -lt 145) { $col = 145 }
    $full = [Math]::Max(300, (2 * $col) + $gap)

    $noteLabel.SetBounds($margin, 10, 160, 22)
    $noteBox.SetBounds($margin, 34, $full, 24)
    $btnRefresh.SetBounds($margin, 74, $full, 34)
    $btnDashboard.SetBounds($margin, 118, $col, 34)
    $btnStream.SetBounds($margin + $col + $gap, 118, $col, 34)
    $btnQgc.SetBounds($margin, 162, $col, 34)
    $btnSsh.SetBounds($margin + $col + $gap, 162, $col, 34)
    $btnVlc.SetBounds($margin, 206, $col, 34)
    $btnCheck.SetBounds($margin + $col + $gap, 206, $col, 34)

    $commandGroup.SetBounds($margin, 258, $full, 190)
    $cmdCol = [int](($commandGroup.ClientSize.Width - 32 - $gap) / 2)
    if ($cmdCol -lt 130) { $cmdCol = 130 }
    $commandButtons["ping"].SetBounds(12, 24, $cmdCol, 30)
    $commandButtons["status_snapshot"].SetBounds(20 + $cmdCol + $gap, 24, $cmdCol, 30)
    $commandButtons["mark_event"].SetBounds(12, 64, $cmdCol, 30)
    $commandButtons["start_record"].SetBounds(20 + $cmdCol + $gap, 64, $cmdCol, 30)
    $commandButtons["stop_record"].SetBounds(12, 104, $cmdCol, 30)
    $commandButtons["shadow_start"].SetBounds(20 + $cmdCol + $gap, 104, $cmdCol, 30)
    $commandButtons["shadow_stop"].SetBounds(12, 144, $cmdCol, 30)
}

$controlPanel.Add_Resize({ Layout-ControlPanel })
$form.Add_Shown({
    if ($mainSplit.Height -gt 260) {
        $mainSplit.SplitterDistance = [Math]::Max(260, $mainSplit.Height - 135)
    }
    if ($topSplit.Width -gt 760) {
        $topSplit.SplitterDistance = [Math]::Max(420, $topSplit.Width - 360)
    }
    Layout-ControlPanel
})

$btnRefresh.Add_Click({
    Add-Log $logBox "Refreshing Dashboard status..."
    Invoke-Background -Action {
        Invoke-RestMethod -Uri $urls.Status -Method Get -TimeoutSec 5
    } -OnDone {
        param($eventArgs)
        if ($eventArgs.Error) {
            $statusBox.Text = "Status request failed: $($eventArgs.Error.Message)"
            Add-Log $logBox "Status request failed: $($eventArgs.Error.Message)"
        } else {
            $statusBox.Text = $eventArgs.Result | ConvertTo-Json -Depth 8
            Add-Log $logBox "Status refreshed."
        }
    }
})

$btnDashboard.Add_Click({
    Start-Process $urls.Base
    Add-Log $logBox "Opened Dashboard: $($urls.Base)"
})

$btnStream.Add_Click({
    Set-EmbeddedStream -PictureBox $videoBox -StreamUrl $urls.Stream
    $displayTabs.SelectedTab = $videoTab
    Add-Log $logBox "Loaded embedded stream: $($urls.Stream)"
})

$btnQgc.Add_Click({
    $qgc = Test-ToolPath "QGroundControl.exe" @(
        "F:\QGroundControl\bin\QGroundControl.exe",
        "$env:ProgramFiles\QGroundControl\QGroundControl.exe",
        "${env:ProgramFiles(x86)}\QGroundControl\QGroundControl.exe",
        "$env:LOCALAPPDATA\QGroundControl\QGroundControl.exe"
    )
    if ($qgc) {
        Start-Process -FilePath $qgc
        Add-Log $logBox "Opened QGroundControl: $qgc"
    } else {
        Add-Log $logBox "QGroundControl.exe was not found."
    }
})

$btnSsh.Add_Click({
    $target = "{0}@{1}" -f $config.jetson.user, $config.jetson.host
    Start-Process powershell.exe -ArgumentList @("-NoExit", "-Command", "ssh $target")
    Add-Log $logBox "Opened SSH terminal: ssh $target"
})

$btnVlc.Add_Click({
    $portable = Join-Path $root $config.backupVideo.vlc.portablePath
    $vlc = Test-ToolPath "vlc.exe" @(
        $portable,
        "$env:ProgramFiles\VideoLAN\VLC\vlc.exe",
        "${env:ProgramFiles(x86)}\VideoLAN\VLC\vlc.exe"
    )
    if ($vlc) {
        $streamUrl = $config.backupVideo.futureStreams.udpH264
        Start-Process -FilePath $vlc -ArgumentList @($streamUrl)
        Add-Log $logBox "Opened VLC backup video: $streamUrl"
        Add-Log $logBox "Reminder: Jetson Dashboard must be stopped before UDP video uses /dev/video0."
    } else {
        Add-Log $logBox "vlc.exe was not found."
    }
})

$btnCheck.Add_Click({
    $script = Join-Path $root "scripts\a2g_ground_check.ps1"
    Add-Log $logBox "Running ground check..."
    Invoke-Background -Action {
        powershell -NoProfile -ExecutionPolicy Bypass -File $script 2>&1 | Out-String
    } -OnDone {
        param($eventArgs)
        if ($eventArgs.Error) {
            Add-Log $logBox "Ground check failed: $($eventArgs.Error.Message)"
        } else {
            Add-Log $logBox $eventArgs.Result
        }
    }
})

Add-Log $logBox "Console ready."
Add-Log $logBox "Dashboard: $($urls.Base)"
Add-Log $logBox "Command API: $($urls.CommandApi)"
Set-EmbeddedStream -PictureBox $videoBox -StreamUrl $urls.Stream
Add-Log $logBox "Embedded stream loaded: $($urls.Stream)"
$btnRefresh.PerformClick()

$form.Add_FormClosing({
    [A2GMjpegViewer]::Stop()
})

[void]$form.ShowDialog()
