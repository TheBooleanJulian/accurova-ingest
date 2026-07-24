# ============================================================
#  ACCUROVA INGEST - Nikon D850 (Windows)
#  v6 - Fixed toggle controls
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -- CONFIG FILE ---------------------------------------------
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigFile = Join-Path $ScriptDir "accurova_config.json"

function LoadConfig {
    if (Test-Path $ConfigFile) {
        try {
            $raw = Get-Content $ConfigFile -Raw | ConvertFrom-Json
            return @{ Dest = $raw.Dest; LogDir = $raw.LogDir; Exiftool = $raw.Exiftool }
        } catch {}
    }
    return @{
        Dest     = "$env:USERPROFILE\Pictures\Accurova"
        LogDir   = "$env:USERPROFILE\Pictures\Accurova\_logs"
        Exiftool = "C:\exiftool\exiftool.exe"
    }
}

function SaveConfig($dest, $logDir, $exiftool) {
    @{ Dest = $dest; LogDir = $logDir; Exiftool = $exiftool } | ConvertTo-Json | Set-Content $ConfigFile -Encoding utf8
}

$Config = LoadConfig

# -- COLOURS -------------------------------------------------
$BG       = [System.Drawing.Color]::FromArgb(13,  17,  23)
$PANEL    = [System.Drawing.Color]::FromArgb(22,  30,  40)
$TEAL     = [System.Drawing.Color]::FromArgb(0,   210, 190)
$TEAL_DIM = [System.Drawing.Color]::FromArgb(0,   140, 126)
$FG       = [System.Drawing.Color]::FromArgb(220, 230, 240)
$FG_DIM   = [System.Drawing.Color]::FromArgb(100, 130, 150)
$RED      = [System.Drawing.Color]::FromArgb(255, 85,  85)
$GREEN    = [System.Drawing.Color]::FromArgb(80,  220, 140)
$YELLOW   = [System.Drawing.Color]::FromArgb(255, 200, 60)
$ORANGE   = [System.Drawing.Color]::FromArgb(255, 140, 40)
$FONT_UI  = New-Object System.Drawing.Font("Segoe UI", 9)
$FONT_LBL = New-Object System.Drawing.Font("Segoe UI Semibold", 8.5)
$FONT_TTL = New-Object System.Drawing.Font("Segoe UI Light", 18)
$FONT_SUB = New-Object System.Drawing.Font("Segoe UI", 8)
$FONT_LOG = New-Object System.Drawing.Font("Consolas", 8.5)

# -- FORM ----------------------------------------------------
$Form = New-Object System.Windows.Forms.Form
$Form.Text            = "Accurova Ingest"
$Form.Size            = New-Object System.Drawing.Size(1140, 760)
$Form.StartPosition   = "CenterScreen"
$Form.BackColor       = $BG
$Form.ForeColor       = $FG
$Form.Font            = $FONT_UI
$Form.FormBorderStyle = "FixedSingle"
$Form.MaximizeBox     = $false
$Form.ShowInTaskbar   = $true

# -- HELPERS -------------------------------------------------
function MakeLabel($text, $x, $y) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text      = $text
    $l.Font      = $FONT_LBL
    $l.ForeColor = $FG_DIM
    $l.Location  = New-Object System.Drawing.Point($x, $y)
    $l.Size      = New-Object System.Drawing.Size(300, 18)
    return $l
}

function MakeTextBox($x, $y, $w, $val) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location    = New-Object System.Drawing.Point($x, $y)
    $t.Size        = New-Object System.Drawing.Size($w, 26)
    $t.BackColor   = $PANEL
    $t.ForeColor   = $FG
    $t.BorderStyle = "FixedSingle"
    $t.Font        = $FONT_UI
    $t.Text        = $val
    return $t
}

function MakePlaceholderTextBox($x, $y, $w, $placeholder) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location    = New-Object System.Drawing.Point($x, $y)
    $t.Size        = New-Object System.Drawing.Size($w, 26)
    $t.BackColor   = $PANEL
    $t.ForeColor   = $FG_DIM
    $t.BorderStyle = "FixedSingle"
    $t.Font        = $FONT_UI
    $t.Text        = $placeholder
    $t.Tag         = $placeholder
    $t.Add_GotFocus({
        if ($this.Text -eq $this.Tag) { $this.Text = ""; $this.ForeColor = $FG }
    })
    $t.Add_LostFocus({
        if ($this.Text -eq "") { $this.Text = $this.Tag; $this.ForeColor = $FG_DIM }
    })
    return $t
}

function MakeBrowseBox($x, $y, $w, $val, $isFile) {
    $t = MakeTextBox $x $y ($w - 80) $val
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text      = "Browse"
    $btn.Location  = New-Object System.Drawing.Point(($x + $w - 76), ($y - 1))
    $btn.Size      = New-Object System.Drawing.Size(76, 28)
    $btn.BackColor = $PANEL
    $btn.ForeColor = $FG_DIM
    $btn.FlatStyle = "Flat"
    $btn.Font      = $FONT_SUB
    $btn.FlatAppearance.BorderColor = $FG_DIM
    $btn.FlatAppearance.BorderSize  = 1
    $btn.Cursor    = "Hand"
    # Store both isFile flag and textbox reference in Tag so the closure can access them via $this
    $btn.Tag       = @{ IsFile = $isFile; TextBox = $t }
    $btn.Add_Click({
        $isFilePicker = $this.Tag.IsFile
        $txtBox       = $this.Tag.TextBox
        if ($isFilePicker) {
            $dlg = New-Object System.Windows.Forms.OpenFileDialog
            $dlg.Title  = "Select exiftool.exe"
            $dlg.Filter = "Executables (*.exe)|*.exe"
            if ($txtBox.Text -ne "" -and (Test-Path (Split-Path $txtBox.Text))) { $dlg.InitialDirectory = Split-Path $txtBox.Text }
            if ($dlg.ShowDialog() -eq "OK") { $txtBox.Text = $dlg.FileName }
        } else {
            $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
            $dlg.Description = "Select folder"
            if ($txtBox.Text -ne "" -and (Test-Path $txtBox.Text)) { $dlg.SelectedPath = $txtBox.Text }
            if ($dlg.ShowDialog() -eq "OK") { $txtBox.Text = $dlg.SelectedPath }
        }
    })
    return @{ TextBox = $t; Button = $btn }
}

