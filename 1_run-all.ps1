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

Write-Host ""
Write-Host "==> All done. Run 'wsl --shutdown && wsl' to restart WSL." -ForegroundColor Yellow
