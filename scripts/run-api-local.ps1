$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$envPath = Join-Path $root ".env"

if (-not (Test-Path $envPath)) {
    throw "Missing root .env file. Copy .env.example to .env and configure DATABASE_URL, DATABASE_USERNAME, DATABASE_PASSWORD and GOOGLE_OAUTH_ALLOWED_CLIENT_IDS."
}

$requiredKeys = @('DATABASE_URL', 'DATABASE_USERNAME', 'DATABASE_PASSWORD')
$allowedKeys = $requiredKeys + 'GOOGLE_OAUTH_ALLOWED_CLIENT_IDS'
$settings = @{}

Get-Content -LiteralPath $envPath -Encoding UTF8 | ForEach-Object {
    $line = $_.Trim()
    if ($line.Length -eq 0 -or $line.StartsWith("#")) {
        return
    }

    $separator = $line.IndexOf("=")
    if ($separator -lt 1) {
        return
    }

    $key = $line.Substring(0, $separator).Trim()
    if ($key -notin $allowedKeys) {
        return
    }

    $value = $line.Substring($separator + 1).Trim()
    if ($value.StartsWith('"') -or $value.StartsWith("'")) {
        # Remove one matching quote pair; preserve literal $, # and = characters.
        $quote = [regex]::Escape($value.Substring(0, 1))
        if ($value -notmatch "^$quote(.*?)$quote\s*(?:#.*)?$") {
            throw "Invalid quoted value for $key in root .env. Check matching quotes and any trailing comment."
        }
        $value = $matches[1]
    } else {
        # An unquoted inline comment starts at # preceded by whitespace.
        $value = ($value -replace '(^|\s+)#.*$', '').Trim()
    }

    $settings[$key] = $value
}

foreach ($key in $requiredKeys) {
    if (-not $settings.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($settings[$key])) {
        throw "Required setting $key is missing or empty in root .env."
    }
}

# Keep support for Google configuration already supplied through the environment.
if ($settings.ContainsKey('GOOGLE_OAUTH_ALLOWED_CLIENT_IDS')) {
    $env:GOOGLE_OAUTH_ALLOWED_CLIENT_IDS = $settings['GOOGLE_OAUTH_ALLOWED_CLIENT_IDS']
}
if ([string]::IsNullOrWhiteSpace($env:GOOGLE_OAUTH_ALLOWED_CLIENT_IDS)) {
    throw "GOOGLE_OAUTH_ALLOWED_CLIENT_IDS is missing in .env."
}

foreach ($key in $requiredKeys) {
    [Environment]::SetEnvironmentVariable($key, $settings[$key], 'Process')
}

Set-Location (Join-Path $root "apps/api")
.\mvnw.cmd spring-boot:run