function AddDivider($y) {
    $d = New-Object System.Windows.Forms.Panel
    $d.BackColor = $PANEL
    $d.Location  = New-Object System.Drawing.Point(24, $y)
    $d.Size      = New-Object System.Drawing.Size(628, 1)
    $Form.Controls.Add($d)
}

function AddSectionHeader($text, $y) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text      = $text
    $l.Font      = New-Object System.Drawing.Font("Segoe UI Semibold", 7.5)
    $l.ForeColor = $TEAL
    $l.BackColor = [System.Drawing.Color]::FromArgb(0, 30, 28)
    $l.Location  = New-Object System.Drawing.Point(24, $y)
    $l.Size      = New-Object System.Drawing.Size(628, 20)
    $l.TextAlign = "MiddleLeft"
    $l.Padding   = New-Object System.Windows.Forms.Padding(6, 0, 0, 0)
    $Form.Controls.Add($l)
}

function FormatBytes($bytes) {
    if ($bytes -ge 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) }
    if ($bytes -ge 1MB) { return "{0:N1} MB" -f ($bytes / 1MB) }
    if ($bytes -ge 1KB) { return "{0:N0} KB" -f ($bytes / 1KB) }
    return "$bytes B"
}

function FormatSpeed($bps) {
    if ($bps -ge 1MB) { return "{0:N1} MB/s" -f ($bps / 1MB) }
    if ($bps -ge 1KB) { return "{0:N0} KB/s" -f ($bps / 1KB) }
    return "$([int]$bps) B/s"
}

function FormatETA($secs) {
    if ($secs -le 0) { return "--:--" }
    $ts = [TimeSpan]::FromSeconds($secs)
    if ($ts.TotalHours -ge 1)   { return "{0}h {1:D2}m" -f [int]$ts.TotalHours, $ts.Minutes }
    if ($ts.TotalMinutes -ge 1) { return "{0}m {1:D2}s" -f $ts.Minutes, $ts.Seconds }
    return "{0}s" -f $ts.Seconds
}

# ============================================================
#  TITLE
# ============================================================
$LblTitle = New-Object System.Windows.Forms.Label
$LblTitle.Text      = "ACCUROVA"
$LblTitle.Font      = $FONT_TTL
$LblTitle.ForeColor = $TEAL
$LblTitle.Location  = New-Object System.Drawing.Point(24, 18)
$LblTitle.Size      = New-Object System.Drawing.Size(200, 36)
$Form.Controls.Add($LblTitle)

$LblSub = New-Object System.Windows.Forms.Label
$LblSub.Text      = "D850 INGEST UTILITY"
$LblSub.Font      = $FONT_SUB
$LblSub.ForeColor = $FG_DIM
$LblSub.Location  = New-Object System.Drawing.Point(26, 52)
$LblSub.Size      = New-Object System.Drawing.Size(200, 18)
$Form.Controls.Add($LblSub)

$TitleLine = New-Object System.Windows.Forms.Panel
$TitleLine.BackColor = $TEAL
$TitleLine.Location  = New-Object System.Drawing.Point(24, 76)
$TitleLine.Size      = New-Object System.Drawing.Size(1092, 1)
$Form.Controls.Add($TitleLine)

# ============================================================
#  SECTION: PATHS
# ============================================================
AddSectionHeader "  PATHS" 86

$Form.Controls.Add((MakeLabel "VAULT DESTINATION" 24 116))
$DestBox = MakeBrowseBox 24 134 628 $Config.Dest $false
$Form.Controls.Add($DestBox.TextBox)
$Form.Controls.Add($DestBox.Button)

$Form.Controls.Add((MakeLabel "LOG FOLDER" 24 170))
$LogBox = MakeBrowseBox 24 188 628 $Config.LogDir $false
$Form.Controls.Add($LogBox.TextBox)
$Form.Controls.Add($LogBox.Button)

$Form.Controls.Add((MakeLabel "EXIFTOOL PATH" 24 224))
$ExifBox = MakeBrowseBox 24 242 628 $Config.Exiftool $true
$Form.Controls.Add($ExifBox.TextBox)
$Form.Controls.Add($ExifBox.Button)

$DestBox.TextBox.Add_TextChanged({
    $newDest = $DestBox.TextBox.Text.Trim()
    if ($newDest -ne "") { $LogBox.TextBox.Text = Join-Path $newDest "_logs" }
})

$BtnSaveConfig = New-Object System.Windows.Forms.Button
$BtnSaveConfig.Text      = "Save Paths"
$BtnSaveConfig.Location  = New-Object System.Drawing.Point(24, 278)
$BtnSaveConfig.Size      = New-Object System.Drawing.Size(100, 26)
$BtnSaveConfig.BackColor = $PANEL
$BtnSaveConfig.ForeColor = $TEAL
$BtnSaveConfig.FlatStyle = "Flat"
$BtnSaveConfig.Font      = $FONT_SUB
$BtnSaveConfig.FlatAppearance.BorderColor = $TEAL
$BtnSaveConfig.FlatAppearance.BorderSize  = 1
$BtnSaveConfig.Cursor    = "Hand"
$Form.Controls.Add($BtnSaveConfig)

$LblSaveStatus = New-Object System.Windows.Forms.Label
$LblSaveStatus.Text      = ""
$LblSaveStatus.Font      = $FONT_SUB
$LblSaveStatus.ForeColor = $GREEN
$LblSaveStatus.Location  = New-Object System.Drawing.Point(134, 283)
$LblSaveStatus.Size      = New-Object System.Drawing.Size(300, 18)
$Form.Controls.Add($LblSaveStatus)

$BtnSaveConfig.Add_Click({
    SaveConfig $DestBox.TextBox.Text.Trim() $LogBox.TextBox.Text.Trim() $ExifBox.TextBox.Text.Trim()
    $LblSaveStatus.Text = "Saved."
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 2000
    $timer.Add_Tick({ $LblSaveStatus.Text = ""; $timer.Stop() })
    $timer.Start()
})

AddDivider 314

# ============================================================
#  SECTION: SESSION
# ============================================================
AddSectionHeader "  SESSION" 324

$Form.Controls.Add((MakeLabel "EVENT NAME" 24 354))
$TxtEvent = MakePlaceholderTextBox 24 372 400 "e.g. FAF Day 2"
$Form.Controls.Add($TxtEvent)

