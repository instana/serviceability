
###############################################################################
#
# Copyright IBM Corp. 2025
#
# This script collects data from IBM MQ
#
###############################################################################

$VERSION = "1.0.0"
Write-Host "Version: $VERSION" -ForegroundColor Yellow

# Function to check if the user belongs to the 'mqm' group or is an Administrator
function Check-MqmOrAdminGroup {
    $user = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($user)

    $isInMqmGroup = $principal.IsInRole("mqm")
    $isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not ($isInMqmGroup -or $isAdmin)) {
        Write-Error "User '$env:USERNAME' must be in the 'mqm' group or an Administrator. Exiting."
        exit 1
    }
}

# Function to check if the specified queue manager is running
function Check-QmgrRunning {
    param (
        [string]$QueueManager
    )

    $status = & dspmq -m $QueueManager 2>$null

    if (-not $status) {
        Write-Error "Queue Manager '$QueueManager' not found. Exiting."
        exit 1
    } elseif ($status -notmatch "Running") {
        Write-Error "Queue Manager '$QueueManager' is not running. Exiting."
        exit 1
    }
}

# Function to execute MQSC commands
function Execute-Mqsc {
    param (
        [string]$Command,
        [string]$QueueManager
    )

    $Command | & runmqsc $QueueManager
}

# Run group or admin check
Check-MqmOrAdminGroup

# Check if a queue manager name is provided
if ($args.Count -eq 0) {
    Write-Host "Usage: .\script.ps1 <QueueManagerName>"
    exit 1
}

$QMGR_NAME = $args[0]

# Check if the queue manager is running
Check-QmgrRunning -QueueManager $QMGR_NAME

# Display full status of all queue managers
Write-Host "`nFull Queue Manager Status (dspmq -x -o all):"
& dspmq -x -o all
Write-Host ""

# 1. Display definition and status of the queue manager
Write-Host "`nQueue Manager Definition and Status:"
Execute-Mqsc -Command "DISPLAY QMGR ALL" -QueueManager $QMGR_NAME
Execute-Mqsc -Command "DISPLAY QMSTATUS ALL" -QueueManager $QMGR_NAME
Write-Host ""

# 2. Display definitions and statuses of all channels
Write-Host "Channel Definitions:"
Execute-Mqsc -Command "DISPLAY CHANNEL(*) ALL" -QueueManager $QMGR_NAME
Write-Host ""

Write-Host "Channel Authentication Rules (CHLAUTH):"
Execute-Mqsc -Command "DISPLAY CHLAUTH(*) ALL" -QueueManager $QMGR_NAME
Write-Host ""

Write-Host "Channel Statuses:"
Execute-Mqsc -Command "DISPLAY CHSTATUS(*) ALL" -QueueManager $QMGR_NAME
Write-Host ""

# 3. Display definitions and statuses of all listeners
Write-Host "Listener Definitions:"
Execute-Mqsc -Command "DISPLAY LISTENER(*) ALL" -QueueManager $QMGR_NAME
Write-Host ""

Write-Host "Listener Statuses:"
Execute-Mqsc -Command "DISPLAY LSSTATUS(*) ALL" -QueueManager $QMGR_NAME
Write-Host ""
