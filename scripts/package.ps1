# Ponta DevStack Packaging Script
# This script builds the Flutter app and creates an Inno Setup installer.

$ProjectRoot = Get-Location
$InnoSetupScript = Join-Path $ProjectRoot "innosetup\installer.iss"
$BuildDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"

Write-Host "--- 1. Building Flutter Windows App (Release) ---" -ForegroundColor Cyan
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Flutter build failed." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "--- 2. Verifying Build Output ---" -ForegroundColor Cyan
if (-not (Test-Path $BuildDir)) {
    Write-Host "Error: Build directory not found at $BuildDir" -ForegroundColor Red
    exit 1
}

Write-Host "--- 3. Compiling Installer with Inno Setup ---" -ForegroundColor Cyan

# Try to find ISCC.exe
$InnoPaths = @(
    "${env:ProgramFiles(x86)}\Inno Setup 7\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 7\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 7\ISCC.exe",
    "C:\Program Files\Inno Setup 7\ISCC.exe",
    "C:\Users\${env:UserName}\AppData\Local\Programs\Inno Setup 7\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "C:\Users\${env:UserName}\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
)

$ISCC = $null
foreach ($path in $InnoPaths) {
    if (Test-Path $path) {
        $ISCC = $path
        break
    }
}

if ($null -eq $ISCC) {
    Write-Host "Error: Inno Setup Compiler (ISCC.exe) not found." -ForegroundColor Yellow
    Write-Host "Please install Inno Setup 6/7 or add ISCC.exe to your PATH." -ForegroundColor White
    Write-Host "You can download it from: https://jrsoftware.org/isdl.php" -ForegroundColor White
    exit 1
}

Write-Host "Using ISCC at: $ISCC" -ForegroundColor Gray
& $ISCC $InnoSetupScript

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Inno Setup compilation failed." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "--- Packaging Complete! ---" -ForegroundColor Green
Write-Host "Installer created in: $(Join-Path $ProjectRoot "innosetup\Output")" -ForegroundColor White