$Form.Controls.Add((MakeLabel "LOCATION" 24 408))
$TxtLocation = MakePlaceholderTextBox 24 426 400 "e.g. Kallang Leisure Park"
$Form.Controls.Add($TxtLocation)

$Form.Controls.Add((MakeLabel "SD CARD DRIVE" 24 462))
$CmbDrive = New-Object System.Windows.Forms.ComboBox
$CmbDrive.Location      = New-Object System.Drawing.Point(24, 480)
$CmbDrive.Size          = New-Object System.Drawing.Size(100, 26)
$CmbDrive.BackColor     = $PANEL
$CmbDrive.ForeColor     = $FG
$CmbDrive.FlatStyle     = "Flat"
$CmbDrive.Font          = $FONT_UI
$CmbDrive.DropDownStyle = "DropDownList"
foreach ($Letter in @("C","D","E","F","G","H","I")) { $CmbDrive.Items.Add($Letter + ":\") | Out-Null }
$CmbDrive.SelectedItem = "D:\"
$Form.Controls.Add($CmbDrive)

$LblAutoDetect = New-Object System.Windows.Forms.Label
$LblAutoDetect.Text      = "Scanning drives..."
$LblAutoDetect.Font      = $FONT_SUB
$LblAutoDetect.ForeColor = $FG_DIM
$LblAutoDetect.Location  = New-Object System.Drawing.Point(136, 484)
$LblAutoDetect.Size      = New-Object System.Drawing.Size(300, 18)
$Form.Controls.Add($LblAutoDetect)

# -- EJECT TOGGLE (inlined) ----------------------------------
$script:EjectChecked = $false

$EjectTrack = New-Object System.Windows.Forms.Panel
$EjectTrack.Location  = New-Object System.Drawing.Point(24, 516)
$EjectTrack.Size      = New-Object System.Drawing.Size(36, 18)
$EjectTrack.BackColor = $PANEL
$EjectTrack.Cursor    = "Hand"

$EjectThumb = New-Object System.Windows.Forms.Panel
$EjectThumb.Size      = New-Object System.Drawing.Size(12, 12)
$EjectThumb.Location  = New-Object System.Drawing.Point(3, 3)
$EjectThumb.BackColor = $FG_DIM
$EjectThumb.Cursor    = "Hand"
$EjectTrack.Controls.Add($EjectThumb)

$EjectLabel = New-Object System.Windows.Forms.Label
$EjectLabel.Text      = "Eject SD card after ingest"
$EjectLabel.Font      = $FONT_SUB
$EjectLabel.ForeColor = $FG_DIM
$EjectLabel.Location  = New-Object System.Drawing.Point(68, 517)
$EjectLabel.Size      = New-Object System.Drawing.Size(300, 18)
$EjectLabel.Cursor    = "Hand"

$Form.Controls.Add($EjectTrack)
$Form.Controls.Add($EjectLabel)

$EjectToggle = {
    $script:EjectChecked = -not $script:EjectChecked
    if ($script:EjectChecked) {
        $EjectTrack.BackColor = $TEAL
        $EjectThumb.BackColor = $BG
        $EjectThumb.Location  = New-Object System.Drawing.Point(21, 3)
        $EjectLabel.ForeColor = $FG
    } else {
        $EjectTrack.BackColor = $PANEL
        $EjectThumb.BackColor = $FG_DIM
        $EjectThumb.Location  = New-Object System.Drawing.Point(3, 3)
        $EjectLabel.ForeColor = $FG_DIM
    }
}
$EjectTrack.Add_Click($EjectToggle)
$EjectThumb.Add_Click($EjectToggle)
$EjectLabel.Add_Click($EjectToggle)

# -- DRY RUN TOGGLE (inlined) --------------------------------
$script:DryRunChecked = $false

$DryTrack = New-Object System.Windows.Forms.Panel
$DryTrack.Location  = New-Object System.Drawing.Point(24, 542)
$DryTrack.Size      = New-Object System.Drawing.Size(36, 18)
$DryTrack.BackColor = $PANEL
$DryTrack.Cursor    = "Hand"

$DryThumb = New-Object System.Windows.Forms.Panel
$DryThumb.Size      = New-Object System.Drawing.Size(12, 12)
$DryThumb.Location  = New-Object System.Drawing.Point(3, 3)
$DryThumb.BackColor = $FG_DIM
$DryThumb.Cursor    = "Hand"
$DryTrack.Controls.Add($DryThumb)

$DryLabel = New-Object System.Windows.Forms.Label
$DryLabel.Text      = "Dry run (simulate only - no files will be copied)"
$DryLabel.Font      = $FONT_SUB
$DryLabel.ForeColor = $FG_DIM
$DryLabel.Location  = New-Object System.Drawing.Point(68, 543)
$DryLabel.Size      = New-Object System.Drawing.Size(350, 18)
$DryLabel.Cursor    = "Hand"

$Form.Controls.Add($DryTrack)
$Form.Controls.Add($DryLabel)

# Dry run banner (defined before toggle so toggle can reference it)
$DryRunBanner = New-Object System.Windows.Forms.Panel
$DryRunBanner.BackColor = [System.Drawing.Color]::FromArgb(60, 50, 0)
$DryRunBanner.Location  = New-Object System.Drawing.Point(24, 570)
$DryRunBanner.Size      = New-Object System.Drawing.Size(628, 24)
$DryRunBanner.Visible   = $false
$LblDryRunBanner = New-Object System.Windows.Forms.Label
$LblDryRunBanner.Text      = "  DRY RUN ACTIVE - No files will be copied or moved"
$LblDryRunBanner.Font      = New-Object System.Drawing.Font("Segoe UI Semibold", 8.5)
$LblDryRunBanner.ForeColor = $YELLOW
$LblDryRunBanner.BackColor = [System.Drawing.Color]::Transparent
$LblDryRunBanner.Location  = New-Object System.Drawing.Point(0, 4)
$LblDryRunBanner.Size      = New-Object System.Drawing.Size(628, 18)
$DryRunBanner.Controls.Add($LblDryRunBanner)
$Form.Controls.Add($DryRunBanner)

$DryToggle = {
    $script:DryRunChecked = -not $script:DryRunChecked
    if ($script:DryRunChecked) {
        $DryTrack.BackColor   = $TEAL
        $DryThumb.BackColor   = $BG
        $DryThumb.Location    = New-Object System.Drawing.Point(21, 3)
        $DryLabel.ForeColor   = $FG
        $DryRunBanner.Visible = $true
    } else {
        $DryTrack.BackColor   = $PANEL
        $DryThumb.BackColor   = $FG_DIM
        $DryThumb.Location    = New-Object System.Drawing.Point(3, 3)
        $DryLabel.ForeColor   = $FG_DIM
        $DryRunBanner.Visible = $false
    }
}
$DryTrack.Add_Click($DryToggle)
$DryThumb.Add_Click($DryToggle)
$DryLabel.Add_Click($DryToggle)

AddDivider 604

# ============================================================
#  BUTTONS
# ============================================================
$BtnRun = New-Object System.Windows.Forms.Button
$BtnRun.Text      = "START INGEST"
$BtnRun.Location  = New-Object System.Drawing.Point(24, 614)
$BtnRun.Size      = New-Object System.Drawing.Size(180, 38)
$BtnRun.BackColor = $TEAL
$BtnRun.ForeColor = $BG
$BtnRun.FlatStyle = "Flat"
$BtnRun.Font      = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5)
$BtnRun.FlatAppearance.BorderSize = 0
$BtnRun.Cursor    = "Hand"
$Form.Controls.Add($BtnRun)

$BtnStop = New-Object System.Windows.Forms.Button
$BtnStop.Text      = "STOP"
$BtnStop.Location  = New-Object System.Drawing.Point(214, 614)
$BtnStop.Size      = New-Object System.Drawing.Size(80, 38)
$BtnStop.BackColor = $RED
$BtnStop.ForeColor = $FG
$BtnStop.FlatStyle = "Flat"
$BtnStop.Font      = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5)
$BtnStop.FlatAppearance.BorderSize = 0
$BtnStop.Cursor    = "Hand"
$BtnStop.Enabled   = $false
$Form.Controls.Add($BtnStop)

