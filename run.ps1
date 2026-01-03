# Snake Game - Build and Run Script
# Copies files to DOSBox-X and launches the emulator

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$dosboxDir = Join-Path $scriptDir "DOSBox-X"
$driveD = Join-Path $dosboxDir "drived"

# Copy source files to DOSBox-X drive
Write-Host "Copying files to DOSBox-X..." -ForegroundColor Cyan
Copy-Item (Join-Path $scriptDir "SNAKE.ASM") -Destination $driveD -Force
Copy-Item (Join-Path $scriptDir "BUILD.BAT") -Destination $driveD -Force

# Find DOSBox-X executable
$dosboxExe = Get-ChildItem -Path $dosboxDir -Filter "dosbox-x.exe" -Recurse | Select-Object -First 1

if (-not $dosboxExe) {
    Write-Host "ERROR: dosbox-x.exe not found in $dosboxDir" -ForegroundColor Red
    exit 1
}

Write-Host "Launching DOSBox-X..." -ForegroundColor Green
Write-Host "Once inside, run: BUILD.BAT && SNAKE.EXE" -ForegroundColor Yellow

# Launch DOSBox-X
Start-Process -FilePath $dosboxExe.FullName -WorkingDirectory $dosboxDir
