# Claude-GLM PowerShell Installer for Windows
# Works without admin rights, installs to user's profile directory
#
# Usage with parameters when downloading:
#   Test error reporting:
#     $env:CLAUDE_GLM_TEST_ERROR=1; iwr -useb https://raw.githubusercontent.com/JoeInnsp23/claude-glm-wrapper/main/install.ps1 | iex; $env:CLAUDE_GLM_TEST_ERROR=$null
#
#   Enable debug mode:
#     $env:CLAUDE_GLM_DEBUG=1; iwr -useb https://raw.githubusercontent.com/JoeInnsp23/claude-glm-wrapper/main/install.ps1 | iex; $env:CLAUDE_GLM_DEBUG=$null
#
# Usage when running locally:
#   .\install.ps1 -TestError
#   .\install.ps1 -Debug

param(
    [switch]$TestError,
    [switch]$Debug
)

# Support environment variables for parameters when using iwr | iex
if ($env:CLAUDE_GLM_TEST_ERROR -eq "1" -or $env:CLAUDE_GLM_TEST_ERROR -eq "true") {
    $TestError = $true
}
if ($env:CLAUDE_GLM_DEBUG -eq "1" -or $env:CLAUDE_GLM_DEBUG -eq "true") {
    $Debug = $true
}

# Configuration
$UserBinDir = "$env:USERPROFILE\.local\bin"
$GlmConfigDir = "$env:USERPROFILE\.claude-glm"
$Glm45ConfigDir = "$env:USERPROFILE\.claude-glm-45"
$GlmFastConfigDir = "$env:USERPROFILE\.claude-glm-fast"
$ZaiApiKey = "YOUR_ZAI_API_KEY_HERE"

# Debug logging
function Write-DebugLog {
    param([string]$Message)
    if ($Debug) {
        Write-Host "DEBUG: $Message" -ForegroundColor Gray
    }
}

# Find all existing wrapper installations
function Find-AllInstallations {
    Write-DebugLog "Searching for existing installations..."
    $locations = @(
        "$env:USERPROFILE\.local\bin",
        "$env:ProgramFiles\Claude-GLM",
        "$env:LOCALAPPDATA\Programs\claude-glm",
        "C:\Program Files\Claude-GLM"
    )

    $foundFiles = @()

    foreach ($location in $locations) {
        Write-DebugLog "Checking location: $location"
        if (Test-Path $location) {
            # Find all claude-glm*.ps1 files in this location
            try {
                $files = Get-ChildItem -Path $location -Filter "claude-glm*.ps1" -ErrorAction Stop
                foreach ($file in $files) {
                    Write-DebugLog "Found: $($file.FullName)"
                    $foundFiles += $file.FullName
                }
            } catch {
                Write-DebugLog "Could not access $location : $_"
                # Continue searching other locations
            }
        }
    }

    Write-DebugLog "Total installations found: $($foundFiles.Count)"
    return $foundFiles
}

# Clean up old wrapper installations
function Remove-OldWrappers {
    $currentLocation = $UserBinDir
    $allWrappers = Find-AllInstallations

    if ($allWrappers.Count -eq 0) {
        return
    }

    # Separate current location files from old ones
    $oldWrappers = @()
    $currentWrappers = @()

    foreach ($wrapper in $allWrappers) {
        if ($wrapper -like "$currentLocation*") {
            $currentWrappers += $wrapper
        } else {
            $oldWrappers += $wrapper
        }
    }

    # If no old wrappers found, nothing to clean
    if ($oldWrappers.Count -eq 0) {
        return
    }

    Write-Host ""
    Write-Host "SEARCH: Found existing wrappers in multiple locations:"
    Write-Host ""

    foreach ($wrapper in $oldWrappers) {
        Write-Host "  REMOVED: $wrapper (old location)"
    }

    if ($currentWrappers.Count -gt 0) {
        foreach ($wrapper in $currentWrappers) {
            Write-Host "  OK: $wrapper (current location)"
        }
    }

    Write-Host ""
    $cleanupChoice = Read-Host "Would you like to clean up old installations? (y/n)"

    if ($cleanupChoice -eq "y" -or $cleanupChoice -eq "Y") {
        Write-Host ""
        Write-Host "Removing old wrappers..."
        foreach ($wrapper in $oldWrappers) {
            try {
                Remove-Item -Path $wrapper -Force -ErrorAction Stop
                Write-Host "  OK: Removed: $wrapper"
            } catch {
                Write-Host "  WARNING: Could not remove: $wrapper (permission denied)"
            }
        }
        Write-Host ""
        Write-Host "OK: Cleanup complete!"
    } else {
        Write-Host ""
        Write-Host "WARNING: Skipping cleanup. Old wrappers may interfere with the new installation."
        Write-Host "   You may want to manually remove them later."
    }

    Write-Host ""
}