$LblStatus = New-Object System.Windows.Forms.Label
$LblStatus.Text      = "Ready."
$LblStatus.Font      = $FONT_SUB
$LblStatus.ForeColor = $FG_DIM
$LblStatus.Location  = New-Object System.Drawing.Point(308, 626)
$LblStatus.Size      = New-Object System.Drawing.Size(344, 18)
$Form.Controls.Add($LblStatus)

AddDivider 662

# ============================================================
#  PROGRESS
# ============================================================
$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Location  = New-Object System.Drawing.Point(24, 672)
$ProgressBar.Size      = New-Object System.Drawing.Size(628, 14)
$ProgressBar.Minimum   = 0
$ProgressBar.Maximum   = 100
$ProgressBar.Value     = 0
$ProgressBar.Style     = "Continuous"
$ProgressBar.ForeColor = $TEAL
$ProgressBar.BackColor = $PANEL
$Form.Controls.Add($ProgressBar)

$LblPct = New-Object System.Windows.Forms.Label
$LblPct.Text      = "0%"
$LblPct.Font      = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$LblPct.ForeColor = $TEAL
$LblPct.Location  = New-Object System.Drawing.Point(24, 694)
$LblPct.Size      = New-Object System.Drawing.Size(60, 18)
$Form.Controls.Add($LblPct)

$LblFiles = New-Object System.Windows.Forms.Label
$LblFiles.Text      = "0 / 0 files"
$LblFiles.Font      = $FONT_SUB
$LblFiles.ForeColor = $FG_DIM
$LblFiles.Location  = New-Object System.Drawing.Point(90, 694)
$LblFiles.Size      = New-Object System.Drawing.Size(160, 18)
$Form.Controls.Add($LblFiles)

$LblSpeed = New-Object System.Windows.Forms.Label
$LblSpeed.Text      = ""
$LblSpeed.Font      = $FONT_SUB
$LblSpeed.ForeColor = $FG_DIM
$LblSpeed.Location  = New-Object System.Drawing.Point(280, 694)
$LblSpeed.Size      = New-Object System.Drawing.Size(120, 18)
$Form.Controls.Add($LblSpeed)

$LblETA = New-Object System.Windows.Forms.Label
$LblETA.Text      = ""
$LblETA.Font      = $FONT_SUB
$LblETA.ForeColor = $FG_DIM
$LblETA.Location  = New-Object System.Drawing.Point(430, 694)
$LblETA.Size      = New-Object System.Drawing.Size(222, 18)
$Form.Controls.Add($LblETA)

$LblCurrentFile = New-Object System.Windows.Forms.Label
$LblCurrentFile.Text      = ""
$LblCurrentFile.Font      = $FONT_SUB
$LblCurrentFile.ForeColor = $FG_DIM
$LblCurrentFile.Location  = New-Object System.Drawing.Point(24, 714)
$LblCurrentFile.Size      = New-Object System.Drawing.Size(628, 18)
$Form.Controls.Add($LblCurrentFile)

# ============================================================
#  RIGHT PANEL - OUTPUT LOG (full height)
# ============================================================

# Vertical divider between left controls and right log
$VDivider = New-Object System.Windows.Forms.Panel
$VDivider.BackColor = $PANEL
$VDivider.Location  = New-Object System.Drawing.Point(668, 86)
$VDivider.Size      = New-Object System.Drawing.Size(1, 634)
$Form.Controls.Add($VDivider)

$LblLogHeader = New-Object System.Windows.Forms.Label
$LblLogHeader.Text      = "  OUTPUT LOG"
$LblLogHeader.Font      = New-Object System.Drawing.Font("Segoe UI Semibold", 7.5)
$LblLogHeader.ForeColor = $TEAL
$LblLogHeader.BackColor = [System.Drawing.Color]::FromArgb(0, 30, 28)
$LblLogHeader.Location  = New-Object System.Drawing.Point(685, 86)
$LblLogHeader.Size      = New-Object System.Drawing.Size(431, 20)
$LblLogHeader.TextAlign = "MiddleLeft"
$Form.Controls.Add($LblLogHeader)

$TxtLog = New-Object System.Windows.Forms.RichTextBox
$TxtLog.Location    = New-Object System.Drawing.Point(685, 110)
$TxtLog.Size        = New-Object System.Drawing.Size(431, 610)
$TxtLog.BackColor   = $PANEL
$TxtLog.ForeColor   = $FG_DIM
$TxtLog.Font        = $FONT_LOG
$TxtLog.ReadOnly    = $true
$TxtLog.BorderStyle = "None"
$TxtLog.ScrollBars  = "Vertical"
$Form.Controls.Add($TxtLog)

