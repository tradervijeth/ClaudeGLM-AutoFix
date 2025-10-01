# Claude-GLM PowerShell Installer for Windows
# Works without admin rights, installs to user's profile directory

# Configuration
$UserBinDir = "$env:USERPROFILE\.local\bin"
$GlmConfigDir = "$env:USERPROFILE\.claude-glm"
$Glm45ConfigDir = "$env:USERPROFILE\.claude-glm-45"
$GlmFastConfigDir = "$env:USERPROFILE\.claude-glm-fast"
$ZaiApiKey = "YOUR_ZAI_API_KEY_HERE"

# Find all existing wrapper installations
function Find-AllInstallations {
    $locations = @(
        "$env:USERPROFILE\.local\bin",
        "$env:ProgramFiles\Claude-GLM",
        "$env:LOCALAPPDATA\Programs\claude-glm",
        "C:\Program Files\Claude-GLM"
    )

    $foundFiles = @()

    foreach ($location in $locations) {
        if (Test-Path $location) {
            # Find all claude-glm*.ps1 files in this location
            $files = Get-ChildItem -Path $location -Filter "claude-glm*.ps1" -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                $foundFiles += $file.FullName
            }
        }
    }

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
    Write-Host "🔍 Found existing wrappers in multiple locations:"
    Write-Host ""

    foreach ($wrapper in $oldWrappers) {
        Write-Host "  ❌ $wrapper (old location)"
    }

    if ($currentWrappers.Count -gt 0) {
        foreach ($wrapper in $currentWrappers) {
            Write-Host "  ✅ $wrapper (current location)"
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
                Write-Host "  ✅ Removed: $wrapper"
            } catch {
                Write-Host "  ⚠️  Could not remove: $wrapper (permission denied)"
            }
        }
        Write-Host ""
        Write-Host "✅ Cleanup complete!"
    } else {
        Write-Host ""
        Write-Host "⚠️  Skipping cleanup. Old wrappers may interfere with the new installation."
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
        Write-Host "📝 Adding $UserBinDir to PATH..."

        # Add to user PATH
        $newPath = if ($currentPath) { "$currentPath;$UserBinDir" } else { $UserBinDir }
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")

        # Update current session PATH
        $env:PATH = "$env:PATH;$UserBinDir"

        Write-Host ""
        Write-Host "⚠️  IMPORTANT: PATH has been updated for future sessions."
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
    $profileContent = Get-Content $PROFILE -ErrorAction SilentlyContinue

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

    Write-Host "✅ Added aliases to PowerShell profile: $PROFILE"
}

# Create the GLM-4.6 wrapper
function New-ClaudeGlmWrapper {
    $wrapperPath = Join-Path $UserBinDir "claude-glm.ps1"

    $wrapperContent = @"
# Claude-GLM - Claude Code with Z.AI GLM-4.6 (Standard Model)

# Set Z.AI environment variables
`$env:ANTHROPIC_BASE_URL = "https://api.z.ai/api/anthropic"
`$env:ANTHROPIC_AUTH_TOKEN = "$ZaiApiKey"
`$env:ANTHROPIC_MODEL = "glm-4.6"
`$env:ANTHROPIC_SMALL_FAST_MODEL = "glm-4.5-air"

# Use custom config directory to avoid conflicts
`$env:CLAUDE_HOME = "$GlmConfigDir"

# Create config directory if it doesn't exist
if (-not (Test-Path `$env:CLAUDE_HOME)) {
    New-Item -ItemType Directory -Path `$env:CLAUDE_HOME -Force | Out-Null
}

# Create/update settings file with GLM configuration
`$settingsContent = @"
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "$ZaiApiKey",
    "ANTHROPIC_MODEL": "glm-4.6",
    "ANTHROPIC_SMALL_FAST_MODEL": "glm-4.5-air"
  }
}
"@

Set-Content -Path (Join-Path `$env:CLAUDE_HOME "settings.json") -Value `$settingsContent

# Launch Claude Code with custom config
Write-Host "🚀 Starting Claude Code with GLM-4.6 (Standard Model)..."
Write-Host "📁 Config directory: `$env:CLAUDE_HOME"
Write-Host ""

# Check if claude exists
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Error: 'claude' command not found!"
    Write-Host "Please ensure Claude Code is installed and in your PATH"
    exit 1
}

