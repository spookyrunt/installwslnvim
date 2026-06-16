# Master setup script - run as Administrator in PowerShell
# Runs all steps in order: WSL install, nvim setup, registry import

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Step 1: WSL + Ubuntu
Write-Host "==> Step 1: Installing WSL and Ubuntu..." -ForegroundColor Cyan
wsl --install -d Ubuntu

# Step 2: nvim setup inside WSL
Write-Host "==> Step 2: Running nvim setup in WSL..." -ForegroundColor Cyan
$WinPath = Join-Path $ScriptDir "2_nvim-setup.sh"
$Drive = $WinPath[0].ToString().ToLower()
$BashScript = "/mnt/$Drive/" + $WinPath.Substring(3).Replace("\", "/")
wsl -d Ubuntu bash $BashScript
Write-Host "    Done." -ForegroundColor Green

# Step 3: Registry import
Write-Host "==> Step 3: Importing registry..." -ForegroundColor Cyan
reg import "$ScriptDir\3_nvim-registry.reg"
Write-Host "    Done." -ForegroundColor Green

# Step 4a: Download han2f12.exe
Write-Host "==> Step 4a: Downloading han2f12.exe..." -ForegroundColor Cyan
$Han2F12Url = "https://github.com/spookyrunt/han2f12/releases/latest/download/han2f12.exe"
$Han2F12Dir = Read-Host "    Where should han2f12.exe be saved? [D:\Apps]"
if (-not $Han2F12Dir) { $Han2F12Dir = "D:\Apps" }
$Han2F12Path = Join-Path $Han2F12Dir "han2f12.exe"
New-Item -ItemType Directory -Force -Path $Han2F12Dir | Out-Null
if (-not (Test-Path $Han2F12Path)) {
    Invoke-WebRequest -Uri $Han2F12Url -OutFile $Han2F12Path
    Write-Host "    Done." -ForegroundColor Green
} else {
    Write-Host "    han2f12.exe already exists, skipping." -ForegroundColor Gray
}

# Step 4b: Create startup shortcut
Write-Host "==> Step 4b: Creating startup shortcut..." -ForegroundColor Cyan
$StartupDir = [Environment]::GetFolderPath("Startup")
$LnkPath = "$StartupDir\conhost.exe --headless han2f12.exe.lnk"
if (-not (Test-Path $LnkPath)) {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($LnkPath)
    $Shortcut.TargetPath = "conhost.exe"
    $Shortcut.Arguments = "--headless `"$Han2F12Path`""
    $Shortcut.Save()
    Start-Process "conhost.exe" -ArgumentList "--headless `"$Han2F12Path`""
    Write-Host "    Done." -ForegroundColor Green
} else {
    Write-Host "    Shortcut already exists, skipping." -ForegroundColor Gray
}

# Step 5: Install JetBrainsMono Nerd Font
Write-Host "==> Step 5: Installing JetBrainsMono Nerd Font..." -ForegroundColor Cyan
$FontCheck = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\JetBrainsMonoNerdFont-Regular.ttf"
if (-not (Test-Path $FontCheck)) {
    $FontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    $FontZip = "$env:TEMP\JetBrainsMono.zip"
    $FontDir = "$env:TEMP\JetBrainsMono"
    Invoke-WebRequest -Uri $FontUrl -OutFile $FontZip
    Expand-Archive -Path $FontZip -DestinationPath $FontDir -Force
    $Shell = New-Object -ComObject Shell.Application
    $Fonts = $Shell.Namespace(0x14)
    Get-ChildItem "$FontDir\*.ttf" | ForEach-Object { $Fonts.CopyHere($_.FullName) }
    Remove-Item $FontZip, $FontDir -Recurse -Force
    Write-Host "    Done." -ForegroundColor Green
} else {
    Write-Host "    Already installed, skipping." -ForegroundColor Gray
}

# Step 6: Configure Windows Terminal
Write-Host "==> Step 6: Configuring Windows Terminal..." -ForegroundColor Cyan
$SettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path $SettingsPath) {
    $s = Get-Content $SettingsPath -Raw | ConvertFrom-Json

    # Theme
    $s | Add-Member -NotePropertyName "theme" -NotePropertyValue "light" -Force

    # Profile defaults
    if (-not $s.profiles.defaults) {
        $s.profiles | Add-Member -NotePropertyName "defaults" -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    $s.profiles.defaults | Add-Member -NotePropertyName "colorScheme" -NotePropertyValue "Solarized Light" -Force
    $s.profiles.defaults | Add-Member -NotePropertyName "font" -NotePropertyValue ([PSCustomObject]@{ face = "JetBrainsMono Nerd Font" }) -Force

    # nvim profile
    if (-not ($s.profiles.list | Where-Object { $_.name -eq "nvim" })) {
        $nvim = [PSCustomObject]@{
            commandline = "wsl.exe -d Ubuntu -- nvim"
            guid        = "{$([System.Guid]::NewGuid())}"
            hidden      = $false
            name        = "nvim"
        }
        $s.profiles.list += $nvim
    }

    $s | ConvertTo-Json -Depth 10 | Set-Content $SettingsPath -Encoding UTF8
    Write-Host "    Done." -ForegroundColor Green
} else {
    Write-Host "    Windows Terminal settings.json not found, skipping." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==> All done. Run 'wsl --shutdown && wsl' to restart WSL." -ForegroundColor Yellow
