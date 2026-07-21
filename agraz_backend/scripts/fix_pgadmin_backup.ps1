# Fix pgAdmin backup: point pg_dump to PostgreSQL 17 bin (not pgAdmin runtime).
# Close pgAdmin before running.

$ErrorActionPreference = 'Stop'
$pgAdminDb = Join-Path $env:APPDATA 'pgAdmin\pgadmin4.db'
$pgBin = 'C:\Program Files\PostgreSQL\17\bin'

if (-not (Test-Path "$pgBin\pg_dump.exe")) {
    Write-Error "pg_dump not found at $pgBin. Install PostgreSQL 17 client tools on Windows."
}

$running = Get-Process -Name 'pgAdmin4' -ErrorAction SilentlyContinue
if ($running) {
    Write-Host 'Closing pgAdmin...'
    $running | Stop-Process -Force
    Start-Sleep -Seconds 2
}

if (-not (Test-Path $pgAdminDb)) {
    Write-Error "pgAdmin config not found: $pgAdminDb"
}

$backup = "$pgAdminDb.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item $pgAdminDb $backup
Write-Host "Backed up config to $backup"

Add-Type -AssemblyName System.Data
$conn = New-Object System.Data.SQLite.SQLiteConnection
# Use sqlite3 via cmd if System.Data.SQLite unavailable
$json = @'
[{"version":"130000","next_major_version":"140000","serverType":"PostgreSQL 13","binaryPath":"BIN","isDefault":false,"cid":"nn43"},{"version":"140000","next_major_version":"150000","serverType":"PostgreSQL 14","binaryPath":"BIN","isDefault":true,"cid":"nn44"},{"version":"150000","next_major_version":"160000","serverType":"PostgreSQL 15","binaryPath":"BIN","isDefault":false,"cid":"nn45"},{"version":"160000","next_major_version":"170000","serverType":"PostgreSQL 16","binaryPath":"BIN","isDefault":false,"cid":"nn46"},{"version":"170000","next_major_version":"180000","serverType":"PostgreSQL 17","binaryPath":"BIN","isDefault":false,"isFixed":false}]
'@ -replace 'BIN', ($pgBin -replace '\\', '\\')

$sqlite = Get-Command sqlite3 -ErrorAction SilentlyContinue
if (-not $sqlite) {
    Write-Error 'sqlite3 not in PATH. Run from WSL: ./scripts/fix_pgadmin_backup.sh'
}

$escaped = $json.Replace("'", "''")
& sqlite3 $pgAdminDb "UPDATE user_preferences SET value='$escaped' WHERE pid=(SELECT id FROM preferences WHERE name='pg_bin_dir');"
& sqlite3 $pgAdminDb "UPDATE server SET host='127.0.0.1' WHERE host='localhost';"

Write-Host 'Done. Open pgAdmin and run Backup (Plain) to a path like:'
Write-Host '  C:\Users\tss\Desktop\agraz_backup.sql'