# Run the actual claude command
& claude `$args
"@

    Set-Content -Path $wrapperPath -Value $wrapperContent
    Write-Host "✅ Installed claude-glm at $wrapperPath"
}

# Create the GLM-4.5 wrapper
function New-ClaudeGlm45Wrapper {
    $wrapperPath = Join-Path $UserBinDir "claude-glm-4.5.ps1"

    $wrapperContent = @"
# Claude-GLM-4.5 - Claude Code with Z.AI GLM-4.5

# Set Z.AI environment variables
`$env:ANTHROPIC_BASE_URL = "https://api.z.ai/api/anthropic"
`$env:ANTHROPIC_AUTH_TOKEN = "$ZaiApiKey"
`$env:ANTHROPIC_MODEL = "glm-4.5"
`$env:ANTHROPIC_SMALL_FAST_MODEL = "glm-4.5-air"

# Use custom config directory to avoid conflicts
`$env:CLAUDE_HOME = "$Glm45ConfigDir"

# Create config directory if it doesn't exist
if (-not (Test-Path `$env:CLAUDE_HOME)) {
    New-Item -ItemType Directory -Path `$env:CLAUDE_HOME -Force | Out-Null
}

# Create/update settings file with GLM configuration
`$settingsContent = @"
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "$ZaiApiKey",
    "ANTHROPIC_MODEL": "glm-4.5",
    "ANTHROPIC_SMALL_FAST_MODEL": "glm-4.5-air"
  }
}
"@

Set-Content -Path (Join-Path `$env:CLAUDE_HOME "settings.json") -Value `$settingsContent

# Launch Claude Code with custom config
Write-Host "🚀 Starting Claude Code with GLM-4.5..."
Write-Host "📁 Config directory: `$env:CLAUDE_HOME"
Write-Host ""

# Check if claude exists
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Error: 'claude' command not found!"
    Write-Host "Please ensure Claude Code is installed and in your PATH"
    exit 1
}

# Run the actual claude command
& claude `$args
"@

    Set-Content -Path $wrapperPath -Value $wrapperContent
    Write-Host "✅ Installed claude-glm-4.5 at $wrapperPath"
}

# Create the fast GLM-4.5-Air wrapper
function New-ClaudeGlmFastWrapper {
    $wrapperPath = Join-Path $UserBinDir "claude-glm-fast.ps1"

    $wrapperContent = @"
# Claude-GLM-Fast - Claude Code with Z.AI GLM-4.5-Air (Fast Model)

# Set Z.AI environment variables
`$env:ANTHROPIC_BASE_URL = "https://api.z.ai/api/anthropic"
`$env:ANTHROPIC_AUTH_TOKEN = "$ZaiApiKey"
`$env:ANTHROPIC_MODEL = "glm-4.5-air"
`$env:ANTHROPIC_SMALL_FAST_MODEL = "glm-4.5-air"

# Use custom config directory to avoid conflicts
`$env:CLAUDE_HOME = "$GlmFastConfigDir"

# Create config directory if it doesn't exist
if (-not (Test-Path `$env:CLAUDE_HOME)) {
    New-Item -ItemType Directory -Path `$env:CLAUDE_HOME -Force | Out-Null
}

# Create/update settings file with GLM-Air configuration
`$settingsContent = @"
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "$ZaiApiKey",
    "ANTHROPIC_MODEL": "glm-4.5-air",
    "ANTHROPIC_SMALL_FAST_MODEL": "glm-4.5-air"
  }
}
"@

Set-Content -Path (Join-Path `$env:CLAUDE_HOME "settings.json") -Value `$settingsContent

# Launch Claude Code with custom config
Write-Host "⚡ Starting Claude Code with GLM-4.5-Air (Fast Model)..."
Write-Host "📁 Config directory: `$env:CLAUDE_HOME"
Write-Host ""

# Check if claude exists
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Error: 'claude' command not found!"
    Write-Host "Please ensure Claude Code is installed and in your PATH"
    exit 1
}

# Run the actual claude command
& claude `$args
"@

    Set-Content -Path $wrapperPath -Value $wrapperContent
    Write-Host "✅ Installed claude-glm-fast at $wrapperPath"
}

# Check Claude Code availability
function Test-ClaudeInstallation {
    Write-Host "🔍 Checking Claude Code installation..."

    if (Get-Command claude -ErrorAction SilentlyContinue) {
        $claudePath = (Get-Command claude).Source
        Write-Host "✅ Claude Code found at: $claudePath"
        return $true
    } else {
        Write-Host "⚠️  Claude Code not found in PATH"
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
    Write-Host "❌ Installation failed!" -ForegroundColor Red
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
    $sanitizedError = $ErrorMessage -replace 'ANTHROPIC_AUTH_TOKEN["\s]*=["\s]*[^";\s]+', 'ANTHROPIC_AUTH_TOKEN="[REDACTED]"'
    $sanitizedError = $sanitizedError -replace 'ZaiApiKey["\s]*=["\s]*[^";\s]+', 'ZaiApiKey="[REDACTED]"'
    $sanitizedError = $sanitizedError -replace '\$ZaiApiKey\s*=\s*"[^"]+"', '$ZaiApiKey="[REDACTED]"'

    # Get additional context
    $claudeFound = if (Get-Command claude -ErrorAction SilentlyContinue) { "Yes" } else { "No" }

    # Build error report
    $issueBody = @"
## Installation Error (Windows PowerShell)

**OS:** $osInfo
**PowerShell:** $psVersion
**Timestamp:** $timestamp

### Error Details:
``````
$sanitizedError
``````

$(if ($ErrorLine) { "**Error Location:** $ErrorLine`n" })