# Setup user bin directory and add to PATH
function Setup-UserBin {
    # Create user bin directory
    if (-not (Test-Path $UserBinDir)) {
        New-Item -ItemType Directory -Path $UserBinDir -Force | Out-Null
    }

    # Check if PATH includes user bin
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -notlike "*$UserBinDir*") {
        Write-Host "INFO: Adding $UserBinDir to PATH..."

        # Add to user PATH
        $newPath = if ($currentPath) { "$currentPath;$UserBinDir" } else { $UserBinDir }
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")

        # Update current session PATH
        $env:PATH = "$env:PATH;$UserBinDir"

        Write-Host ""
        Write-Host "WARNING: IMPORTANT: PATH has been updated for future sessions."
        Write-Host "   For this session, restart PowerShell or run: `$env:PATH += ';$UserBinDir'"
        Write-Host ""
    }
}

# Add aliases to PowerShell profile
function Add-PowerShellAliases {
    # Ensure profile exists
    if (-not (Test-Path $PROFILE)) {
        $profileDir = Split-Path $PROFILE
        if (-not (Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }

    # Read current profile
    $profileContent = @()
    if (Test-Path $PROFILE) {
        try {
            $profileContent = Get-Content $PROFILE -ErrorAction Stop
            Write-DebugLog "Read existing profile with $($profileContent.Count) lines"
        } catch {
            Write-DebugLog "Could not read profile: $_"
            $profileContent = @()
        }
    }

    # Remove old aliases if they exist
    $filteredContent = $profileContent | Where-Object {
        $_ -notmatch "# Claude Code Model Switcher Aliases" -and
        $_ -notmatch "Set-Alias cc " -and
        $_ -notmatch "Set-Alias ccg " -and
        $_ -notmatch "Set-Alias ccg45 " -and
        $_ -notmatch "Set-Alias ccf "
    }

    # Add new aliases
    $aliases = @"

# Claude Code Model Switcher Aliases
Set-Alias cc claude
Set-Alias ccg claude-glm
Set-Alias ccg45 claude-glm-4.5
Set-Alias ccf claude-glm-fast
"@

    $newContent = $filteredContent + $aliases
    Set-Content -Path $PROFILE -Value $newContent

    Write-Host "OK: Added aliases to PowerShell profile: $PROFILE"
}

# Create the GLM-4.6 wrapper
function New-ClaudeGlmWrapper {
    $wrapperPath = Join-Path $UserBinDir "claude-glm.ps1"

    # Build wrapper content using array and join to avoid nested here-strings
    $wrapperContent = @(
        '# Claude-GLM - Claude Code with Z.AI GLM-4.6 (Standard Model)',
        '',
        '# Set Z.AI environment variables',
        '$env:ANTHROPIC_BASE_URL = "https://api.z.ai/api/anthropic"',
        "`$env:ANTHROPIC_AUTH_TOKEN = `"$ZaiApiKey`"",
        '$env:ANTHROPIC_MODEL = "glm-4.6"',
        '$env:ANTHROPIC_SMALL_FAST_MODEL = "glm-4.5-air"',
        '',
        '# Use custom config directory to avoid conflicts',
        "`$env:CLAUDE_HOME = `"$GlmConfigDir`"",
        '',
        '# Create config directory if it doesn''t exist',
        'if (-not (Test-Path $env:CLAUDE_HOME)) {',
        '    New-Item -ItemType Directory -Path $env:CLAUDE_HOME -Force | Out-Null',
        '}',
        '',
        '# Create/update settings file with GLM configuration',
        '$settingsJson = "{`"env`":{`"ANTHROPIC_BASE_URL`":`"https://api.z.ai/api/anthropic`",`"ANTHROPIC_AUTH_TOKEN`":`"' + $ZaiApiKey + '`",`"ANTHROPIC_MODEL`":`"glm-4.6`",`"ANTHROPIC_SMALL_FAST_MODEL`":`"glm-4.5-air`"}}"',
        'Set-Content -Path (Join-Path $env:CLAUDE_HOME "settings.json") -Value $settingsJson',
        '',
        '# Launch Claude Code with custom config',
        'Write-Host "LAUNCH: Starting Claude Code with GLM-4.6 (Standard Model)..."',
        'Write-Host "CONFIG: Config directory: $env:CLAUDE_HOME"',
        'Write-Host ""',
        '',
        '# Check if claude exists',
        'if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {',
        '    Write-Host "ERROR: ''claude'' command not found!"',
        '    Write-Host "Please ensure Claude Code is installed and in your PATH"',
        '    exit 1',
        '}',
        '',
        '# Run the actual claude command',
        '& claude $args'
    ) -join "`n"

    Set-Content -Path $wrapperPath -Value $wrapperContent
    Write-Host "OK: Installed claude-glm at $wrapperPath" -ForegroundColor Green
}

# Create the GLM-4.5 wrapper
function New-ClaudeGlm45Wrapper {
    $wrapperPath = Join-Path $UserBinDir "claude-glm-4.5.ps1"

    # Build wrapper content using array and join to avoid nested here-strings
    $wrapperContent = @(
        '# Claude-GLM-4.5 - Claude Code with Z.AI GLM-4.5',
        '',
        '# Set Z.AI environment variables',
        '$env:ANTHROPIC_BASE_URL = "https://api.z.ai/api/anthropic"',
        "`$env:ANTHROPIC_AUTH_TOKEN = `"$ZaiApiKey`"",
        '$env:ANTHROPIC_MODEL = "glm-4.5"',
        '$env:ANTHROPIC_SMALL_FAST_MODEL = "glm-4.5-air"',
        '',
        '# Use custom config directory to avoid conflicts',
        "`$env:CLAUDE_HOME = `"$Glm45ConfigDir`"",
        '',
        '# Create config directory if it doesn''t exist',
        'if (-not (Test-Path $env:CLAUDE_HOME)) {',
        '    New-Item -ItemType Directory -Path $env:CLAUDE_HOME -Force | Out-Null',
        '}',
        '',
        '# Create/update settings file with GLM configuration',
        '$settingsJson = "{`"env`":{`"ANTHROPIC_BASE_URL`":`"https://api.z.ai/api/anthropic`",`"ANTHROPIC_AUTH_TOKEN`":`"' + $ZaiApiKey + '`",`"ANTHROPIC_MODEL`":`"glm-4.5`",`"ANTHROPIC_SMALL_FAST_MODEL`":`"glm-4.5-air`"}}"',
        'Set-Content -Path (Join-Path $env:CLAUDE_HOME "settings.json") -Value $settingsJson',
        '',
        '# Launch Claude Code with custom config',
        'Write-Host "LAUNCH: Starting Claude Code with GLM-4.5..."',
        'Write-Host "CONFIG: Config directory: $env:CLAUDE_HOME"',
        'Write-Host ""',
        '',
        '# Check if claude exists',
        'if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {',
        '    Write-Host "ERROR: ''claude'' command not found!"',
        '    Write-Host "Please ensure Claude Code is installed and in your PATH"',
        '    exit 1',
        '}',
        '',
        '# Run the actual claude command',
        '& claude $args'
    ) -join "`n"

    Set-Content -Path $wrapperPath -Value $wrapperContent
    Write-Host "OK: Installed claude-glm-4.5 at $wrapperPath" -ForegroundColor Green
}

# Create the fast GLM-4.5-Air wrapper
function New-ClaudeGlmFastWrapper {
    $wrapperPath = Join-Path $UserBinDir "claude-glm-fast.ps1"

    # Build wrapper content using array and join to avoid nested here-strings
    $wrapperContent = @(
        '# Claude-GLM-Fast - Claude Code with Z.AI GLM-4.5-Air (Fast Model)',
        '',
        '# Set Z.AI environment variables',
        '$env:ANTHROPIC_BASE_URL = "https://api.z.ai/api/anthropic"',
        "`$env:ANTHROPIC_AUTH_TOKEN = `"$ZaiApiKey`"",
        '$env:ANTHROPIC_MODEL = "glm-4.5-air"',
        '$env:ANTHROPIC_SMALL_FAST_MODEL = "glm-4.5-air"',
        '',
        '# Use custom config directory to avoid conflicts',
        "`$env:CLAUDE_HOME = `"$GlmFastConfigDir`"",
        '',
        '# Create config directory if it doesn''t exist',
        'if (-not (Test-Path $env:CLAUDE_HOME)) {',
        '    New-Item -ItemType Directory -Path $env:CLAUDE_HOME -Force | Out-Null',
        '}',
        '',
        '# Create/update settings file with GLM-Air configuration',
        '$settingsJson = "{`"env`":{`"ANTHROPIC_BASE_URL`":`"https://api.z.ai/api/anthropic`",`"ANTHROPIC_AUTH_TOKEN`":`"' + $ZaiApiKey + '`",`"ANTHROPIC_MODEL`":`"glm-4.5-air`",`"ANTHROPIC_SMALL_FAST_MODEL`":`"glm-4.5-air`"}}"',
        'Set-Content -Path (Join-Path $env:CLAUDE_HOME "settings.json") -Value $settingsJson',
        '',
        '# Launch Claude Code with custom config',
        'Write-Host "FAST: Starting Claude Code with GLM-4.5-Air (Fast Model)..."',
        'Write-Host "CONFIG: Config directory: $env:CLAUDE_HOME"',
        'Write-Host ""',
        '',
        '# Check if claude exists',
        'if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {',
        '    Write-Host "ERROR: ''claude'' command not found!"',
        '    Write-Host "Please ensure Claude Code is installed and in your PATH"',
        '    exit 1',
        '}',
        '',
        '# Run the actual claude command',
        '& claude $args'
    ) -join "`n"

    Set-Content -Path $wrapperPath -Value $wrapperContent
    Write-Host "OK: Installed claude-glm-fast at $wrapperPath" -ForegroundColor Green
}

# Check Claude Code availability
function Test-ClaudeInstallation {
    Write-Host "CHECKING: Claude Code installation..."

    if (Get-Command claude -ErrorAction SilentlyContinue) {
        $claudePath = (Get-Command claude).Source
        Write-Host "OK: Claude Code found at: $claudePath"
        return $true
    } else {
        Write-Host "WARNING: Claude Code not found in PATH"
        Write-Host ""
        Write-Host "Options:"
        Write-Host "1. If Claude Code is installed elsewhere, add it to PATH first"
        Write-Host "2. Install Claude Code from: https://www.anthropic.com/claude-code"
        Write-Host "3. Continue anyway (wrappers will be created but won't work until claude is available)"
        Write-Host ""
        $continue = Read-Host "Continue with installation? (y/n)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            Write-Host "Installation cancelled."
            exit 1
        }
        return $false
    }
}

# Report installation errors to GitHub
function Report-Error {
    param(
        [string]$ErrorMessage,
        [string]$ErrorLine = "",
        [object]$ErrorRecord = $null
    )

    Write-Host ""
    Write-Host "ERROR: Installation failed!" -ForegroundColor Red
    Write-Host ""

    # Collect system information
    $osInfo = try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        "Windows $($os.Version) ($($os.Caption))"
    } catch {
        "Windows (version unknown)"
    }

    $psVersion = $PSVersionTable.PSVersion.ToString()
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"

    # Sanitize error message (remove API keys)
    $sanitizedError = $ErrorMessage -replace 'ANTHROPIC_AUTH_TOKEN\s*=\s*\S+', 'ANTHROPIC_AUTH_TOKEN="[REDACTED]"'
    $sanitizedError = $sanitizedError -replace 'ZaiApiKey\s*=\s*\S+', 'ZaiApiKey="[REDACTED]"'
    $sanitizedError = $sanitizedError -replace '\$ZaiApiKey\s*=\s*"\S+"', '$ZaiApiKey="[REDACTED]"'

    # Get additional context
    $claudeFound = if (Get-Command claude -ErrorAction SilentlyContinue) { "Yes" } else { "No" }

    # Build error report (using string concatenation to avoid here-string parsing issues)
    $issueBody = "## Installation Error (Windows PowerShell)`n`n"
    $issueBody += "**OS:** $osInfo`n"
    $issueBody += "**PowerShell:** $psVersion`n"
    $issueBody += "**Timestamp:** $timestamp`n`n"
    $issueBody += "### Error Details:`n"
    $issueBody += "``````n"
    $issueBody += "$sanitizedError`n"
    $issueBody += "``````n`n"

    if ($ErrorLine) {
        $issueBody += "**Error Location:** $ErrorLine`n`n"
    }

    $issueBody += "### System Information:`n"
    $issueBody += "- Installation Location: $UserBinDir`n"
    $issueBody += "- Claude Code Found: $claudeFound`n"

    try {
        $execPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
        $issueBody += "- PowerShell Execution Policy: $execPolicy`n"
    } catch {
        $issueBody += "- PowerShell Execution Policy: Unknown`n"
    }

    $issueBody += "`n### Additional Context:`n"

    if ($ErrorRecord) {
        try {
            $exceptionType = $ErrorRecord.Exception.GetType().FullName
            $category = $ErrorRecord.CategoryInfo.Category
            $issueBody += "- Exception Type: $exceptionType`n"
            $issueBody += "- Category: $category`n"
        } catch {
            $issueBody += "- Additional error details unavailable`n"
        }
    }

    $issueBody += "`n---`n"
    $issueBody += "*This error was automatically reported by the installer. Please add any additional context below.*"

    # URL encode the body (native PowerShell method, no dependencies)
    Write-DebugLog "Encoding error report for URL..."

    # Truncate body if too long (GitHub has URL limits)
    if ($issueBody.Length -gt 5000) {
        $issueBody = $issueBody.Substring(0, 5000) + "`n`n[Report truncated due to length]"
        Write-DebugLog "Truncated error report to 5000 characters"
    }

    # Use native PowerShell URL encoding
    $encodedBody = [uri]::EscapeDataString($issueBody)
    $encodedTitle = [uri]::EscapeDataString("Installation Error: Windows PowerShell")

    $issueUrl = "https://github.com/JoeInnsp23/claude-glm-wrapper/issues/new?title=$encodedTitle`&body=$encodedBody`&labels=bug,windows,installation"

    Write-Host "INFO: Error details have been prepared for reporting."
    Write-Host ""

    # Try multiple methods to open the browser
    $browserOpened = $false

    Write-DebugLog "Attempting to open browser with Start-Process..."
    try {
        Start-Process $issueUrl -ErrorAction Stop
        $browserOpened = $true
        Write-Host "OK: Browser opened. Please submit the GitHub issue." -ForegroundColor Green
    } catch {
        Write-DebugLog "Start-Process failed: $_"
    }

    if (-not $browserOpened) {
        Write-DebugLog "Attempting to open browser with cmd /c start..."
        try {
            & cmd /c start $issueUrl 2>$null
            if ($LASTEXITCODE -eq 0) {
                $browserOpened = $true
                Write-Host "OK: Browser opened. Please submit the GitHub issue." -ForegroundColor Green
            }
        } catch {
            Write-DebugLog "cmd /c start failed: $_"
        }
    }

    if (-not $browserOpened) {
        Write-DebugLog "Attempting to open browser with explorer.exe..."
        try {
            & explorer.exe $issueUrl
            $browserOpened = $true
            Write-Host "OK: Browser opened. Please submit the GitHub issue." -ForegroundColor Green
        } catch {
            Write-DebugLog "explorer.exe failed: $_"
        }
    }

    if (-not $browserOpened) {
        Write-Host "WARNING: Could not open browser automatically." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Please copy and open this URL manually:" -ForegroundColor Yellow
        Write-Host $issueUrl -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Or press Enter to see a shortened URL..." -ForegroundColor Gray
        $null = Read-Host

        # Create a shorter URL with just the title
        $shortUrl = "https://github.com/JoeInnsp23/claude-glm-wrapper/issues/new?title=$encodedTitle`&labels=bug,windows,installation"
        Write-Host "Shortened URL (add error details manually):" -ForegroundColor Yellow
        Write-Host $shortUrl -ForegroundColor Cyan
    }

    Write-Host ""
}

