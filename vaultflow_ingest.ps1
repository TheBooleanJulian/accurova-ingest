# ============================================================
#  VAULTFLOW INGEST (Windows)
#  Camera-agnostic SD card ingest: sort by EXIF date, dedupe,
#  verify, ready to format. Configure your RAW/video/aux file
#  extensions in the FILE TYPES section to match your camera.
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -- CONFIG FILE ---------------------------------------------
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigFile = Join-Path $ScriptDir "vaultflow_config.json"
$IconFile   = Join-Path $ScriptDir "assets\vaultflow.ico"
$LogoFile   = Join-Path $ScriptDir "assets\vaultflow-icon.png"

function LoadConfig {
    if (Test-Path $ConfigFile) {
        try {
            $raw = Get-Content $ConfigFile -Raw | ConvertFrom-Json
            return @{
                Dest           = $raw.Dest
                LogDir         = $raw.LogDir
                Exiftool       = $raw.Exiftool
                RawExt         = if ($raw.RawExt)   { $raw.RawExt }   else { "nef" }
                VideoExt       = if ($raw.VideoExt) { $raw.VideoExt } else { "mp4" }
                AuxExt         = $raw.AuxExt
                Copyright      = $raw.Copyright
                ContactEmail   = $raw.ContactEmail
                Website        = $raw.Website
                TelegramToken  = $raw.TelegramToken
                TelegramChatId = $raw.TelegramChatId
            }
        } catch {}
    }
    return @{
        Dest           = "$env:USERPROFILE\Pictures\PhotoVault"
        LogDir         = "$env:USERPROFILE\Pictures\PhotoVault\_logs"
        Exiftool       = "C:\exiftool\exiftool.exe"
        RawExt         = "nef"
        VideoExt       = "mp4"
        AuxExt         = ""
        Copyright      = ""
        ContactEmail   = ""
        Website        = ""
        TelegramToken  = ""
        TelegramChatId = ""
    }
}

function SaveConfig($dest, $logDir, $exiftool, $rawExt, $videoExt, $auxExt, $copyright, $contactEmail, $website, $telegramToken, $telegramChatId) {
    @{
        Dest           = $dest
        LogDir         = $logDir
        Exiftool       = $exiftool
        RawExt         = $rawExt
        VideoExt       = $videoExt
        AuxExt         = $auxExt
        Copyright      = $copyright
        ContactEmail   = $contactEmail
        Website        = $website
        TelegramToken  = $telegramToken
        TelegramChatId = $telegramChatId
    } | ConvertTo-Json | Set-Content $ConfigFile -Encoding utf8
}

# Parses a comma-separated extension list ("nef, cr2 , .arw") into a clean
# lowercase array without dots ("nef","cr2","arw"), so users can paste
# whatever format they're used to.
function ParseExtList($raw) {
    if (-not $raw) { return @() }
    return @($raw -split "," | ForEach-Object { $_.Trim().TrimStart(".").ToLower() } | Where-Object { $_ -ne "" })
}

function GetFilesByExt($path, $extList) {
    if ($extList.Count -eq 0) { return @() }
    return @(Get-ChildItem -Path $path -Recurse -Include ($extList | ForEach-Object { "*.$_" }) -ErrorAction SilentlyContinue)
}

# -- CLIENT FOLDER SCAFFOLD & JOB-TYPE METADATA PRESETS -------
$ClientFolderTemplate = @(
    "01_RAW", "02_SELECTS", "03_EDITED", "04_EXPORTS", "05_DELIVERED"
)

