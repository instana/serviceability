# gather-ACE.ps1 – Enhanced with MQSC listener, chlauth, chstatus

# ⚠️ Please run this script in the IBM ACE Command Console (integrated environment)

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

Write-Host "== ACE Must‑Gather Started: $(Get-Date) =="

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

# 4. Node → Queue Manager mapping
Show-Section "Integration Node → Queue Manager Mapping"
$nodes = $mqsisumm -split "`r?`n" | 
  Where-Object { $_ -match "Integration node '(.+?)'.*default queue manager '(.+?)'" } |
  ForEach-Object { @{Node=$matches[1];Qmgr=$matches[2]} }

foreach ($n in $nodes) {
  Write-Host "`n------------------------------------------------------------"
  Write-Host " Node: $($n.Node) → QMGR: $($n.Qmgr)"
  Write-Host "------------------------------------------------------------"
  
  # 5. MQSC collection: listeners, channel auth & status
  Show-Section "MQSC: Listeners for $($n.Qmgr)"
  echo "DISPLAY LISTENER(*) ALL" | runmqsc $($n.Qmgr)

  Show-Section "MQSC: Listener Status for $($n.Qmgr)"
  echo "DISPLAY LSSTATUS(*) ALL" | runmqsc $($n.Qmgr) | Out-String

  Show-Section "MQSC: Channel Authentication Rules for $($n.Qmgr)"
  echo "DISPLAY CHLAUTH(*)" | runmqsc $($n.Qmgr)

  Show-Section "MQSC: Channel Status for $($n.Qmgr)"
  echo "DISPLAY CHSTATUS(*)" | runmqsc $($n.Qmgr)
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
foreach ($n in $nodes) {
  $servers = mqsilist $n.Node | Select-String "Integration server '(.+?)'"
  foreach ($s in $servers) {
    $is = ($s -replace ".*Integration server '(.+?)'.*", '$1')
    Write-Host "`n>>> Resource stats for Node [$($n.Node)] / Server [$is]"
    mqsireportresourcestats $n.Node -e $is

    Write-Host "`n>>> Flow stats for Node [$($n.Node)] / Server [$is]"
    mqsireportflowstats $n.Node -s -e $is
  }
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

Write-Host "`n== ACE Must‑Gather Completed: $(Get-Date) =="
Stop-Transcript
Write-Host "`nResults in: $outDir"