#Requires -Version 5.1
<#
.SYNOPSIS
    Exports Windows 10 MageeMedia configurations to E:\Migration_Backup and
    converts Windows Plex Registry values into a Linux-ready Preferences.xml.
#>

$ErrorActionPreference = "Stop"
$BackupRoot = "E:\Migration_Backup"
$AppDataStage = Join-Path $BackupRoot "appdata"

Write-Host "=== MageeMedia Windows-to-Linux Config Exporter ===" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $BackupRoot, $AppDataStage | Out-Null

# -----------------------------------------------------------------------------
# 1. Export Plex Registry & Generate Linux Preferences.xml
# -----------------------------------------------------------------------------
Write-Host "[1/4] Generating Linux Preferences.xml from Windows Registry..." -ForegroundColor Yellow
$PlexRegPath = "HKCU:\Software\Plex, Inc.\Plex Media Server"
if (Test-Path $PlexRegPath) {
    reg export "HKCU\Software\Plex, Inc.\Plex Media Server" (Join-Path $BackupRoot "plex_registry_backup.reg") /y | Out-Null
    $RegProps = Get-ItemProperty -Path $PlexRegPath

    # Map essential Plex Registry keys to XML attributes for Linux Docker
    $XmlKeys = @(
        "MachineIdentifier",
        "ProcessedMachineIdentifier",
        "AnonymousMachineIdentifier",
        "PlexOnlineToken",
        "PlexOnlineUsername",
        "PlexOnlineMail",
        "PlexOnlineHome",
        "FriendlyName",
        "AcceptedEULA",
        "PublishServerOnPlexOnlineKey",
        "CertificateUUID",
        "CertificateVersion",
        "ManualPortMappingMode",
        "LastAutomaticMappedPort",
        "DlnaEnabled",
        "ButlerStartHour",
        "ButlerEndHour",
        "LanguageInCloud",
        "TranscoderQuality"
    )

    $Attrs = foreach ($Key in $XmlKeys) {
        if ($null -ne $RegProps.$Key -and "$($RegProps.$Key)" -ne "") {
            $EscapedVal = [System.Security.SecurityElement]::Escape("$($RegProps.$Key)")
            "$Key=`"$EscapedVal`""
        }
    }
    # Force autoEmptyTrash="0" during migration so library path changes never delete watch history!
    $Attrs += 'autoEmptyTrash="0"'

    $PreferencesXml = "<?xml version=`"1.0`" encoding=`"utf-8`"?>`n<Preferences $($Attrs -join ' ')/>`n"
    $PrefOutPath = Join-Path $BackupRoot "Preferences.xml"
    Set-Content -Path $PrefOutPath -Value $PreferencesXml -Encoding UTF8
    Write-Host "  -> Saved Linux Preferences.xml to $PrefOutPath" -ForegroundColor Green
} else {
    Write-Warning "Plex Registry path not found at $PlexRegPath"
}

# -----------------------------------------------------------------------------
# 2. Export Tautulli Database & Convert config.ini Paths for Docker
# -----------------------------------------------------------------------------
Write-Host "[2/4] Backing up Tautulli database & converting config.ini paths..." -ForegroundColor Yellow
$TautulliSrc = "$env:LOCALAPPDATA\Tautulli"
$TautulliDst = Join-Path $AppDataStage "tautulli"
if (Test-Path $TautulliSrc) {
    New-Item -ItemType Directory -Force -Path $TautulliDst | Out-Null
    Copy-Item -Path (Join-Path $TautulliSrc "tautulli.db") -Destination $TautulliDst -Force
    foreach ($SubDir in @("backups", "newsletters")) {
        $SrcSub = Join-Path $TautulliSrc $SubDir
        if (Test-Path $SrcSub) {
            Copy-Item -Path $SrcSub -Destination $TautulliDst -Recurse -Force
        }
    }
    $ConfigIni = Get-Content (Join-Path $TautulliSrc "config.ini") -Raw
    $ConfigIni = $ConfigIni -replace 'backup_dir\s*=\s*.*', 'backup_dir = /config/backups'
    $ConfigIni = $ConfigIni -replace 'cache_dir\s*=\s*.*', 'cache_dir = /config/cache'
    $ConfigIni = $ConfigIni -replace 'export_dir\s*=\s*.*', 'export_dir = /config/exports'
    $ConfigIni = $ConfigIni -replace 'log_dir\s*=\s*.*', 'log_dir = /config/logs'
    $ConfigIni = $ConfigIni -replace 'newsletter_dir\s*=\s*.*', 'newsletter_dir = /config/newsletters'
    $ConfigIni = $ConfigIni -replace 'pms_ip\s*=\s*127\.0\.0\.1', 'pms_ip = 192.168.1.237'
    $ConfigIni = $ConfigIni -replace 'pms_url\s*=\s*http://127\.0\.0\.1:32400', 'pms_url = http://192.168.1.237:32400'
    Set-Content -Path (Join-Path $TautulliDst "config.ini") -Value $ConfigIni -Encoding UTF8
    Write-Host "  -> Staged Tautulli to $TautulliDst" -ForegroundColor Green
}

# -----------------------------------------------------------------------------
# 3. Export Pi-hole v6 & Unbound Configs from WSL1 RootFS
# -----------------------------------------------------------------------------
Write-Host "[3/4] Backing up Pi-hole v6 & Unbound configurations..." -ForegroundColor Yellow
$PiholeSrc = "C:\Program Files\Pi-hole\rootfs\etc"
$PiholeDst = Join-Path $AppDataStage "pihole"
$UnboundDst = Join-Path $AppDataStage "unbound"
if (Test-Path $PiholeSrc) {
    New-Item -ItemType Directory -Force -Path (Join-Path $PiholeDst "etc-pihole"), (Join-Path $PiholeDst "etc-dnsmasq.d"), $UnboundDst | Out-Null
    foreach ($File in @("pihole.toml", "gravity.db", "pihole-FTL.db", "dhcp.leases", "dnsmasq.conf", "cli_pw")) {
        $SrcFile = Join-Path "$PiholeSrc\pihole" $File
        if (Test-Path $SrcFile) {
            Copy-Item -Path $SrcFile -Destination (Join-Path $PiholeDst "etc-pihole") -Force
        }
    }
    Copy-Item -Path "$PiholeSrc\dnsmasq.d\*" -Destination (Join-Path $PiholeDst "etc-dnsmasq.d") -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "$PSScriptRoot\..\docker\unbound\pi-hole.conf" -Destination (Join-Path $UnboundDst "pi-hole.conf") -Force
    Write-Host "  -> Staged Pi-hole & Unbound to $PiholeDst and $UnboundDst" -ForegroundColor Green
}

# -----------------------------------------------------------------------------
# 4. Export Deluge Config (Optional Legacy Backup)
# -----------------------------------------------------------------------------
Write-Host "[4/4] Backing up Deluge state..." -ForegroundColor Yellow
$DelugeSrc = "$env:APPDATA\deluge"
$DelugeDst = Join-Path $AppDataStage "deluge"
if (Test-Path $DelugeSrc) {
    Copy-Item -Path $DelugeSrc -Destination $DelugeDst -Recurse -Force
    Write-Host "  -> Staged Deluge to $DelugeDst" -ForegroundColor Green
}

Write-Host "`nAll configurations successfully staged to $BackupRoot!" -ForegroundColor Cyan