# Extra IPTC keywords layered on top per job type. Edit these to taste.
$JobTypeKeywords = @{
    "Wedding"   = "wedding, bride, groom, ceremony, reception"
    "Corporate" = "corporate, business, headshot, professional"
    "Event"     = "event, conference, networking"
    "Portrait"  = "portrait, portraiture, headshot"
    "Other"     = ""
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
$Form.Text            = "VaultFlow Ingest"
$Form.Size            = New-Object System.Drawing.Size(1140, 1000)
$Form.StartPosition   = "CenterScreen"
$Form.BackColor       = $BG
$Form.ForeColor       = $FG
$Form.Font            = $FONT_UI
$Form.FormBorderStyle = "FixedSingle"
$Form.MaximizeBox     = $false
$Form.ShowInTaskbar   = $true
if (Test-Path $IconFile) {
    try { $Form.Icon = New-Object System.Drawing.Icon($IconFile) } catch {}
}

# -- HELPERS -------------------------------------------------
function MakeLabel($text, $x, $y, $w = 300) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text      = $text
    $l.Font      = $FONT_LBL
    $l.ForeColor = $FG_DIM
    $l.Location  = New-Object System.Drawing.Point($x, $y)
    $l.Size      = New-Object System.Drawing.Size($w, 18)
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
if (Test-Path $LogoFile) {
    $LogoBox = New-Object System.Windows.Forms.PictureBox
    $LogoBox.Image       = [System.Drawing.Image]::FromFile($LogoFile)
    $LogoBox.SizeMode    = "Zoom"
    $LogoBox.Location    = New-Object System.Drawing.Point(24, 14)
    $LogoBox.Size        = New-Object System.Drawing.Size(44, 44)
    $LogoBox.BackColor   = [System.Drawing.Color]::Transparent
    $Form.Controls.Add($LogoBox)
    $TitleX = 76
} else {
    $TitleX = 24
}

$LblTitle = New-Object System.Windows.Forms.Label
$LblTitle.Text      = "VAULTFLOW"
$LblTitle.Font      = $FONT_TTL
$LblTitle.ForeColor = $TEAL
$LblTitle.Location  = New-Object System.Drawing.Point($TitleX, 18)
$LblTitle.Size      = New-Object System.Drawing.Size(200, 36)
$Form.Controls.Add($LblTitle)

$LblSub = New-Object System.Windows.Forms.Label
$LblSub.Text      = "SD CARD INGEST UTILITY"
$LblSub.Font      = $FONT_SUB
$LblSub.ForeColor = $FG_DIM
$LblSub.Location  = New-Object System.Drawing.Point(($TitleX + 2), 52)
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
    $auxVal      = if ($TxtAuxExt.Text -eq $TxtAuxExt.Tag) { "" } else { $TxtAuxExt.Text.Trim() }
    $copyVal     = if ($TxtCopyright.Text -eq $TxtCopyright.Tag) { "" } else { $TxtCopyright.Text.Trim() }
    $contactVal  = if ($TxtContactEmail.Text -eq $TxtContactEmail.Tag) { "" } else { $TxtContactEmail.Text.Trim() }
    $websiteVal  = if ($TxtWebsite.Text -eq $TxtWebsite.Tag) { "" } else { $TxtWebsite.Text.Trim() }
    $tgTokenVal  = if ($TxtTelegramToken.Text -eq $TxtTelegramToken.Tag) { "" } else { $TxtTelegramToken.Text.Trim() }
    $tgChatIdVal = if ($TxtTelegramChatId.Text -eq $TxtTelegramChatId.Tag) { "" } else { $TxtTelegramChatId.Text.Trim() }
    SaveConfig $DestBox.TextBox.Text.Trim() $LogBox.TextBox.Text.Trim() $ExifBox.TextBox.Text.Trim() $TxtRawExt.Text.Trim() $TxtVideoExt.Text.Trim() $auxVal $copyVal $contactVal $websiteVal $tgTokenVal $tgChatIdVal
    $LblSaveStatus.Text = "Saved."
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 2000
    $timer.Add_Tick({ $LblSaveStatus.Text = ""; $this.Stop() })
    $timer.Start()
})

AddDivider 314

# ============================================================
#  SECTION: FILE TYPES  (camera-agnostic - configure per camera)
# ============================================================
AddSectionHeader "  FILE TYPES" 324

$Form.Controls.Add((MakeLabel "RAW EXTENSIONS" 24 354 208))
$TxtRawExt = MakeTextBox 24 372 196 $Config.RawExt
$Form.Controls.Add($TxtRawExt)

$Form.Controls.Add((MakeLabel "VIDEO EXTENSIONS" 240 354 208))
$TxtVideoExt = MakeTextBox 240 372 196 $Config.VideoExt
$Form.Controls.Add($TxtVideoExt)

$Form.Controls.Add((MakeLabel "AUX EXT. (optional)" 456 354 196))
$TxtAuxExt = MakePlaceholderTextBox 456 372 196 "e.g. lrv, insv"
if ($Config.AuxExt) { $TxtAuxExt.Text = $Config.AuxExt; $TxtAuxExt.ForeColor = $FG }
$Form.Controls.Add($TxtAuxExt)

$LblFileTypesHint = New-Object System.Windows.Forms.Label
$LblFileTypesHint.Text      = "Comma-separated, no dots. RAW example: nef, cr2, cr3, arw, raf, orf, rw2, dng.  AUX = proxy/360 footage, e.g. GoPro/Insta360 .lrv/.insv"
$LblFileTypesHint.Font      = $FONT_SUB
$LblFileTypesHint.ForeColor = $FG_DIM
$LblFileTypesHint.Location  = New-Object System.Drawing.Point(24, 402)
$LblFileTypesHint.Size      = New-Object System.Drawing.Size(628, 18)
$Form.Controls.Add($LblFileTypesHint)

AddDivider 434

# ============================================================
#  SECTION: METADATA  (embedded into every ingested file via ExifTool)
# ============================================================
AddSectionHeader "  METADATA  /  NOTIFICATIONS" 444

$Form.Controls.Add((MakeLabel "COPYRIGHT" 24 474 120))
$TxtCopyright = MakePlaceholderTextBox 24 492 120 "(c) 2026 Jane Doe"
if ($Config.Copyright) { $TxtCopyright.Text = $Config.Copyright; $TxtCopyright.ForeColor = $FG }
$Form.Controls.Add($TxtCopyright)