### System Information:
- Installation Location: $UserBinDir
- Claude Code Found: $claudeFound
- PowerShell Execution Policy: $(Get-ExecutionPolicy -Scope CurrentUser)

### Additional Context:
$(if ($ErrorRecord) {
"- Exception Type: $($ErrorRecord.Exception.GetType().FullName)
- Category: $($ErrorRecord.CategoryInfo.Category)"
})

---
*This error was automatically reported by the installer. Please add any additional context below.*
"@

    # URL encode the body (PowerShell 5+ compatible)
    Add-Type -AssemblyName System.Web
    $encodedBody = [System.Web.HttpUtility]::UrlEncode($issueBody)
    $encodedTitle = [System.Web.HttpUtility]::UrlEncode("Installation Error: Windows PowerShell")

    $issueUrl = "https://github.com/JoeInnsp23/claude-glm-wrapper/issues/new?title=$encodedTitle&body=$encodedBody&labels=bug,windows,installation"

    Write-Host "📋 Error details have been prepared for reporting."
    Write-Host ""
    Write-Host "Please report this error by opening the following URL:"
    Write-Host $issueUrl -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Attempting to open in your browser..." -ForegroundColor Gray

    try {
        Start-Process $issueUrl
        Write-Host "✅ Browser opened. Please submit the GitHub issue." -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Could not open browser automatically. Please copy and paste the URL above." -ForegroundColor Yellow
    }

    Write-Host ""
}

# Main installation
function Install-ClaudeGlm {
    Write-Host "🔧 Claude-GLM PowerShell Installer for Windows"
    Write-Host "==============================================="
    Write-Host ""
    Write-Host "This installer:"
    Write-Host "  • Does NOT require administrator rights"
    Write-Host "  • Installs to: $UserBinDir"
    Write-Host "  • Works on Windows systems"
    Write-Host ""

    # Check Claude Code
    Test-ClaudeInstallation

    # Setup user bin directory
    Setup-UserBin

    # Clean up old installations from different locations
    Remove-OldWrappers

    # Check if already installed
    $glmWrapper = Join-Path $UserBinDir "claude-glm.ps1"
    $glmFastWrapper = Join-Path $UserBinDir "claude-glm-fast.ps1"

    if ((Test-Path $glmWrapper) -or (Test-Path $glmFastWrapper)) {
        Write-Host ""
        Write-Host "✅ Existing installation detected!"
        Write-Host "1) Update API key only"
        Write-Host "2) Reinstall everything"
        Write-Host "3) Cancel"
        $choice = Read-Host "Choice (1-3)"

        switch ($choice) {
            "1" {
                $inputKey = Read-Host "Enter your Z.AI API key"
                if ($inputKey) {
                    $script:ZaiApiKey = $inputKey
                    New-ClaudeGlmWrapper
                    New-ClaudeGlm45Wrapper
                    New-ClaudeGlmFastWrapper
                    Write-Host "✅ API key updated!"
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
        Write-Host "✅ API key received ($($inputKey.Length) characters)"
    } else {
        Write-Host "⚠️  No API key provided. Add it manually later to:"
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
    Write-Host "✅ Installation complete!"
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "⚡ IMPORTANT: Restart PowerShell or reload profile:"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "   . `$PROFILE"
    Write-Host ""
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "📝 After reloading, you can use:"
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
        Write-Host "⚠️  Don't forget to add your API key to:"
        Write-Host "   $UserBinDir\claude-glm.ps1"
        Write-Host "   $UserBinDir\claude-glm-4.5.ps1"
        Write-Host "   $UserBinDir\claude-glm-fast.ps1"
    }

    Write-Host ""
    Write-Host "📁 Installation location: $UserBinDir"
    Write-Host "📁 Config directories: $GlmConfigDir, $Glm45ConfigDir, $GlmFastConfigDir"
}

# Run installation with error handling
try {
    $ErrorActionPreference = "Stop"
    Install-ClaudeGlm
} catch {
    $errorMessage = $_.Exception.Message
    $errorLine = if ($_.InvocationInfo.ScriptLineNumber) {
        "Line $($_.InvocationInfo.ScriptLineNumber) in $($_.InvocationInfo.ScriptName)"
    } else {
        "Unknown location"
    }

    Report-Error -ErrorMessage $errorMessage -ErrorLine $errorLine -ErrorRecord $_
    exit 1
}
