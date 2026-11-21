@echo off
chcp 65001 >nul
cd /d "%~dp0"

rem ===== 설정 (필요하면 고치세요) =====
set "TARGET_BRANCH=claude/tender-gauss-i4mq1o"
rem Godot 실행 파일 경로를 적으면 업데이트 후 프로젝트를 바로 엽니다. 예: set "GODOT_EXE=C:\Godot\Godot_v4.7-stable_win64.exe"
set "GODOT_EXE="
rem ====================================

echo ============================================
echo   TRG 최신 버전으로 업데이트합니다
echo ============================================

where git >nul 2>nul
if errorlevel 1 goto NOGIT

git fetch origin
if errorlevel 1 goto FAILED

git checkout %TARGET_BRANCH%
if errorlevel 1 goto DIRTY

git pull --ff-only origin %TARGET_BRANCH%
if errorlevel 1 goto DIRTY

echo.
echo 업데이트 완료! 현재 버전:
git log -1 --format="  %h  %s  [%cd]" --date=format:"%%Y-%%m-%%d %%H:%%M"

if not "%GODOT_EXE%"=="" (
  echo Godot를 실행합니다...
  start "" "%GODOT_EXE%" --editor --path "%~dp0"
)
echo.
pause
exit /b 0

:NOGIT
echo [오류] Git이 설치되어 있지 않습니다. https://git-scm.com 에서 설치한 뒤 다시 실행하세요.
pause
exit /b 1

:DIRTY
echo.
echo [안내] 업데이트하지 못했습니다. 이 폴더의 파일을 직접 수정했거나 다른 브랜치에 있을 수 있습니다.
echo        직접 고친 파일이 없다면 아래 명령으로 강제로 맞출 수 있습니다:
echo          git reset --hard origin/%TARGET_BRANCH%
pause
exit /b 1

:FAILED
echo [오류] 서버에서 최신 내용을 가져오지 못했습니다. 인터넷 연결을 확인하세요.
pause
exit /b 1