$Form.Controls.Add((MakeLabel "CONTACT EMAIL" 151 474 120))
$TxtContactEmail = MakePlaceholderTextBox 151 492 120 "you@site.com"
if ($Config.ContactEmail) { $TxtContactEmail.Text = $Config.ContactEmail; $TxtContactEmail.ForeColor = $FG }
$Form.Controls.Add($TxtContactEmail)

$Form.Controls.Add((MakeLabel "WEBSITE" 278 474 120))
$TxtWebsite = MakePlaceholderTextBox 278 492 120 "yoursite.com"
if ($Config.Website) { $TxtWebsite.Text = $Config.Website; $TxtWebsite.ForeColor = $FG }
$Form.Controls.Add($TxtWebsite)

$Form.Controls.Add((MakeLabel "TG BOT TOKEN" 405 474 120))
$TxtTelegramToken = MakePlaceholderTextBox 405 492 120 "bot token"
if ($Config.TelegramToken) { $TxtTelegramToken.Text = $Config.TelegramToken; $TxtTelegramToken.ForeColor = $FG }
$Form.Controls.Add($TxtTelegramToken)

$Form.Controls.Add((MakeLabel "TG CHAT ID" 532 474 120))
$TxtTelegramChatId = MakePlaceholderTextBox 532 492 120 "chat id"
if ($Config.TelegramChatId) { $TxtTelegramChatId.Text = $Config.TelegramChatId; $TxtTelegramChatId.ForeColor = $FG }
$Form.Controls.Add($TxtTelegramChatId)

$LblMetadataHint = New-Object System.Windows.Forms.Label
$LblMetadataHint.Text      = "Metadata written to every ingested file via ExifTool, plus Job Type keywords. Telegram fields are optional - leave blank to skip the completion notification."
$LblMetadataHint.Font      = $FONT_SUB
$LblMetadataHint.ForeColor = $FG_DIM
$LblMetadataHint.Location  = New-Object System.Drawing.Point(24, 522)
$LblMetadataHint.Size      = New-Object System.Drawing.Size(628, 18)
$Form.Controls.Add($LblMetadataHint)

AddDivider 554

# ============================================================
#  SECTION: SESSION
# ============================================================
AddSectionHeader "  SESSION" 564

$Form.Controls.Add((MakeLabel "CLIENT NAME" 24 594 300))
$TxtClient = MakePlaceholderTextBox 24 612 300 "e.g. Tan Family"
$Form.Controls.Add($TxtClient)

$Form.Controls.Add((MakeLabel "JOB TYPE" 340 594 150))
$CmbJobType = New-Object System.Windows.Forms.ComboBox
$CmbJobType.Location      = New-Object System.Drawing.Point(340, 612)
$CmbJobType.Size          = New-Object System.Drawing.Size(150, 26)
$CmbJobType.BackColor     = $PANEL
$CmbJobType.ForeColor     = $FG
$CmbJobType.FlatStyle     = "Flat"
$CmbJobType.Font          = $FONT_UI
$CmbJobType.DropDownStyle = "DropDownList"
foreach ($jt in @("Wedding", "Corporate", "Event", "Portrait", "Other")) { $CmbJobType.Items.Add($jt) | Out-Null }
$CmbJobType.SelectedItem = "Other"
$Form.Controls.Add($CmbJobType)

$Form.Controls.Add((MakeLabel "EVENT NAME" 24 648))
$TxtEvent = MakePlaceholderTextBox 24 666 400 "e.g. FAF Day 2"
$Form.Controls.Add($TxtEvent)

$Form.Controls.Add((MakeLabel "SD CARD DRIVE" 24 702))
$CmbDrive = New-Object System.Windows.Forms.ComboBox
$CmbDrive.Location      = New-Object System.Drawing.Point(24, 720)
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
$LblAutoDetect.Location  = New-Object System.Drawing.Point(136, 724)
$LblAutoDetect.Size      = New-Object System.Drawing.Size(300, 18)
$Form.Controls.Add($LblAutoDetect)

# -- EJECT TOGGLE (inlined) ----------------------------------
$script:EjectChecked = $false

$EjectTrack = New-Object System.Windows.Forms.Panel
$EjectTrack.Location  = New-Object System.Drawing.Point(24, 756)
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
$EjectLabel.Location  = New-Object System.Drawing.Point(68, 757)
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

# Dry run banner - shown while a dry run is in progress
$DryRunBanner = New-Object System.Windows.Forms.Panel
$DryRunBanner.BackColor = [System.Drawing.Color]::FromArgb(60, 50, 0)
$DryRunBanner.Location  = New-Object System.Drawing.Point(24, 782)
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

AddDivider 844

# ============================================================
#  BUTTONS
# ============================================================
$GOLD = [System.Drawing.Color]::FromArgb(212, 175, 55)

