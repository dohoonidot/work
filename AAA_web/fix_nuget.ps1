# NuGet 설치 및 PATH 추가 스크립트
# 관리자 권한으로 실행 필요

Write-Host "=== NuGet 설치 스크립트 ===" -ForegroundColor Cyan
Write-Host ""

# 관리자 권한 확인
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "❌ 이 스크립트는 관리자 권한이 필요합니다." -ForegroundColor Red
    Write-Host "PowerShell을 관리자 권한으로 다시 실행해주세요." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. PowerShell 아이콘을 우클릭" -ForegroundColor White
    Write-Host "2. '관리자 권한으로 실행' 선택" -ForegroundColor White
    Write-Host "3. 다시 이 스크립트 실행: .\fix_nuget.ps1" -ForegroundColor White
    pause
    exit 1
}

Write-Host "✅ 관리자 권한 확인 완료" -ForegroundColor Green
Write-Host ""

# 1. NuGet 디렉토리 생성
$nugetDir = "C:\nuget"
Write-Host "[1/4] NuGet 디렉토리 생성: $nugetDir" -ForegroundColor Yellow

if (-not (Test-Path $nugetDir)) {
    New-Item -ItemType Directory -Path $nugetDir -Force | Out-Null
    Write-Host "      ✓ 디렉토리 생성 완료" -ForegroundColor Green
} else {
    Write-Host "      ✓ 디렉토리가 이미 존재함" -ForegroundColor Green
}
Write-Host ""

# 2. NuGet.exe 다운로드
$nugetExePath = "$nugetDir\nuget.exe"
Write-Host "[2/4] NuGet.exe 다운로드" -ForegroundColor Yellow

if (Test-Path $nugetExePath) {
    Write-Host "      NuGet이 이미 설치되어 있습니다. 업데이트하시겠습니까? (Y/N)" -ForegroundColor Cyan
    $update = Read-Host
    if ($update -ne "Y" -and $update -ne "y") {
        Write-Host "      ✓ 기존 NuGet 유지" -ForegroundColor Green
    } else {
        try {
            Write-Host "      다운로드 중..." -ForegroundColor White
            Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile $nugetExePath
            Write-Host "      ✓ NuGet 업데이트 완료" -ForegroundColor Green
        } catch {
            Write-Host "      ❌ 다운로드 실패: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
} else {
    try {
        Write-Host "      다운로드 중..." -ForegroundColor White
        Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile $nugetExePath
        Write-Host "      ✓ NuGet 다운로드 완료" -ForegroundColor Green
    } catch {
        Write-Host "      ❌ 다운로드 실패: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# 3. PATH 환경변수에 추가
Write-Host "[3/4] 시스템 PATH에 NuGet 추가" -ForegroundColor Yellow

$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")

if ($machinePath -like "*$nugetDir*") {
    Write-Host "      ✓ NuGet이 이미 PATH에 등록되어 있음" -ForegroundColor Green
} else {
    try {
        [Environment]::SetEnvironmentVariable("Path", "$machinePath;$nugetDir", "Machine")
        Write-Host "      ✓ PATH에 추가 완료" -ForegroundColor Green
    } catch {
        Write-Host "      ❌ PATH 추가 실패: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# 4. 설치 확인
Write-Host "[4/4] NuGet 설치 확인" -ForegroundColor Yellow

# PATH 새로고침
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

try {
    $nugetVersion = & $nugetExePath help | Select-Object -First 1
    Write-Host "      ✓ NuGet 설치 성공: $nugetVersion" -ForegroundColor Green
} catch {
    Write-Host "      ❌ NuGet 실행 실패" -ForegroundColor Red
    exit 1
}
Write-Host ""

# 완료
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "✅ NuGet 설치가 완료되었습니다!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "다음 단계:" -ForegroundColor Yellow
Write-Host "1. 현재 터미널/PowerShell을 모두 닫기" -ForegroundColor White
Write-Host "2. 새로운 터미널을 열기" -ForegroundColor White
Write-Host "3. Flutter 프로젝트 정리 및 재실행:" -ForegroundColor White
Write-Host "   cd '$PSScriptRoot'" -ForegroundColor Cyan
Write-Host "   flutter clean" -ForegroundColor Cyan
Write-Host "   flutter pub get" -ForegroundColor Cyan
Write-Host "   flutter run -d windows" -ForegroundColor Cyan
Write-Host ""

pause
