# ###############################################################################
#
# Copyright IBM Corp. 2024, 2025
# Instana WebSphere Liberty Sensor MustGather Tool - Windows Version
#
# Usage:
#   .\instana-websphere-liberty-mustgather-windows.ps1
#
# ###############################################################################

$VERSION = "1.0.0"
Write-Host "Instana WebSphere Liberty Sensor MustGather Tool - Version: $VERSION"

# Create timestamp for directory name
$CURRENT_TIME = Get-Date -Format "yyyyMMdd-HHmmss"
$MGDIR = "instana-websphere-liberty-mustgather-$VERSION-$CURRENT_TIME"
New-Item -Path $MGDIR -ItemType Directory -Force | Out-Null

# Check Java availability
try {
    $javaVersion = java -version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Java is not available. Please install Java or ensure it is in your PATH."
        exit 1
    }
} catch {
    Write-Host "Error: Java is not available. Please install Java or ensure it is in your PATH."
    exit 1
}

# Collect Liberty information
function Collect-LibertyInfo {
    Write-Host "Enter the path to the WebSphere Liberty installation directory:"
    $liberty_path = Read-Host

    if (-not (Test-Path $liberty_path)) {
        Write-Host "Error: Liberty directory not found at $liberty_path"
        return $false
    }

    New-Item -Path "$MGDIR\liberty_info" -ItemType Directory -Force | Out-Null

    # Collect Liberty version
    if (Test-Path "$liberty_path\bin\productInfo.bat") {
        Write-Host "Collecting Liberty version information..."
        & "$liberty_path\bin\productInfo.bat" version > "$MGDIR\liberty_info\liberty_version.txt" 2>&1
        Write-Host "Liberty version information collected."
    } else {
        Write-Host "Warning: productInfo.bat not found at $liberty_path\bin\productInfo.bat"
    }

    # Ask for server name
    Write-Host "Enter the WebSphere Liberty server name:"
    $server_name = Read-Host

    $server_dir = "$liberty_path\usr\servers\$server_name"
    if (-not (Test-Path $server_dir)) {
        Write-Host "Error: Server directory not found at $server_dir"
        return $false
    }

    # Collect server.xml
    if (Test-Path "$server_dir\server.xml") {
        Copy-Item "$server_dir\server.xml" "$MGDIR\liberty_info\" -Force
        Write-Host "Server configuration (server.xml) collected."
        
        # Check for monitor-1.0 feature
        $monitorFeature = Select-String -Path "$server_dir\server.xml" -Pattern "monitor-1.0" -SimpleMatch
        if ($monitorFeature) {
            $monitorFeature | Out-File "$MGDIR\liberty_info\monitor_feature.txt"
        } else {
            "monitor-1.0 feature not found in server.xml" | Out-File "$MGDIR\liberty_info\monitor_feature.txt"
        }
        
        # Check for JMX configuration
        $jmxConfig = Select-String -Path "$server_dir\server.xml" -Pattern "monitor-1.0" -Context 0,10
        if ($jmxConfig) {
            $jmxConfig | Out-File "$MGDIR\liberty_info\jmx_config.txt"
        } else {
            "JMX configuration not found in server.xml" | Out-File "$MGDIR\liberty_info\jmx_config.txt"
        }
    } else {
        Write-Host "Warning: server.xml not found at $server_dir\server.xml"
    }

    # Collect jvm.options
    if (Test-Path "$server_dir\jvm.options") {
        Copy-Item "$server_dir\jvm.options" "$MGDIR\liberty_info\" -Force
        Write-Host "JVM options (jvm.options) collected."
        
        # Check for javaagent configuration
        $javaagentConfig = Select-String -Path "$server_dir\jvm.options" -Pattern "javaagent" -SimpleMatch
        if ($javaagentConfig) {
            $javaagentConfig | Out-File "$MGDIR\liberty_info\javaagent_config.txt"
        } else {
            "javaagent configuration not found in jvm.options" | Out-File "$MGDIR\liberty_info\javaagent_config.txt"
        }
    } else {
        Write-Host "Warning: jvm.options not found at $server_dir\jvm.options"
    }

    # Collect server logs
    if (Test-Path "$server_dir\logs") {
        New-Item -Path "$MGDIR\liberty_info\logs" -ItemType Directory -Force | Out-Null
        
        if (Test-Path "$server_dir\logs\console.log") {
            Copy-Item "$server_dir\logs\console.log" "$MGDIR\liberty_info\logs\" -Force
        }
        
        if (Test-Path "$server_dir\logs\messages.log") {
            Copy-Item "$server_dir\logs\messages.log" "$MGDIR\liberty_info\logs\" -Force
        }
        
        Write-Host "Server logs collected."
    } else {
        Write-Host "Warning: Server logs directory not found at $server_dir\logs"
    }

    # Check server status
    if (Test-Path "$liberty_path\bin\server.bat") {
        Write-Host "Collecting server status..."
        & "$liberty_path\bin\server.bat" status "$server_name" > "$MGDIR\liberty_info\server_status.txt" 2>&1
        Write-Host "Server status collected."
    } else {
        Write-Host "Warning: server.bat not found at $liberty_path\bin\server.bat"
    }

    return $true
}

# Main function
function instana_websphere_liberty_mustgather {
    # Collect Java version information
    Write-Host "Collecting Java version information..."
    java -version 2>&1 | Out-File "$MGDIR\java_version.txt"
    Write-Host "Java version information collected."

    # Collect system information
    Write-Host "Collecting system information..."
    systeminfo | Out-File "$MGDIR\system_info.txt"
    Write-Host "System information collected."

    # Collect Liberty information
    Collect-LibertyInfo

    # Create ZIP archive
    Write-Host "Creating archive..."
    Compress-Archive -Path $MGDIR -DestinationPath "$MGDIR.zip" -Force

    Write-Host ""
    Write-Host "Must-gather completed successfully."
    Write-Host "Archive created: $MGDIR.zip"
    Write-Host "Please provide this file to IBM Support for analysis."
}

# Execute the main function
instana_websphere_liberty_mustgather