# Main installation
function Install-ClaudeGlm {
    Write-Host "INSTALLER: Claude-GLM PowerShell Installer for Windows"
    Write-Host "==============================================="
    Write-Host ""
    Write-Host "This installer:"
    Write-Host "  • Does NOT require administrator rights"
    Write-Host "  • Installs to: $UserBinDir"
    Write-Host "  • Works on Windows systems"
    Write-Host ""

    if ($Debug) {
        Write-Host "DEBUG: Debug mode enabled" -ForegroundColor Gray
        Write-Host ""
    }

    Write-DebugLog "Starting installation process..."

    # Check Claude Code
    Write-DebugLog "Checking Claude Code installation..."
    Test-ClaudeInstallation

    # Setup user bin directory
    Write-DebugLog "Setting up user bin directory..."
    Setup-UserBin

    # Clean up old installations from different locations
    Write-DebugLog "Checking for old installations..."
    Remove-OldWrappers

    # Check if already installed
    $glmWrapper = Join-Path $UserBinDir "claude-glm.ps1"
    $glmFastWrapper = Join-Path $UserBinDir "claude-glm-fast.ps1"

    if ((Test-Path $glmWrapper) -or (Test-Path $glmFastWrapper)) {
        Write-Host ""
        Write-Host "OK: Existing installation detected!"
        Write-Host "1. Update API key only"
        Write-Host "2. Reinstall everything"
        Write-Host "3. Cancel"
        $choice = Read-Host "Choice (1-3)"

        switch ($choice) {
            "1" {
                $inputKey = Read-Host "Enter your Z.AI API key"
                if ($inputKey) {
                    $script:ZaiApiKey = $inputKey
                    New-ClaudeGlmWrapper
                    New-ClaudeGlm45Wrapper
                    New-ClaudeGlmFastWrapper
                    Write-Host "OK: API key updated!"
                    exit 0
                }
            }
            "2" {
                Write-Host "Reinstalling..."
            }
            default {
                exit 0
            }
        }
    }

    # Get API key
    Write-Host ""
    Write-Host "Enter your Z.AI API key (from https://z.ai/manage-apikey/apikey-list)"
    $inputKey = Read-Host "API Key"

    if ($inputKey) {
        $script:ZaiApiKey = $inputKey
        Write-Host "OK: API key received ($($inputKey.Length) characters)"
    } else {
        Write-Host "WARNING: No API key provided. Add it manually later to:"
        Write-Host "   $UserBinDir\claude-glm.ps1"
        Write-Host "   $UserBinDir\claude-glm-4.5.ps1"
        Write-Host "   $UserBinDir\claude-glm-fast.ps1"
    }

    # Create wrappers
    New-ClaudeGlmWrapper
    New-ClaudeGlm45Wrapper
    New-ClaudeGlmFastWrapper
    Add-PowerShellAliases

    # Final instructions
    Write-Host ""
    Write-Host "OK: Installation complete!"
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "IMPORTANT: Restart PowerShell or reload profile:"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "   . `$PROFILE"
    Write-Host ""
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "INFO: After reloading, you can use:"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "   claude-glm      - GLM-4.6 (latest)"
    Write-Host "   claude-glm-4.5  - GLM-4.5"
    Write-Host "   claude-glm-fast - GLM-4.5-Air (fast)"
    Write-Host ""
    Write-Host "Aliases:"
    Write-Host "   cc    - claude (regular Claude)"
    Write-Host "   ccg   - claude-glm (GLM-4.6)"
    Write-Host "   ccg45 - claude-glm-4.5 (GLM-4.5)"
    Write-Host "   ccf   - claude-glm-fast"
    Write-Host ""

    if ($ZaiApiKey -eq "YOUR_ZAI_API_KEY_HERE") {
        Write-Host "WARNING: Don't forget to add your API key to:"
        Write-Host "   $UserBinDir\claude-glm.ps1"
        Write-Host "   $UserBinDir\claude-glm-4.5.ps1"
        Write-Host "   $UserBinDir\claude-glm-fast.ps1"
    }

    Write-Host ""
    Write-Host "LOCATION: Installation location: $UserBinDir"
    Write-Host "LOCATION: Config directories: $GlmConfigDir, $Glm45ConfigDir, $GlmFastConfigDir"
}

