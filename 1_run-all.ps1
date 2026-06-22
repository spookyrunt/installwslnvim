# Master setup script - run as Administrator in PowerShell
# Runs all steps in order: WSL install, nvim setup, registry import

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "ScriptDir: [$ScriptDir]"

# Step 1: WSL + Ubuntu
Write-Host "==> Step 1: WSL and Ubuntu setup" -ForegroundColor Cyan
$WslDir = Read-Host "    Where should WSL be stored? [D:\WSL]"
if (-not $WslDir) { $WslDir = "D:\WSL" }
New-Item -ItemType Directory -Force -Path $WslDir | Out-Null

$ImportExisting = Read-Host "    Import an existing WSL backup? (y/N)"
if ($ImportExisting -eq "y" -or $ImportExisting -eq "Y") {
    $BackupPath = Read-Host "    Path to backup file (.tar or .vhdx)"
    if ($BackupPath -match '\.vhdx$') {
        Write-Host "    Registering vhdx in $WslDir..." -ForegroundColor Cyan
        Copy-Item $BackupPath "$WslDir\ext4.vhdx" -ErrorAction SilentlyContinue
        wsl --import-in-place Ubuntu "$WslDir\ext4.vhdx"
    } else {
        Write-Host "    Importing tar into $WslDir..." -ForegroundColor Cyan
        wsl --import Ubuntu $WslDir $BackupPath
    }
    Write-Host "    Done." -ForegroundColor Green
} else {
    Write-Host "    Installing WSL and Ubuntu..." -ForegroundColor Cyan
    Write-Host "    Type exit after setting up Ubuntu"
    wsl --install -d Ubuntu
    Write-Host "    Migrating to $WslDir..." -ForegroundColor Cyan
    wsl --export Ubuntu "$WslDir\ubuntu-backup.tar"
    wsl --unregister Ubuntu
    wsl --import Ubuntu $WslDir "$WslDir\ubuntu-backup.tar"
    Remove-Item "$WslDir\ubuntu-backup.tar"
    # kill race condition
    wsl --shutdown
    Start-Sleep -Seconds 3
    wsl -d Ubuntu true 
    Write-Host "    Done." -ForegroundColor Green
}

# Step 2: nvim setup inside WSL
Write-Host "==> Step 2: Running nvim setup in WSL..." -ForegroundColor Cyan
$WinPath = Join-Path $ScriptDir "2_nvim-setup.sh"
$Drive = $WinPath[0].ToString().ToLower()
$BashScript = "/mnt/$Drive/" + $WinPath.Substring(3).Replace("\", "/")
Write-Host "BashScript: [$BashScript]"
wsl -d Ubuntu bash $BashScript
if ($LASTEXITCODE -ne 0) {
    Write-Host "    Failed (exit code: $LASTEXITCODE)" -ForegroundColor Red
} else {
    Write-Host "    Done." -ForegroundColor Green
}

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

    # Configure Ubuntu profile
    $ExistingUbuntu = $s.profiles.list | Where-Object { $_.name -eq "Ubuntu" }
    if ($null -ne $ExistingUbuntu) {
      # Update target properties while keeping the auto-detection feature intact
      $ExistingUbuntu.hidden = $false
      $ExistingUbuntu.commandline = "wsl.exe -d Ubuntu"
      $ExistingUbuntu.name = "Ubuntu"
    } else {
      # Create a new profile if it does not exist
      $NewUbuntu = [PSCustomObject]@{
        commandline = "wsl.exe -d Ubuntu"
          guid        = "{$([System.Guid]::NewGuid())}"
          hidden      = $false
          name        = "Ubuntu"
      }
      $s.profiles.list += $NewUbuntu
    }

    $s | ConvertTo-Json -Depth 10 | Set-Content $SettingsPath -Encoding UTF8
      Write-Host "    Done." -ForegroundColor Green
} else {
  Write-Host "    Windows Terminal settings.json not found, skipping." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==> All done." -ForegroundColor Yellow

