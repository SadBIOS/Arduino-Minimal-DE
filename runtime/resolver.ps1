$libs = @()
$libs += grep '#include' .\Arduino.ino | awk -F'[<>]' '{print $2}' | sed 's/_/ /g; s/.h//g'
$arrlen = $libs.Length
$libcount = 0
$bps = 0
$lbdix = @()
function meas {
    param (
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Stopwatch]$TIM
    )
    $msec = $TIM.Elapsed.TotalMilliseconds
    if ($msec -gt 1000) {
        $elapSec = [math]::Floor($msec / 1000)
        $MsecRem = $msec % 1000
        $hrs = [math]::Floor($elapSec / 3600)
        $mins = [math]::Floor(($elapSec % 3600) / 60)
        $sec = $elapSec % 60
        $rawTIM = ""
        if ($hrs -gt 0) {
            $rawTIM += "$hrs hr "
        }
        if ($mins -gt 0) {
            $rawTIM += "$mins min "
        }
        $rawTIM += "$sec sec $MsecRem ms"

        Write-Host "`nQuery Time: $rawTIM"
    }
    else {
        Write-Host "`nQuery Time: $msec ms"
    }
}
function clmatch($s1, $s2) {
    $s1 = $s1.ToLower()
    $s2 = $s2.ToLower()
    $d = @(0..$s2.Length)
    for ($i = 1; $i -le $s1.Length; $i++) {
        $d[0] = $i
        $current = $i
        for ($j = 1; $j -le $s2.Length; $j++) {
            $temp = $d[$j]
            if ($s1[$i - 1] -eq $s2[$j - 1]) {
                $d[$j] = $current
            }
            else {
                $d[$j] = [math]::Min($d[$j - 1], [math]::Min($current, $d[$j])) + 1
            }
            $current = $temp
        }
    }
    return $d[$s2.Length]
}

for ($i = 0; $i -lt $arrlen; $i++) {
    $tmp = arduino-cli lib list | grep $libs[$i] | sed 's/ /+/g' | grep -oP '(?<=\+)[0-9.]+(?=\+)'
    if ($null -ne $tmp) {
        Write-Host $libs[$i] -NoNewline
        Write-Host " --- This library already exists skipping re-install" -ForegroundColor Red
    }
    else {
        $tmprx = Get-Content .\master_library_catalog.txt | grep -w $libs[$i]
        if ($null -eq $tmprx) {
            $TIM = [System.Diagnostics.Stopwatch]::StartNew()
            $list = Get-Content .\master_library_catalog.txt
            $x = $libs[$i]
            $results = @()
            $catch = $null
            foreach ($index in 0..($list.Length - 1)) {
                $item = $list[$index]
                $dist = clmatch $x $item
                if ($dist -eq 1) {
                    $TIM.Stop()
                    meas $TIM 
                    Write-Host "`nExact match to " -NoNewline -ForegroundColor Cyan
                    Write-Host $x -NoNewline 
                    Write-Host " found!" -ForegroundColor Cyan
                    Write-Host "`nIndex: $index - $item`n"
                    $catch = 1
                    $lbdix += $index
                    $bps++
                    break
                }
                $results += [PSCustomObject]@{ Item = $item; Distance = $dist; Index = $index }
            }
            $TIM.Stop()
            if ($null -eq $catch) {
                meas $TIM 
                if ($results.Count -gt 0) {
                    $topMatches = $results | Sort-Object Distance | Select-Object -First 5
                    Write-Host "`nTop 5 closest matches to: " -ForegroundColor Cyan -NoNewline
                    Write-Host $x
                    $serialNumber = 1
                    $libcount++
                    $bps++
                    foreach ($match in $topMatches) {
                        Write-Output "$serialNumber. Index: $($match.Index) - $($match.Item) "
                        $serialNumber++
                    }
                }
            }
        }
        if ($null -ne $tmprx) {
            $TIM = [System.Diagnostics.Stopwatch]::StartNew()
            $list = Get-Content .\master_library_catalog.txt
            $x = $libs[$i]
            $results = @()
            $catch = $null
            foreach ($index in 0..($list.Length - 1)) {
                $item = $list[$index]
                $dist = clmatch $x $item
                if ($dist -eq 1) {
                    $TIM.Stop()
                    meas $TIM 
                    Write-Host "`nExact match to " -NoNewline -ForegroundColor Cyan
                    Write-Host $x -NoNewline 
                    Write-Host " found!" -ForegroundColor Cyan
                    Write-Host "`nIndex: $index - $item`n"
                    $catch = 1
                    $lbdix += $index
                    $bps++
                    break
                }
                $results += [PSCustomObject]@{ Item = $item; Distance = $dist; Index = $index }
            }
            $TIM.Stop()
            if ($null -eq $catch) {
                meas $TIM 
                if ($results.Count -gt 0) {
                    $topMatches = $results | Sort-Object Distance | Select-Object -First 5
                    Write-Host "`nTop 5 closest matches to: " -ForegroundColor Cyan -NoNewline
                    Write-Host $x
                    $serialNumber = 1
                    $libcount++
                    $bps++
                    foreach ($match in $topMatches) {
                        Write-Output "$serialNumber. Index: $($match.Index) - $($match.Item) "
                        $serialNumber++
                    }
                }
            }
        }
    }
    $tmp = $null
}
Write-Host "`nMissing Library Count - $bps`n" -ForegroundColor Cyan
$tmprx = Get-Content .\master_library_catalog.txt
for ($i = 0; $i -lt $libcount; $i++) {
    $index = Read-Host "Enter the index of the Closest Library (0 to $($tmprx.Length - 1))"
    if ($index -match '^\d+$') {
        $index = [int]$index
        if ($index -ge 0 -and $index -lt $tmprx.Length) {
            if ($lbdix.Contains($index)) {
                Write-Host "Index [$index]" -NoNewline
                Write-Host " - $($tmprx[$index])"  -NoNewline -ForegroundColor Cyan
                Write-Host " has already been added to the queue. Please select a different index."
                $i--
            }
            else {
                Write-Host "'$($tmprx[$index])'" -NoNewline -ForegroundColor Cyan
                Write-Host " has been added to install queue."
                $lbdix += $index
            }
        }
        else {
            $skipOption = Read-Host "Invalid Library index. Would you like to try again (Y/N) or skip (S)?"
            if ($skipOption -eq 'S') {
                Write-Host "You chose to skip. You can install the library manually." -ForegroundColor Red
                break
            }
        }
    }
    else {
        Write-Host "Please enter a valid number."
    }
}
$ctr = 1
$lbdix | ForEach-Object { 
    $tpxr = $tmprx[$_]
    Write-Host "$ctr. $($tpxr) [$($_)]"
    $ctr++
}
if ($bps -gt 0) {
    $userInput = Read-Host "Do you want to start the installation? (Y/N)"
    if ($userInput -ieq "y") {
        Write-Host "Starting installation..."
        for ($i = 0; $i -lt $lbdix.Length; $i++) {
            Write-Progress -PercentComplete $i -Status "Installing $($tmprx[$($lbdix[$i])])" -Activity "Invoking arduino-cli library installer"
            arduino-cli lib install "$($tmprx[$($lbdix[$i])])"
            Start-Sleep -Seconds 1
        }
        Write-Host "`nInstallation completed!"
    }
    elseif ($userInput -ieq "n") {
        Write-Host "Quitting session..."
    }
    else {
        Write-Host "Invalid input. Please enter 'Y' or 'N'."
    }
}