# ============================================================
#  RUNTIME HELPERS
# ============================================================
function AppendLog($msg, $color) {
    $TxtLog.SelectionStart  = $TxtLog.TextLength
    $TxtLog.SelectionLength = 0
    $TxtLog.SelectionColor  = $color
    $TxtLog.AppendText("$msg`n")
    $TxtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function ResetUI {
    $BtnRun.Enabled      = $true
    $BtnStop.Enabled     = $false
    $BtnRun.Text         = "START INGEST"
    $BtnRun.BackColor    = $TEAL
    $LblSpeed.Text       = ""
    $LblETA.Text         = ""
    $LblCurrentFile.Text = ""
}

# -- SD AUTO-DETECT ------------------------------------------
function DetectSDCard {
    foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
        if ($drive.DriveType -eq "Removable" -and $drive.IsReady) {
            if (Test-Path (Join-Path $drive.RootDirectory.FullName "DCIM")) {
                return $drive.Name.TrimEnd("\")
            }
        }
    }
    return $null
}

$Form.Add_Shown({
    $found = DetectSDCard
    if ($found) {
        $item = $found + "\"
        if ($CmbDrive.Items.Contains($item)) { $CmbDrive.SelectedItem = $item }
        $LblAutoDetect.Text      = "Auto-detected: $found (DCIM found)"
        $LblAutoDetect.ForeColor = $GREEN
    } else {
        $LblAutoDetect.Text      = "No SD card detected - select manually"
        $LblAutoDetect.ForeColor = $YELLOW
    }
})

$CmbDrive.Add_DropDown({
    $found = DetectSDCard
    if ($found) {
        $item = $found + "\"
        if ($CmbDrive.Items.Contains($item)) { $CmbDrive.SelectedItem = $item }
        $LblAutoDetect.Text      = "Auto-detected: $found"
        $LblAutoDetect.ForeColor = $GREEN
    }
})

# -- STOP ----------------------------------------------------
$script:StopRequested  = $false
$script:CurrentProcess = $null

$BtnStop.Add_Click({
    $script:StopRequested = $true
    if ($script:CurrentProcess -and -not $script:CurrentProcess.HasExited) {
        try { $script:CurrentProcess.Kill() } catch {}
    }
    AppendLog "[WARN]  Stopped by user." $RED
    $LblStatus.Text      = "Stopped."
    $LblStatus.ForeColor = $RED
    ResetUI
})

# -- DUPLICATE INDEX -----------------------------------------
function BuildDestIndex($destPath) {
    $index = @{}
    if (Test-Path $destPath) {
        Get-ChildItem -Path $destPath -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            $key = $_.Name.ToLower()
            if (-not $index.ContainsKey($key)) { $index[$key] = $_.FullName }
        }
    }
    return $index
}

# -- EXIFTOOL RUNNER -----------------------------------------
# $subFolder: optional subfolder appended after the date folder (e.g. "360")
function RunExifStep($extensions, $sourceDir, $fileMap, $destIndex, $isDryRun, $dest, $subFolder = "") {
    $extArgs  = ($extensions | ForEach-Object { "-ext $_" }) -join " "
    $subPart  = if ($subFolder -ne "") { "\$subFolder" } else { "" }
    $destPattern = "$dest\%Y_%m\%Y_%m_%d$($script:Suffix)$subPart"

    if ($isDryRun) {
        foreach ($ext in $extensions) {
            $files = Get-ChildItem -Path $sourceDir -Recurse -Filter "*.$ext" -ErrorAction SilentlyContinue
            foreach ($f in $files) {
                if ($script:StopRequested) { return $false }
                $key = $f.Name.ToLower()
                if ($destIndex.ContainsKey($key)) {
                    AppendLog ("  [SKIP - duplicate]  " + $f.Name) $ORANGE
                } else {
                    $subLabel = if ($subFolder -ne "") { " >> $subFolder" } else { "" }
                    AppendLog ("  [WOULD COPY$subLabel]  " + $f.Name + "  (" + (FormatBytes $f.Length) + ")") $TEAL_DIM
                }
                $script:BytesDone += $f.Length
                $script:FilesDone++
                $pct = if ($script:TotalBytes -gt 0) { [int](($script:BytesDone / $script:TotalBytes) * 100) } else { 0 }
                $ProgressBar.Value   = [Math]::Min($pct, 100)
                $LblPct.Text         = "$([Math]::Min($pct,100))%"
                $LblFiles.Text       = "$($script:FilesDone) / $($script:TotalFiles) files"
                $LblCurrentFile.Text = "Simulating: $($f.Name)"
                [System.Windows.Forms.Application]::DoEvents()
            }
        }
        return $true
    }

    $argStr = "-r -d `"$destPattern`" `"-Directory<DateTimeOriginal`" `"-Directory<CreateDate`" `"-Directory<FileModifyDate`" $extArgs -o `".`" --overwrite_original -progress `"$sourceDir`""

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = $ExifBox.TextBox.Text.Trim()
    $psi.Arguments              = $argStr
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true

    $script:CurrentProcess = New-Object System.Diagnostics.Process
    $script:CurrentProcess.StartInfo = $psi
    $script:CurrentProcess.Start() | Out-Null

    while (-not $script:CurrentProcess.StandardOutput.EndOfStream) {
        $line    = $script:CurrentProcess.StandardOutput.ReadLine()
        $trimmed = $line.Trim()
        if ($trimmed -ne "") {
            if ($trimmed -match "^=======\s+(.+)$") {
                $filePath = $Matches[1].Trim()
                $fileName = [System.IO.Path]::GetFileName($filePath)
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($filePath).ToLower()
                $fileKey  = $fileName.ToLower()
                $fileSize = 0
                if ($fileMap.ContainsKey($baseName)) { $fileSize = $fileMap[$baseName].Length }
                if ($destIndex.ContainsKey($fileKey)) {
                    AppendLog ("  [DUPLICATE - already in vault]  $fileName") $ORANGE
                } else {
                    $script:BytesDone += $fileSize
                    $script:FilesDone++
                    $pct = if ($script:TotalBytes -gt 0) { [int](($script:BytesDone / $script:TotalBytes) * 100) } else { 0 }
                    $ProgressBar.Value   = [Math]::Min($pct, 100)
                    $LblPct.Text         = "$([Math]::Min($pct,100))%"
                    $LblFiles.Text       = "$($script:FilesDone) / $($script:TotalFiles) files"
                    $elapsed = ([DateTime]::Now - $script:IngestStart).TotalSeconds
                    if ($elapsed -gt 1 -and $script:BytesDone -gt 0) {
                        $speed     = $script:BytesDone / $elapsed
                        $remaining = $script:TotalBytes - $script:BytesDone
                        $etaSecs   = if ($speed -gt 0) { $remaining / $speed } else { 0 }
                        $LblSpeed.Text = FormatSpeed $speed
                        $LblETA.Text   = "ETA  " + (FormatETA $etaSecs)
                    }
                    $LblCurrentFile.Text = "Copying: $fileName  (" + (FormatBytes $fileSize) + ")"
                    AppendLog ("  [" + (FormatBytes $script:BytesDone) + " / " + (FormatBytes $script:TotalBytes) + "]  $fileName") $FG_DIM
                }
            } elseif ($trimmed -match "\d+ image files") {
                AppendLog "  $trimmed" $GREEN
            } elseif ($trimmed -match "^(Error|Warning)") {
                AppendLog "  $trimmed" $YELLOW
            }
        }
        [System.Windows.Forms.Application]::DoEvents()
        if ($script:StopRequested) {
            try { $script:CurrentProcess.Kill() } catch {}
            return $false
        }
    }
    $errText = $script:CurrentProcess.StandardError.ReadToEnd()
    if ($errText.Trim() -ne "") { AppendLog "  $errText" $FG_DIM }
    $script:CurrentProcess.WaitForExit()
    return (-not $script:StopRequested)
}

