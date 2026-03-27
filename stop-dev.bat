@echo off
setlocal EnableDelayedExpansion
set "KILLED=0"
set "SEEN_PIDS= "
set "STOP_DB=0"
if /i "%~1"=="--db" set "STOP_DB=1"
if /i "%~1"=="db" set "STOP_DB=1"

for %%P in (8000 5173) do (
  for /f "tokens=5" %%A in ('netstat -ano ^| findstr /R /C:":%%P .*LISTENING"') do (
    set "PID=%%A"
    echo !SEEN_PIDS! | find " !PID! " >nul
    if errorlevel 1 (
      set "SEEN_PIDS=!SEEN_PIDS!!PID! "
      taskkill /F /T /PID !PID! >nul 2>&1
      if not errorlevel 1 (
        echo Stopped port %%P process PID !PID!
        set /a KILLED+=1
      )
    )
  )
)

for %%T in ("Backend - AI Project" "Frontend - AI Project") do (
  taskkill /F /T /FI "WINDOWTITLE eq %%~T*" >nul 2>&1
  if not errorlevel 1 (
    echo Stopped window %%~T
    set /a KILLED+=1
  )
)

where powershell.exe >nul 2>&1
if not errorlevel 1 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$patterns=@('uvicorn app.main:app','vite --host','vite --port 5173','npm run dev'); $k=0; foreach($p in $patterns){ Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like ('*'+$p+'*') } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop; $k++ } catch {} } }; if($k -gt 0){ Write-Host ('Stopped '+$k+' process(es) by command line.') }" >nul 2>&1
)

if "!STOP_DB!"=="1" (
  where docker.exe >nul 2>&1
  if not errorlevel 1 (
    docker info >nul 2>&1
    if not errorlevel 1 (
      docker rm -f ai-test-platform-postgres >nul 2>&1
      if not errorlevel 1 (
        echo Stopped postgres container ai-test-platform-postgres
        set /a KILLED+=1
      )
    )
  )
)

if "!KILLED!"=="0" (
  echo No dev process found on ports 8000 or 5173.
) else (
  echo Stopped !KILLED! process^(es^).
)

endlocal