$BtnDryRun = New-Object System.Windows.Forms.Button
$BtnDryRun.Text      = "START DRY RUN"
$BtnDryRun.Location  = New-Object System.Drawing.Point(24, 854)
$BtnDryRun.Size      = New-Object System.Drawing.Size(170, 38)
$BtnDryRun.BackColor = $PANEL
$BtnDryRun.ForeColor = $FG
$BtnDryRun.FlatStyle = "Flat"
$BtnDryRun.Font      = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5)
$BtnDryRun.FlatAppearance.BorderColor = $FG_DIM
$BtnDryRun.FlatAppearance.BorderSize  = 1
$BtnDryRun.Cursor    = "Hand"
$Form.Controls.Add($BtnDryRun)

$BtnLiveIngest = New-Object System.Windows.Forms.Button
$BtnLiveIngest.Text      = "START LIVE INGEST"
$BtnLiveIngest.Location  = New-Object System.Drawing.Point(204, 854)
$BtnLiveIngest.Size      = New-Object System.Drawing.Size(170, 38)
$BtnLiveIngest.BackColor = $TEAL
$BtnLiveIngest.ForeColor = $BG
$BtnLiveIngest.FlatStyle = "Flat"
$BtnLiveIngest.Font      = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5)
$BtnLiveIngest.FlatAppearance.BorderColor = $GOLD
$BtnLiveIngest.FlatAppearance.BorderSize  = 2
$BtnLiveIngest.Cursor    = "Hand"
$Form.Controls.Add($BtnLiveIngest)

$BtnStop = New-Object System.Windows.Forms.Button
$BtnStop.Text      = "STOP"
$BtnStop.Location  = New-Object System.Drawing.Point(384, 854)
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
$LblStatus.Location  = New-Object System.Drawing.Point(484, 866)
$LblStatus.Size      = New-Object System.Drawing.Size(168, 18)
$Form.Controls.Add($LblStatus)

AddDivider 902

# ============================================================
#  PROGRESS
# ============================================================
$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Location  = New-Object System.Drawing.Point(24, 912)
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
$LblPct.Location  = New-Object System.Drawing.Point(24, 934)
$LblPct.Size      = New-Object System.Drawing.Size(60, 18)
$Form.Controls.Add($LblPct)

$LblFiles = New-Object System.Windows.Forms.Label
$LblFiles.Text      = "0 / 0 files"
$LblFiles.Font      = $FONT_SUB
$LblFiles.ForeColor = $FG_DIM
$LblFiles.Location  = New-Object System.Drawing.Point(90, 934)
$LblFiles.Size      = New-Object System.Drawing.Size(160, 18)
$Form.Controls.Add($LblFiles)

$LblSpeed = New-Object System.Windows.Forms.Label
$LblSpeed.Text      = ""
$LblSpeed.Font      = $FONT_SUB
$LblSpeed.ForeColor = $FG_DIM
$LblSpeed.Location  = New-Object System.Drawing.Point(280, 934)
$LblSpeed.Size      = New-Object System.Drawing.Size(120, 18)
$Form.Controls.Add($LblSpeed)

$LblETA = New-Object System.Windows.Forms.Label
$LblETA.Text      = ""
$LblETA.Font      = $FONT_SUB
$LblETA.ForeColor = $FG_DIM
$LblETA.Location  = New-Object System.Drawing.Point(430, 934)
$LblETA.Size      = New-Object System.Drawing.Size(222, 18)
$Form.Controls.Add($LblETA)

$LblCurrentFile = New-Object System.Windows.Forms.Label
$LblCurrentFile.Text      = ""
$LblCurrentFile.Font      = $FONT_SUB
$LblCurrentFile.ForeColor = $FG_DIM
$LblCurrentFile.Location  = New-Object System.Drawing.Point(24, 954)
$LblCurrentFile.Size      = New-Object System.Drawing.Size(628, 18)
$Form.Controls.Add($LblCurrentFile)

# ============================================================
#  RIGHT PANEL - OUTPUT LOG (full height)
# ============================================================

# Vertical divider between left controls and right log
$VDivider = New-Object System.Windows.Forms.Panel
$VDivider.BackColor = $PANEL
$VDivider.Location  = New-Object System.Drawing.Point(668, 86)
$VDivider.Size      = New-Object System.Drawing.Size(1, 874)
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
$TxtLog.Size        = New-Object System.Drawing.Size(431, 850)
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
    $BtnDryRun.Enabled     = $true
    $BtnLiveIngest.Enabled = $true
    $BtnStop.Enabled       = $false
    $BtnDryRun.Text        = "START DRY RUN"
    $BtnLiveIngest.Text    = "START LIVE INGEST"
    $BtnDryRun.BackColor   = $PANEL
    $BtnLiveIngest.BackColor = $TEAL
    $LblSpeed.Text       = ""
    $LblETA.Text         = ""
    $LblCurrentFile.Text = ""
}