# -- VERIFY --------------------------------------------------
function VerifyIngest($sourceFiles, $destPath, $isDryRun) {
    if ($isDryRun) { AppendLog "[INFO]  Skipping verification (dry run)." $FG_DIM; return }
    AppendLog "`n[INFO]  Verifying ingest..." $YELLOW
    $srcCount = $sourceFiles.Count
    $srcBytes = ($sourceFiles | Measure-Object -Property Length -Sum).Sum
    if (-not $srcBytes) { $srcBytes = 0 }
    $matchedCount = 0; $matchedBytes = 0; $missing = @()
    foreach ($f in $sourceFiles) {
        $found = Get-ChildItem -Path $destPath -Recurse -Filter $f.Name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $matchedCount++; $matchedBytes += $found.Length }
        else { $missing += $f.Name }
    }
    AppendLog ("  Source : $srcCount files  (" + (FormatBytes $srcBytes) + ")") $FG
    AppendLog ("  Dest   : $matchedCount files matched  (" + (FormatBytes $matchedBytes) + ")") $FG
    if ($missing.Count -gt 0) {
        AppendLog "[WARN]  $($missing.Count) file(s) missing from destination:" $RED
        foreach ($m in $missing) { AppendLog "    MISSING: $m" $RED }
        AppendLog "[WARN]  Do NOT format SD card until resolved." $RED
    } elseif ($matchedCount -eq $srcCount) {
        AppendLog "[OK]    All $srcCount files verified." $GREEN
        AppendLog "[OK]    Safe to format SD card." $GREEN
    }
}

