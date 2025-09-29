# gather-ACE.ps1 – Enhanced with MQSC listener, chlauth, chstatus, ace credentials check

param (
    [string]$NodeName = "",       # integration node name
    [string]$QueueManager = "",   # queue manager name
    [string]$AdminURL = "",       # Administration URI
    [string]$User = "",           # Username
    [string]$Pass = "",           # Password
    [string]$CustomApi = ""       # Optional - If the user is using IIB10. Default is apiv2
)

# !! Please run this script in the IBM ACE Command Console (integrated environment)
# Usage examples:
#   .\instana-ace-mustgather.ps1 -NodeName iNode1                     # Examines only the specified node
#   .\instana-ace-mustgather.ps1 -QueueManager QM1                    # Examines only the specified queue manager
#   .\instana-ace-mustgather.ps1 -NodeName iNode1 -QueueManager QM1 -AdminURL http://acewindows21:4415   # Examines only the specified node, queue manager and verifies the ace credentials without username and password
#   .\instana-ace-mustgather.ps1 -NodeName iNode1 -QueueManager QM1 -AdminURL http://acewindows21:4415 -User adminUser -Pass myStrongPass  # Examines only the specified node, queue manager and verifies the ace credentials with username and password
#   .\instana-ace-mustgather.ps1 -NodeName iNode1 -QueueManager QM1 -AdminURL http://acewindows21:4415 -User adminUser -Pass myStrongPass -CustomApi apiv1  # Examines only the specified node, queue manager and verifies the ace credentials with username and password on custom api. For eg: apiv1(IIB10)

$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$outDir = "ace_mustgather_$ts"
New-Item -ItemType Directory -Path $outDir | Out-Null
$log = "$outDir\gather.log"
Start-Transcript -Path $log

function Show-Section {
    param([string]$Title)
    Write-Host "`n============================================================"
    Write-Host ">>> $Title"
    Write-Host "============================================================"
}

Write-Host "== ACE Must-Gather Started: $(Get-Date) =="

# 1. mqsilist summary + running integration server
Show-Section "mqsilist Summary"
$mqsisumm = mqsilist -a -d 1 | Tee-Object -Variable lines
$mqsisumm

Show-Section "Running Integration Servers"
$lines | Where-Object { $_ -match "Integration server '(.+?)' on integration node '(.+?)' is running" }

# 2. whoami /groups filtered
Show-Section "whoami /groups (mqm & mqbrkrs)"
whoami /groups | Select-String "mqm","mqbrkrs"

# 3. local group membership
Show-Section "Local Group Membership: mqm"
net localgroup mqm
Show-Section "Local Group Membership: mqbrkrs"
net localgroup mqbrkrs

# 4. MQSC collection (if QueueManager is provided)
Show-Section "MQSC Collection"

# Check if QueueManager is provided
if (-not $NodeName -and -not $QueueManager) {
  Write-Host "!! No node name or queue manager name provided."
  Write-Host "Please specify at least one of these parameters to examine specific components:"
  Write-Host "  -NodeName: To examine a specific integration node"
  Write-Host "  -QueueManager: To examine a specific queue manager"
  Write-Host "Example: .\instana-ace-mustgather.ps1 -NodeName YourNodeName -QueueManager YourQMName"
  
  # Skip MQSC collection if no parameters provided
  Write-Host "`nSkipping MQSC collection. Please provide QueueManager parameter."
} elseif ($QueueManager) {
  # Use the QueueManager parameter directly
  Write-Host "Using specified queue manager: $QueueManager"
  Write-Host "`n------------------------------------------------------------"
  Write-Host " Queue Manager: $QueueManager"
  Write-Host "------------------------------------------------------------"
  
  # MQSC collection: listeners, channel auth & status
  Show-Section "MQSC: Listeners for $QueueManager"
  echo "DISPLAY LISTENER(*) ALL" | runmqsc $QueueManager

  Show-Section "MQSC: Listener Status for $QueueManager"
  echo "DISPLAY LSSTATUS(*) ALL" | runmqsc $QueueManager | Out-String

  Show-Section "MQSC: Check connection authentication for $QueueManager"
  echo "dis qmgr connauth" | runmqsc $QueueManager

  Show-Section "MQSC: Channel Authentication for $QueueManager"
  echo "dis qmgr chlauth" | runmqsc $QueueManager

  Show-Section "MQSC: Channel Status for $QueueManager"
  echo "DISPLAY CHSTATUS(*)" | runmqsc $QueueManager
} else {
  Write-Host "Skipping MQSC collection. Please provide QueueManager parameter to collect MQSC information."
}

# 6. TCP Ports used by ACE/MQ Processes
Show-Section "TCP Ports for runmqlsr, bipMQTT, bipbroker"
Get-NetTCPConnection | ForEach-Object {
    $p = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
    if ($p.ProcessName -in 'runmqlsr','bipMQTT','bipbroker') {
        [PSCustomObject]@{
            PID          = $_.OwningProcess
            ProcessName  = $p.ProcessName
            LocalPort    = $_.LocalPort
            LocalAddress = $_.LocalAddress
        }
    }
} | Sort-Object ProcessName, LocalPort | Format-Table -AutoSize