# -- SD AUTO-DETECT ------------------------------------------
function DetectSDCard {
    foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
        if ($drive.DriveType -eq "Removable" -and $drive.IsReady) {
            if (Test-Path (Join-Path $drive.RootDirectory.FullName "DCIM")) {
                $label = $drive.VolumeLabel
                if (-not $label) { $label = "(no label)" }
                return @{ Letter = $drive.Name.TrimEnd("\"); Label = $label }
            }
        }
    }
    return $null
}

$Form.Add_Shown({
    $found = DetectSDCard
    if ($found) {
        $item = $found.Letter + "\"
        if ($CmbDrive.Items.Contains($item)) { $CmbDrive.SelectedItem = $item }
        $LblAutoDetect.Text      = "Auto-detected: $($found.Letter) `"$($found.Label)`" (DCIM found)"
        $LblAutoDetect.ForeColor = $GREEN
    } else {
        $LblAutoDetect.Text      = "No SD card detected - select manually"
        $LblAutoDetect.ForeColor = $YELLOW
    }
})

$CmbDrive.Add_DropDown({
    $found = DetectSDCard
    if ($found) {
        $item = $found.Letter + "\"
        if ($CmbDrive.Items.Contains($item)) { $CmbDrive.SelectedItem = $item }
        $LblAutoDetect.Text      = "Auto-detected: $($found.Letter) `"$($found.Label)`""
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
            if (-not $index.ContainsKey($key)) { $index[$key] = @{ Length = $_.Length; Path = $_.FullName } }
        }
    }
    return $index
}

# A file only counts as a duplicate when the recycled filename AND size match -
# Nikon bodies wrap the DSC_/file counter back to 0001 after ~9999 shots, so
# unrelated files can share a name across shoots. Name+size is just a cheap
# pre-filter though, so once both match we confirm with an MD5 checksum
# against the actual vault file before calling it a true duplicate.
function IsDuplicateInVault($destIndex, $key, $sourceLength, $sourcePath) {
    if (-not $destIndex.ContainsKey($key)) { return $false }
    $entry = $destIndex[$key]
    if ($entry.Length -ne $sourceLength) { return $false }
    if (-not $sourcePath -or -not (Test-Path $sourcePath) -or -not (Test-Path $entry.Path)) { return $false }
    $srcHash  = (Get-FileHash -Path $sourcePath -Algorithm MD5).Hash
    $destHash = (Get-FileHash -Path $entry.Path -Algorithm MD5).Hash
    return $srcHash -eq $destHash
}

# -- EXIFTOOL RUNNER -----------------------------------------
# $subFolder: optional subfolder appended after the date folder (e.g. "360")
# $sourceFiles: pre-gathered FileInfo list for this step (e.g. $RawFiles)
function RunExifStep($sourceFiles, $fileMap, $destIndex, $isDryRun, $dest, $subFolder = "") {
    $subPart  = if ($subFolder -ne "") { "\$subFolder" } else { "" }
    $destPattern = "$dest\%Y_%m\%Y-%m-%d$($script:Suffix)\01_RAW$subPart"

    if ($isDryRun) {
        foreach ($f in $sourceFiles) {
            if ($script:StopRequested) { return $false }
            $key = $f.Name.ToLower()
            if (IsDuplicateInVault $destIndex $key $f.Length $f.FullName) {
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
        return $true
    }

    # Filter out true duplicates (name+size+checksum) BEFORE invoking ExifTool,
    # so already-vaulted files are neither re-copied nor overwritten.
    $toCopy = @()
    foreach ($f in $sourceFiles) {
        $key = $f.Name.ToLower()
        if (IsDuplicateInVault $destIndex $key $f.Length $f.FullName) {
            AppendLog ("  [DUPLICATE - already in vault]  " + $f.Name) $ORANGE
            $script:BytesDone += $f.Length
            $script:FilesDone++
        } else {
            $toCopy += $f
        }
    }
    if ($toCopy.Count -eq 0) { return $true }

    $argFile = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $argFile -Value ($toCopy | ForEach-Object { $_.FullName }) -Encoding UTF8

    $argStr = "-@ `"$argFile`" -d `"$destPattern`" `"-Directory<DateTimeOriginal`" `"-Directory<CreateDate`" `"-Directory<FileModifyDate`" $($script:MetadataArgs) -o `".`" --overwrite_original -progress"

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
                $fileSize = 0
                if ($fileMap.ContainsKey($baseName)) { $fileSize = $fileMap[$baseName].Length }
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
            } elseif ($trimmed -match "\d+ image files") {
                AppendLog "  $trimmed" $GREEN
            } elseif ($trimmed -match "^(Error|Warning)") {
                AppendLog "  $trimmed" $YELLOW
            }
        }
        [System.Windows.Forms.Application]::DoEvents()
        if ($script:StopRequested) {
            try { $script:CurrentProcess.Kill() } catch {}
            Remove-Item -Path $argFile -Force -ErrorAction SilentlyContinue
            return $false
        }
    }
    $errText = $script:CurrentProcess.StandardError.ReadToEnd()
    if ($errText.Trim() -ne "") { AppendLog "  $errText" $FG_DIM }
    $script:CurrentProcess.WaitForExit()
    Remove-Item -Path $argFile -Force -ErrorAction SilentlyContinue
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

# -- TELEGRAM NOTIFICATION -------------------------------------
# Best-effort: failures are logged but never abort or fail the ingest.
function SendTelegramNotification($token, $chatId, $message) {
    if (-not $token -or -not $chatId) { return }
    try {
        $uri  = "https://api.telegram.org/bot$token/sendMessage"
        $body = @{ chat_id = $chatId; text = $message }
        Invoke-RestMethod -Uri $uri -Method Post -Body $body -TimeoutSec 10 | Out-Null
        AppendLog "[OK]    Telegram notification sent." $GREEN
    } catch {
        AppendLog "[WARN]  Telegram notification failed: $($_.Exception.Message)" $YELLOW
    }
}

# ============================================================
#  RUN BUTTONS
# ============================================================
function StartIngest($IsDryRun) {
    $TxtLog.Clear()
    $script:StopRequested  = $false
    $BtnDryRun.Enabled     = $false
    $BtnLiveIngest.Enabled = $false
    $BtnStop.Enabled       = $true
    $DryRunBanner.Visible  = $IsDryRun
    if ($IsDryRun) {
        $BtnDryRun.Text      = "RUNNING..."
        $BtnDryRun.BackColor = $TEAL_DIM
    } else {
        $BtnLiveIngest.Text      = "RUNNING..."
        $BtnLiveIngest.BackColor = $TEAL_DIM
    }
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

    if ($DEST_LIVE -eq "") {
        AppendLog "[ERROR] Vault destination path is empty." $RED; ResetUI; return
    }
    if (-not $IsDryRun -and -not (Test-Path $EXIFTOOL_LIVE)) {
        AppendLog "[ERROR] exiftool.exe not found at: $EXIFTOOL_LIVE" $RED
        AppendLog "        Update the ExifTool path in the Paths section above." $RED
        ResetUI; return
    }

    $ClientVal = $TxtClient.Text.Trim()
    $EvtVal    = $TxtEvent.Text.Trim()
    if ($ClientVal -eq $TxtClient.Tag) { $ClientVal = "" }
    if ($EvtVal -eq $TxtEvent.Tag)     { $EvtVal = "" }
    # Day-folder name: YYYY-MM-DD[_Client][_Event] - matches the client-facing
    # naming convention, enforced here instead of typed manually per shoot.
    $script:Suffix = ""
    if ($ClientVal -ne "") { $script:Suffix += "_$ClientVal" }
    if ($EvtVal -ne "")    { $script:Suffix += "_$EvtVal" }
    $script:Suffix = $script:Suffix -replace '[\\/:*?"<>|]', '-'

    $JobTypeVal  = $CmbJobType.SelectedItem.ToString()
    $KeywordsVal = $JobTypeKeywords[$JobTypeVal]
    $CopyrightVal = $TxtCopyright.Text.Trim()
    $WebsiteVal   = if ($TxtWebsite.Text -eq $TxtWebsite.Tag) { "" } else { $TxtWebsite.Text.Trim() }
    $ContactVal   = if ($TxtContactEmail.Text -eq $TxtContactEmail.Tag) { "" } else { $TxtContactEmail.Text.Trim() }
    $metaParts = @()
    if ($CopyrightVal -ne "") { $metaParts += "-Copyright=`"$CopyrightVal`"" }
    if ($WebsiteVal   -ne "") { $metaParts += "-Credit=`"$WebsiteVal`"" }
    if ($ContactVal   -ne "") { $metaParts += "-Source=`"$ContactVal`"" }
    if ($KeywordsVal  -ne "") { $metaParts += "-Keywords=`"$KeywordsVal`"" }
    $script:MetadataArgs = $metaParts -join " "

    $RawExtList   = ParseExtList $TxtRawExt.Text.Trim()
    $VideoExtList = ParseExtList $TxtVideoExt.Text.Trim()
    $AuxRaw       = if ($TxtAuxExt.Text -eq $TxtAuxExt.Tag) { "" } else { $TxtAuxExt.Text.Trim() }
    $AuxExtList   = ParseExtList $AuxRaw

    if ($RawExtList.Count -eq 0) {
        AppendLog "[ERROR] No RAW extensions configured. Set at least one under FILE TYPES (e.g. nef, cr2, arw)." $RED
        ResetUI; return
    }

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

    $RawFiles   = GetFilesByExt $SD_CARD $RawExtList
    $VideoFiles = GetFilesByExt $SD_CARD $VideoExtList
    $AuxFiles   = GetFilesByExt $SD_CARD $AuxExtList
    $JpgFiles   = @(Get-ChildItem -Path $SD_CARD -Recurse -Include "*.jpg","*.jpeg" -ErrorAction SilentlyContinue)

    $FileMap = @{}
    foreach ($f in ($RawFiles + $VideoFiles + $AuxFiles + $JpgFiles)) {
        $key = [System.IO.Path]::GetFileNameWithoutExtension($f.Name).ToLower()
        if (-not $FileMap.ContainsKey($key)) { $FileMap[$key] = $f }
    }

    $TotalRawBytes   = ($RawFiles   | Measure-Object -Property Length -Sum).Sum
    $TotalVideoBytes = ($VideoFiles | Measure-Object -Property Length -Sum).Sum
    $TotalAuxBytes   = ($AuxFiles   | Measure-Object -Property Length -Sum).Sum
    if (-not $TotalRawBytes)   { $TotalRawBytes   = 0 }
    if (-not $TotalVideoBytes) { $TotalVideoBytes = 0 }
    if (-not $TotalAuxBytes)   { $TotalAuxBytes   = 0 }
    $TotalTransferBytes = $TotalRawBytes + $TotalVideoBytes + $TotalAuxBytes
    $script:TotalFiles  = $RawFiles.Count + $VideoFiles.Count + $AuxFiles.Count
    $script:TotalBytes  = $TotalTransferBytes
    $script:FilesDone   = 0
    $script:BytesDone   = 0

    AppendLog "[INFO]  Found $($RawFiles.Count) RAW files   ($(FormatBytes $TotalRawBytes))" $FG
    AppendLog "[INFO]  Found $($VideoFiles.Count) video files   ($(FormatBytes $TotalVideoBytes))" $FG
    if ($AuxExtList.Count -gt 0) {
        AppendLog "[INFO]  Found $($AuxFiles.Count) aux files ($($AuxExtList -join '/'))  ($(FormatBytes $TotalAuxBytes))" $FG
    }
    AppendLog "[INFO]  Total: $(FormatBytes $TotalTransferBytes)" $FG

    $LblStatus.Text = "Building duplicate index..."
    AppendLog "[INFO]  Indexing vault for duplicates..." $YELLOW
    [System.Windows.Forms.Application]::DoEvents()
    $DestIndex = BuildDestIndex $DEST_LIVE
    AppendLog "[INFO]  Vault index: $($DestIndex.Count) existing files." $FG
    $dupCount = 0
    foreach ($f in ($RawFiles + $VideoFiles)) {
        if (IsDuplicateInVault $DestIndex $f.Name.ToLower() $f.Length $f.FullName) { $dupCount++ }
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
                "VaultFlow - Storage Warning",
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
    AppendLog " VAULTFLOW  [$modeLabel]  -  $(Get-Date -Format 'yyyy-MM-dd HH:mm')" $TEAL
    AppendLog " Source : $SD_CARD" $FG
    AppendLog " Dest   : $DEST_LIVE\{YYYY_MM}\{YYYY-MM-DD}$($script:Suffix)\01_RAW" $FG
    AppendLog "============================================" $TEAL

    foreach ($step in @(
        @{ Label="RAW files"; Files=$RawFiles; Bytes=$TotalRawBytes; Sub="" },
        @{ Label="video files"; Files=$VideoFiles; Bytes=$TotalVideoBytes; Sub="" },
        @{ Label="aux files"; Files=$AuxFiles; Bytes=$TotalAuxBytes; Sub="aux" }
    )) {
        if ($step.Files.Count -eq 0) {
            AppendLog "`n[INFO]  No $($step.Label) found - skipping." $FG_DIM
            continue
        }
        $LblStatus.Text = "Copying $($step.Label)..."
        AppendLog "`n[INFO]  Copying $($step.Files.Count) $($step.Label) ($(FormatBytes $step.Bytes))..." $YELLOW
        $ok = RunExifStep $step.Files $FileMap $DestIndex $IsDryRun $DEST_LIVE $step.Sub
        if (-not $ok) { ResetUI; return }
        AppendLog "[OK]    $($step.Label) step complete." $GREEN
    }

    $LblStatus.Text = "Checking orphan JPGs..."
    AppendLog "`n[INFO]  Orphan JPG check..." $YELLOW
    $OrphanCount = 0
    foreach ($Jpg in $JpgFiles) {
        if ($script:StopRequested) { ResetUI; return }
        $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($Jpg.Name)
        $RawMatch = $RawFiles | Where-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -eq $BaseName } | Select-Object -First 1
        if (-not $RawMatch) {
            $fileKey = $Jpg.Name.ToLower()
            if (IsDuplicateInVault $DestIndex $fileKey $Jpg.Length $Jpg.FullName) {
                AppendLog "[SKIP]  Orphan JPG already in vault: $($Jpg.Name)" $ORANGE
            } else {
                AppendLog "[WARN]  Orphan JPG (no matching RAW file): $($Jpg.Name)" $YELLOW
                if (-not $IsDryRun) {
                    $argStr = "-d `"$DEST_LIVE\%Y_%m\%Y-%m-%d$($script:Suffix)\01_RAW`" `"-Directory<DateTimeOriginal`" `"-Directory<CreateDate`" `"-Directory<FileModifyDate`" $($script:MetadataArgs) -o `".`" --overwrite_original `"$($Jpg.FullName)`""
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

    # -- CLIENT FOLDER SCAFFOLD -----------------------------------
    # Ensures every day folder under the vault has the full 5-folder
    # client structure (01_RAW..05_DELIVERED), not just the ones ExifTool
    # happened to create while copying RAW/video files.
    $LblStatus.Text = "Building client folder structure..."
    if ($IsDryRun) {
        AppendLog "`n[INFO]  Would create client folder structure ($($ClientFolderTemplate -join ', ')) in touched day folder(s)." $FG_DIM
    } else {
        $ScaffoldCount = 0
        foreach ($MonthFolder in (Get-ChildItem -Path $DEST_LIVE -Directory -ErrorAction SilentlyContinue)) {
            $DayFolders = Get-ChildItem -Path $MonthFolder.FullName -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}' }
            foreach ($DayFolder in $DayFolders) {
                foreach ($SubFolder in $ClientFolderTemplate) {
                    New-Item -ItemType Directory -Force -Path (Join-Path $DayFolder.FullName $SubFolder) | Out-Null
                }
                $ScaffoldCount++
            }
        }
        if ($ScaffoldCount -gt 0) {
            AppendLog "`n[OK]    Client folder structure ensured in $ScaffoldCount day folder(s)." $GREEN
        }
    }

    $ProgressBar.Value   = 100
    $LblPct.Text         = "100%"
    $LblCurrentFile.Text = ""
    $LblStatus.Text      = "Verifying..."
    VerifyIngest ($RawFiles + $VideoFiles + $AuxFiles) $DEST_LIVE $IsDryRun

    $elapsed    = [DateTime]::Now - $script:IngestStart
    $elapsedStr = "{0}m {1}s" -f [int]$elapsed.TotalMinutes, $elapsed.Seconds
    $avgSpeed   = if (-not $IsDryRun -and $elapsed.TotalSeconds -gt 0) { FormatSpeed ($TotalTransferBytes / $elapsed.TotalSeconds) } else { "n/a (dry run)" }

    AppendLog "`n-- SUMMARY ---------------------" $TEAL
    AppendLog "  Mode        : $modeLabel" $(if ($IsDryRun) { $YELLOW } else { $GREEN })
    AppendLog "  RAW files   : $($RawFiles.Count)  ($(FormatBytes $TotalRawBytes))" $FG
    AppendLog "  Video files : $($VideoFiles.Count)  ($(FormatBytes $TotalVideoBytes))" $FG
    AppendLog "  Aux files   : $($AuxFiles.Count)  ($(FormatBytes $TotalAuxBytes))" $FG
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

    if (-not $IsDryRun) {
        $tgToken  = if ($TxtTelegramToken.Text -eq $TxtTelegramToken.Tag) { "" } else { $TxtTelegramToken.Text.Trim() }
        $tgChatId = if ($TxtTelegramChatId.Text -eq $TxtTelegramChatId.Tag) { "" } else { $TxtTelegramChatId.Text.Trim() }
        if ($tgToken -ne "" -and $tgChatId -ne "") {
            $jobLabel = @($ClientVal, $EvtVal) | Where-Object { $_ -ne "" }
            $jobLabel = if ($jobLabel.Count -gt 0) { $jobLabel -join " - " } else { "Untitled job" }
            $totalFiles = $RawFiles.Count + $VideoFiles.Count + $AuxFiles.Count
            $tgMessage = "VaultFlow Ingest complete - $jobLabel`n$totalFiles files, $(FormatBytes $TotalTransferBytes), ${elapsedStr}."
            SendTelegramNotification $tgToken $tgChatId $tgMessage
        }
    }

    $finalMsg            = "$(if ($IsDryRun) { 'Dry run complete' } else { 'Done!' })  $elapsedStr  |  avg $avgSpeed"
    $LblStatus.ForeColor = $GREEN
    $LblETA.Text         = "Done in $elapsedStr"
    $LblSpeed.Text       = if (-not $IsDryRun) { "avg $avgSpeed" } else { "" }
    AppendLog "`nIngest $(if ($IsDryRun) { 'simulation ' } else { '' })complete." $TEAL
    ResetUI
    $LblStatus.Text      = $finalMsg
    $LblStatus.ForeColor = $GREEN
}

$BtnDryRun.Add_Click({ StartIngest $true })
$BtnLiveIngest.Add_Click({ StartIngest $false })

try {
    [System.Windows.Forms.Application]::Run($Form)
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Startup error:`n`n$($_.Exception.Message)`n`nLine: $($_.InvocationInfo.ScriptLineNumber)",
        "VaultFlow - Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
}