# Test error functionality if requested
if ($TestError) {
    Write-Host "TEST: Testing error reporting functionality..." -ForegroundColor Magenta
    Write-Host ""

    # Show how script was invoked
    if ($env:CLAUDE_GLM_TEST_ERROR) {
        Write-Host "   (Invoked via environment variable)" -ForegroundColor Gray
    }
    Write-Host ""

    # Create a test error
    $testErrorMessage = "This is a test error to verify error reporting works correctly"
    $testErrorLine = "Test mode - no actual error"

    # Create a mock error record
    try {
        throw $testErrorMessage
    } catch {
        Report-Error -ErrorMessage $testErrorMessage -ErrorLine $testErrorLine -ErrorRecord $_
    }

    Write-Host "OK: Test complete. If a browser window opened, error reporting is working!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To run normal installation, use:" -ForegroundColor Gray
    Write-Host "   iwr -useb https://raw.githubusercontent.com/JoeInnsp23/claude-glm-wrapper/main/install.ps1 | iex" -ForegroundColor Cyan
    exit 0
}

# Run installation with error handling
try {
    $ErrorActionPreference = "Stop"
    Write-DebugLog "Starting installation with ErrorActionPreference = Stop"
    Install-ClaudeGlm
} catch {
    $errorMessage = $_.Exception.Message
    $errorLine = if ($_.InvocationInfo.ScriptLineNumber) {
        "Line $($_.InvocationInfo.ScriptLineNumber) in $($_.InvocationInfo.ScriptName)"
    } else {
        "Unknown location"
    }

    Write-DebugLog "Caught error: $errorMessage at $errorLine"
    Report-Error -ErrorMessage $errorMessage -ErrorLine $errorLine -ErrorRecord $_
    exit 1
}