# 7. Resource & flow stats
Show-Section "Resource and Flow Stats"

# Check if NodeName is provided
if (-not $NodeName -and -not $QueueManager) {
  Write-Host "Skipping resource and flow stats. Please provide NodeName parameter."
} elseif ($NodeName) {
  # If NodeName is provided, collect stats for that specific node
  Write-Host "Collecting resource and flow stats for specified node: $NodeName"
  
  # Get servers for this specific node directly
  $servers = mqsilist $NodeName | Select-String "Integration server '(.+?)'"
  
  if ($servers) {
    foreach ($s in $servers) {
      $is = ($s -replace ".*Integration server '(.+?)'.*", '$1')
      Write-Host "`n>>> Resource stats for Node [$NodeName] / Server [$is]"
      mqsireportresourcestats $NodeName -e $is

      Write-Host "`n>>> Flow stats for Node [$NodeName] / Server [$is]"
      mqsireportflowstats $NodeName -s -e $is
    }
  } else {
    Write-Host "!! No servers found for node: $NodeName"
  }
} else {
  Write-Host "Skipping resource and flow stats. NodeName parameter is required for this section."
}

# 7. “Log on as service” policy
Write-Host "`n-- 'Log on as a service' rights --"
$tempFile = "$outDir\secedit.inf"
secedit /export /areas USER_RIGHTS /cfg $tempFile | Out-Null

# Extract accounts with SeServiceLogonRight
$secLine = Select-String -Path $tempFile -Pattern "SeServiceLogonRight"
if ($secLine) {
    $accounts = ($secLine.ToString() -replace ".*SeServiceLogonRight\s*=\s*", "") -split ","
    Write-Host "`nAccounts with 'Log on as a service':"
    $accounts | ForEach-Object { $_.Trim() }
} else {
    Write-Host "No SeServiceLogonRight entry found in security policy export."
}

# Remove the temporary secedit.inf since we already parsed it
Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

# 8. Integration Node overrides
Show-Section "Integration Node Overrides"

# Check if either NodeName or QueueManager is provided
if (-not $NodeName -and -not $QueueManager) {
    Write-Host "Skipping integration node overrides. Please provide NodeName parameter."
} elseif (-not $NodeName) {
    Write-Host "NodeName parameter is required to examine integration node overrides."
    Write-Host "Example: .\instana-ace-mustgather.ps1 -NodeName YourNodeName"
} else {
    Write-Host "Examining specified integration node: $NodeName"
    $nodePath = "C:\ProgramData\IBM\MQSI\components\$NodeName"
    
    # Check if the node directory exists
    if (-not (Test-Path $nodePath)) {
        Write-Host "!! Integration node not found: $NodeName"
    } else {
        # Check for node overrides file
        $nodeOverridesPath = "$nodePath\overrides\node.conf.yaml"
        if (Test-Path $nodeOverridesPath) {
            Write-Host "Node overrides file exists: $nodeOverridesPath"
            Write-Host "Contents of node overrides file:"
            Write-Host "----------------------------------------"
            cmd /c "type ""$nodeOverridesPath"""
            Write-Host "----------------------------------------"
        } else {
            Write-Host "No node.conf.yaml found for this node"
        }
    }
}

Show-Section "ACE credentials Test"

if (-not $AdminURL) {
    Write-Host "Skipping ACE credentials Test. Please provide AdminURL parameter."
    Write-Host "Example: .\instana-ace-mustgather.ps1 -AdminURL http://aceHost:port"
} else {
    if (-not $CustomApi) {
      $FullURL = "$AdminURL/apiv2"
    } else {
      $FullURL = "$AdminURL/$CustomApi"
    }
    Write-Host "Testing $FullURL"
    $curlCommand = "curl.exe -u ${User}:${Pass} -H `"Accept: application/json`" `"$FullURL`""

    try {
        $output = Invoke-Expression $curlCommand

        if ($LASTEXITCODE -ne 0) {
            Write-Host "!! curl failed with exit code $LASTEXITCODE"
        } elseif ($output -match 'BIP8509E') {
            Write-Host "!! Invalid credentials. Please check your username and password."
        } elseif ($output -match '^{.*}$') {
            Write-Host "Authentication successful. JSON response received."
            Write-Output $output
        } else {
            Write-Host "!! Unexpected response format. Possibly HTML or another error."
            Write-Output $output
        }
    } catch {
        Write-Host "!! Exception occurred:"
        Write-Host $_.Exception.Message
    }
}


Write-Host "`n== ACE Must-Gather Completed: $(Get-Date) =="
Stop-Transcript
Write-Host "`nResults in: $outDir"