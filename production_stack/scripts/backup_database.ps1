# 导出数据库便于上传到服务器。
# 当前项目开发环境常用 SQLite（backend/medapp.db）；Docker 栈为 MySQL 8.4。
param(
    [ValidateSet("sqlite", "mysql-docker")]
    [string]$Mode = "sqlite",
    [string]$BackendRoot = (Resolve-Path "$PSScriptRoot\..\backend").Path,
    [string]$OutDir = (Resolve-Path "$PSScriptRoot\..\backups").Path,
    [string]$ComposeDir = (Resolve-Path "$PSScriptRoot\..").Path
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"

if ($Mode -eq "sqlite") {
    $db = Join-Path $BackendRoot "medapp.db"
    if (-not (Test-Path -LiteralPath $db)) {
        Write-Error "未找到 $db ，请确认 .env 中 MYSQL_DSN 为 sqlite 且已建库。"
    }
    $copy = Join-Path $OutDir "medapp_$stamp.db"
    Copy-Item -LiteralPath $db -Destination $copy -Force
    $zip = Join-Path $OutDir "medapp_sqlite_$stamp.zip"
    Compress-Archive -LiteralPath $copy -DestinationPath $zip -Force
    Remove-Item $copy -Force
    Write-Host "已生成: $zip"
    exit 0
}

# MySQL（需在 production_stack 目录已 docker compose up，且容器名含 mysql）
Set-Location $ComposeDir
$sql = Join-Path $OutDir "medapp_mysql_$stamp.sql"
docker compose exec -T mysql mysqldump -umedapp -pmedapp_pwd --single-transaction --routines --triggers medapp | Set-Content -Encoding utf8 $sql
if ($LASTEXITCODE -ne 0) { Write-Error "mysqldump 失败，请确认 Docker 已启动且 mysql 服务正常。" }
Compress-Archive -LiteralPath $sql -DestinationPath "$sql.zip" -Force
Remove-Item $sql -Force
Write-Host "已生成: $sql.zip"
