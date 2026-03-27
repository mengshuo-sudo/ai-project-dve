@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "ROOT=%~dp0"
set "BACKEND=%ROOT%ai-project-back-end"
set "FRONTEND=%ROOT%ai-project_front_end"
set "START_MODE=windows"
set "PAUSE_AT_END=0"
set "SKIP_DB=0"
set "DB_PORT=5433"

if /i "%~1"=="--inline" set "START_MODE=inline"
if /i "%~1"=="inline" set "START_MODE=inline"
if /i "%~1"=="--windows" set "START_MODE=windows"
if /i "%~1"=="windows" set "START_MODE=windows"
if /i "%~1"=="--pause" set "PAUSE_AT_END=1"
if /i "%~1"=="pause" set "PAUSE_AT_END=1"
if /i "%~1"=="--no-db" set "SKIP_DB=1"
if /i "%~1"=="no-db" set "SKIP_DB=1"

if not exist "%BACKEND%\" goto :backend_missing

if not exist "%FRONTEND%\" goto :frontend_missing

if exist "%ROOT%stop-dev.bat" call "%ROOT%stop-dev.bat" >nul 2>&1

pushd "%BACKEND%"
if not exist ".venv\Scripts\python.exe" (
  echo Creating backend virtual environment...
  py -3.13 -m venv .venv 2>nul || py -m venv .venv 2>nul || python -m venv .venv
)

echo Installing backend dependencies...
".venv\Scripts\python.exe" -m pip install -U pip setuptools wheel >nul 2>&1
".venv\Scripts\python.exe" -m pip install -r requirements.txt

set "DB_READY=0"
if "!SKIP_DB!"=="0" (
  call :ensure_postgres
  if "!DB_READY!"=="1" (
    echo Running database migrations...
    ".venv\Scripts\python.exe" -m alembic upgrade head
  ) else (
    echo Database not detected on port !DB_PORT!. Skipping migrations.
  )
)
popd

pushd "%FRONTEND%"
if not exist "node_modules\" (
  echo Installing frontend dependencies...
  npm install
)
popd

if /i "!START_MODE!"=="inline" (
  start "" /b cmd /c "cd /d ""%BACKEND%"" && set ""ENV=local"" && .venv\Scripts\python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"
  start "" /b cmd /c "cd /d ""%FRONTEND%"" && npm run dev -- --host 0.0.0.0 --port 5173"
) else (
  start "Backend - AI Project" cmd /k "cd /d ""%BACKEND%"" && set ""ENV=local"" && if exist "".venv\Scripts\activate.bat"" (call "".venv\Scripts\activate.bat"") && .venv\Scripts\python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"
  start "Frontend - AI Project" cmd /k "cd /d ""%FRONTEND%"" && npm run dev -- --host 0.0.0.0 --port 5173"
)

echo Backend and frontend started.
echo Backend: http://127.0.0.1:8000
echo Frontend: http://127.0.0.1:5173

if "!PAUSE_AT_END!"=="1" (
  echo.
  pause
)
endlocal
exit /b 0

:backend_missing
echo Backend directory not found: %BACKEND%
endlocal
exit /b 1

:frontend_missing
echo Frontend directory not found: %FRONTEND%
endlocal
exit /b 1

:ensure_postgres
where docker.exe >nul 2>&1
if errorlevel 1 goto :check_port
docker info >nul 2>&1
if errorlevel 1 goto :check_port

set "HAS_CONTAINER="
for /f "delims=" %%N in ('docker ps -a --format "{{.Names}}" ^| findstr /i /x "ai-test-platform-postgres"') do set "HAS_CONTAINER=1"
if defined HAS_CONTAINER (
  docker start ai-test-platform-postgres >nul 2>&1
) else (
  docker run -d --name ai-test-platform-postgres -e POSTGRES_PASSWORD=123456 -e POSTGRES_DB=ai_test_platform -p !DB_PORT!:5432 postgres:16 >nul 2>&1
)

for /l %%i in (1,1,60) do (
  docker exec ai-test-platform-postgres pg_isready -U postgres >nul 2>&1 && (set "DB_READY=1" & goto :eof)
  timeout /t 1 >nul
)
goto :eof

:check_port
for /f "tokens=5" %%A in ('netstat -ano ^| findstr /R /C:":!DB_PORT! .*LISTENING"') do set "DB_READY=1"
goto :eof