# ============================================================
#  RUN BUTTON
# ============================================================
$BtnRun.Add_Click({
    $TxtLog.Clear()
    $script:StopRequested = $false
    $BtnRun.Enabled       = $false
    $BtnStop.Enabled      = $true
    $BtnRun.Text          = "RUNNING..."
    $BtnRun.BackColor     = $TEAL_DIM
    $LblStatus.ForeColor  = $YELLOW
    $ProgressBar.Value    = 0
    $LblPct.Text          = "0%"
    $LblFiles.Text        = ""
    $LblSpeed.Text        = ""
    $LblETA.Text          = ""
    $LblCurrentFile.Text  = ""

    $DEST_LIVE     = $DestBox.TextBox.Text.Trim()
    $LOG_DIR_LIVE  = $LogBox.TextBox.Text.Trim()
    $EXIFTOOL_LIVE = $ExifBox.TextBox.Text.Trim()
    $IsDryRun      = $script:DryRunChecked

    if ($DEST_LIVE -eq "") {
        AppendLog "[ERROR] Vault destination path is empty." $RED; ResetUI; return
    }
    if (-not $IsDryRun -and -not (Test-Path $EXIFTOOL_LIVE)) {
        AppendLog "[ERROR] exiftool.exe not found at: $EXIFTOOL_LIVE" $RED
        AppendLog "        Update the ExifTool path in the Paths section above." $RED
        ResetUI; return
    }

    $EvtVal = $TxtEvent.Text.Trim()
    $LocVal = $TxtLocation.Text.Trim()
    if ($EvtVal -eq $TxtEvent.Tag)    { $EvtVal = "" }
    if ($LocVal -eq $TxtLocation.Tag) { $LocVal = "" }
    $script:Suffix = ""
    if ($EvtVal -ne "") { $script:Suffix += " $EvtVal" }
    if ($LocVal -ne "") { $script:Suffix += " $LocVal" }

    $DriveLetter = $CmbDrive.SelectedItem.ToString()
    $SD_CARD     = $DriveLetter + "DCIM"

    if (-not (Test-Path $SD_CARD)) {
        AppendLog "[ERROR] SD card not found at $SD_CARD" $RED
        AppendLog "        Check the drive letter." $RED
        ResetUI; return
    }

    $LblStatus.Text = "Scanning files..."
    AppendLog "[INFO]  Scanning source files..." $YELLOW
    [System.Windows.Forms.Application]::DoEvents()

    $NefFiles  = @(Get-ChildItem -Path $SD_CARD -Recurse -Filter "*.nef"  -ErrorAction SilentlyContinue)
    $Mp4Files  = @(Get-ChildItem -Path $SD_CARD -Recurse -Filter "*.mp4"  -ErrorAction SilentlyContinue)
    $LrvFiles  = @(Get-ChildItem -Path $SD_CARD -Recurse -Filter "*.lrv"  -ErrorAction SilentlyContinue)
    $InsvFiles = @(Get-ChildItem -Path $SD_CARD -Recurse -Filter "*.insv" -ErrorAction SilentlyContinue)
    $JpgFiles  = @(Get-ChildItem -Path $SD_CARD -Recurse -Include "*.jpg","*.jpeg" -ErrorAction SilentlyContinue)

    $FileMap = @{}
    foreach ($f in ($NefFiles + $Mp4Files + $LrvFiles + $InsvFiles + $JpgFiles)) {
        $key = [System.IO.Path]::GetFileNameWithoutExtension($f.Name).ToLower()
        if (-not $FileMap.ContainsKey($key)) { $FileMap[$key] = $f }
    }

    $TotalNefBytes  = ($NefFiles  | Measure-Object -Property Length -Sum).Sum
    $TotalMp4Bytes  = ($Mp4Files  | Measure-Object -Property Length -Sum).Sum
    $Total360Bytes  = (($LrvFiles + $InsvFiles) | Measure-Object -Property Length -Sum).Sum
    if (-not $TotalNefBytes)  { $TotalNefBytes  = 0 }
    if (-not $TotalMp4Bytes)  { $TotalMp4Bytes  = 0 }
    if (-not $Total360Bytes)  { $Total360Bytes  = 0 }
    $TotalTransferBytes = $TotalNefBytes + $TotalMp4Bytes + $Total360Bytes
    $script:TotalFiles  = $NefFiles.Count + $Mp4Files.Count + $LrvFiles.Count + $InsvFiles.Count
    $script:TotalBytes  = $TotalTransferBytes
    $script:FilesDone   = 0
    $script:BytesDone   = 0

    AppendLog "[INFO]  Found $($NefFiles.Count) NEFs   ($(FormatBytes $TotalNefBytes))" $FG
    AppendLog "[INFO]  Found $($Mp4Files.Count) MP4s   ($(FormatBytes $TotalMp4Bytes))" $FG
    AppendLog "[INFO]  Found $($LrvFiles.Count + $InsvFiles.Count) 360 files (.lrv/.insv)  ($(FormatBytes $Total360Bytes))" $FG
    AppendLog "[INFO]  Total: $(FormatBytes $TotalTransferBytes)" $FG

    $LblStatus.Text = "Building duplicate index..."
    AppendLog "[INFO]  Indexing vault for duplicates..." $YELLOW
    [System.Windows.Forms.Application]::DoEvents()
    $DestIndex = BuildDestIndex $DEST_LIVE
    AppendLog "[INFO]  Vault index: $($DestIndex.Count) existing files." $FG
    $dupCount = 0
    foreach ($f in ($NefFiles + $Mp4Files)) {
        if ($DestIndex.ContainsKey($f.Name.ToLower())) { $dupCount++ }
    }
    if ($dupCount -gt 0) {
        AppendLog "[WARN]  $dupCount file(s) already in vault - will be skipped." $ORANGE
    } else {
        AppendLog "[OK]    No duplicates detected." $GREEN
    }

    if (-not $IsDryRun) {
        $LblStatus.Text = "Checking storage..."
        $DestDrive   = Split-Path $DEST_LIVE -Qualifier
        $DriveInfo   = New-Object System.IO.DriveInfo($DestDrive)
        $FreeBytes   = $DriveInfo.AvailableFreeSpace
        $BufferBytes = 500MB
        AppendLog "[INFO]  Target drive $DestDrive free: $(FormatBytes $FreeBytes)" $FG
        if ($TotalTransferBytes -gt 0 -and ($TotalTransferBytes + $BufferBytes) -gt $FreeBytes) {
            $needed = FormatBytes ($TotalTransferBytes + $BufferBytes)
            $avail  = FormatBytes $FreeBytes
            AppendLog "[WARN]  Insufficient storage! Need $needed, have $avail." $RED
            $LblStatus.Text = "Insufficient storage!"
            $dlgResult = [System.Windows.Forms.MessageBox]::Show(
                "Not enough space on $DestDrive.`n`nRequired : $needed`nAvailable: $avail`n`nContinue anyway?",
                "Accurova - Storage Warning",
                [System.Windows.Forms.MessageBoxButtons]::OKCancel,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            if ($dlgResult -eq [System.Windows.Forms.DialogResult]::Cancel) {
                AppendLog "[INFO]  Cancelled (storage check)." $RED
                $LblStatus.Text = "Cancelled."; ResetUI; return
            }
            AppendLog "[WARN]  Continuing despite storage warning." $YELLOW
        } else {
            AppendLog "[OK]    Sufficient storage available." $GREEN
        }
    }

    New-Item -ItemType Directory -Force -Path $DEST_LIVE    | Out-Null
    New-Item -ItemType Directory -Force -Path $LOG_DIR_LIVE | Out-Null
    $Timestamp          = Get-Date -Format "yyyyMMdd_HHmmss"
    $LOG                = "$LOG_DIR_LIVE\ingest_$Timestamp.log"
    $script:IngestStart = [DateTime]::Now
    $modeLabel          = if ($IsDryRun) { "DRY RUN" } else { "LIVE" }

    AppendLog "`n============================================" $TEAL
    AppendLog " ACCUROVA  [$modeLabel]  -  $(Get-Date -Format 'yyyy-MM-dd HH:mm')" $TEAL
    AppendLog " Source : $SD_CARD" $FG
    AppendLog " Dest   : $DEST_LIVE\{YYYY_MM}\{YYYY_MM_DD}$($script:Suffix)" $FG
    AppendLog "============================================" $TEAL

    foreach ($step in @(
        @{ Label="NEFs"; Exts=@("nef"); Files=$NefFiles; Bytes=$TotalNefBytes; Sub="" },
        @{ Label="MP4s"; Exts=@("mp4"); Files=$Mp4Files; Bytes=$TotalMp4Bytes; Sub="" },
        @{ Label="360 files (.lrv/.insv)"; Exts=@("lrv","insv"); Files=($LrvFiles+$InsvFiles); Bytes=$Total360Bytes; Sub="360" }
    )) {
        if ($step.Files.Count -eq 0) {
            AppendLog "`n[INFO]  No $($step.Label) found - skipping." $FG_DIM
            continue
        }
        $LblStatus.Text = "Copying $($step.Label)..."
        AppendLog "`n[INFO]  Copying $($step.Files.Count) $($step.Label) ($(FormatBytes $step.Bytes))..." $YELLOW
        $ok = RunExifStep $step.Exts $SD_CARD $FileMap $DestIndex $IsDryRun $DEST_LIVE $step.Sub
        if (-not $ok) { ResetUI; return }
        AppendLog "[OK]    $($step.Label) step complete." $GREEN
    }

    $LblStatus.Text = "Checking orphan JPGs..."
    AppendLog "`n[INFO]  Orphan JPG check..." $YELLOW
    $OrphanCount = 0
    foreach ($Jpg in $JpgFiles) {
        if ($script:StopRequested) { ResetUI; return }
        $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($Jpg.Name)
        $NefMatch = $NefFiles | Where-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -eq $BaseName } | Select-Object -First 1
        if (-not $NefMatch) {
            $fileKey = $Jpg.Name.ToLower()
            if ($DestIndex.ContainsKey($fileKey)) {
                AppendLog "[SKIP]  Orphan JPG already in vault: $($Jpg.Name)" $ORANGE
            } else {
                AppendLog "[WARN]  Orphan JPG (no NEF): $($Jpg.Name)" $YELLOW
                if (-not $IsDryRun) {
                    $argStr = "-d `"$DEST_LIVE\%Y_%m\%Y_%m_%d$($script:Suffix)`" `"-Directory<DateTimeOriginal`" `"-Directory<CreateDate`" `"-Directory<FileModifyDate`" -o `".`" --overwrite_original `"$($Jpg.FullName)`""
                    $psi2 = New-Object System.Diagnostics.ProcessStartInfo
                    $psi2.FileName = $EXIFTOOL_LIVE; $psi2.Arguments = $argStr
                    $psi2.RedirectStandardOutput = $true; $psi2.UseShellExecute = $false; $psi2.CreateNoWindow = $true
                    $p2 = New-Object System.Diagnostics.Process; $p2.StartInfo = $psi2; $p2.Start() | Out-Null; $p2.WaitForExit()
                }
                $OrphanCount++
            }
        }
    }
    if ($OrphanCount -eq 0) { AppendLog "[OK]    No orphan JPGs." $GREEN }
    else { AppendLog "[WARN]  $OrphanCount orphan JPG(s) $(if ($IsDryRun) { 'would be copied' } else { 'copied' })." $YELLOW }

    $ProgressBar.Value   = 100
    $LblPct.Text         = "100%"
    $LblCurrentFile.Text = ""
    $LblStatus.Text      = "Verifying..."
    VerifyIngest ($NefFiles + $Mp4Files + $LrvFiles + $InsvFiles) $DEST_LIVE $IsDryRun

    AppendLog "`n[INFO]  Output folders:" $YELLOW
    Get-ChildItem -Path $DEST_LIVE -Recurse -Directory -ErrorAction SilentlyContinue | Sort-Object FullName | ForEach-Object {
        $fc = (Get-ChildItem -Path $_.FullName -File -ErrorAction SilentlyContinue).Count
        if ($fc -gt 0) {
            $rel = $_.FullName.Replace($DEST_LIVE, "").TrimStart("\")
            AppendLog "  $fc files  >>  $rel" $FG
        }
    }

    $elapsed    = [DateTime]::Now - $script:IngestStart
    $elapsedStr = "{0}m {1}s" -f [int]$elapsed.TotalMinutes, $elapsed.Seconds
    $avgSpeed   = if (-not $IsDryRun -and $elapsed.TotalSeconds -gt 0) { FormatSpeed ($TotalTransferBytes / $elapsed.TotalSeconds) } else { "n/a (dry run)" }

    AppendLog "`n-- SUMMARY ---------------------" $TEAL
    AppendLog "  Mode        : $modeLabel" $(if ($IsDryRun) { $YELLOW } else { $GREEN })
    AppendLog "  NEFs        : $($NefFiles.Count)  ($(FormatBytes $TotalNefBytes))" $FG
    AppendLog "  MP4s        : $($Mp4Files.Count)  ($(FormatBytes $TotalMp4Bytes))" $FG
    AppendLog "  360 files   : $($LrvFiles.Count + $InsvFiles.Count)  ($(FormatBytes $Total360Bytes))" $FG
    AppendLog "  Duplicates  : $dupCount skipped" $(if ($dupCount -gt 0) { $ORANGE } else { $FG })
    AppendLog "  Orphan JPGs : $OrphanCount" $FG
    AppendLog "  Total size  : $(FormatBytes $TotalTransferBytes)" $FG
    AppendLog "  Avg speed   : $avgSpeed" $FG
    AppendLog "  Total time  : $elapsedStr" $FG
    AppendLog "  Log         : $LOG" $FG_DIM
    AppendLog "---------------------------------" $TEAL

    if ($script:EjectChecked -and -not $IsDryRun) {
        $LblStatus.Text = "Ejecting..."
        AppendLog "`n[INFO]  Ejecting $DriveLetter..." $YELLOW
        [System.Windows.Forms.Application]::DoEvents()
        try {
            $Shell  = New-Object -ComObject Shell.Application
            $Volume = $Shell.Namespace(17).ParseName($DriveLetter.TrimEnd("\"))
            if ($Volume) {
                $Volume.InvokeVerb("Eject")
                Start-Sleep -Milliseconds 500
                AppendLog "[OK]    SD card ejected." $GREEN
            } else { AppendLog "[WARN]  Remove SD card manually." $YELLOW }
        } catch { AppendLog "[WARN]  Eject error - remove manually." $YELLOW }
    }

    $finalMsg            = "$(if ($IsDryRun) { 'Dry run complete' } else { 'Done!' })  $elapsedStr  |  avg $avgSpeed"
    $LblStatus.ForeColor = $GREEN
    $LblETA.Text         = "Done in $elapsedStr"
    $LblSpeed.Text       = if (-not $IsDryRun) { "avg $avgSpeed" } else { "" }
    AppendLog "`nIngest $(if ($IsDryRun) { 'simulation ' } else { '' })complete." $TEAL
    ResetUI
    $LblStatus.Text      = $finalMsg
    $LblStatus.ForeColor = $GREEN
})

try {
    [System.Windows.Forms.Application]::Run($Form)
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Startup error:`n`n$($_.Exception.Message)`n`nLine: $($_.InvocationInfo.ScriptLineNumber)",
        "Accurova - Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
}
