<#
.SYNOPSIS
    Returns list of installed software on remote PC.

.DESCRIPTION
    Retrieves list of installed programs utilizing registry entries.
    Sends jobs in parallel to each device.

.PARAMETER hosts
    Array of hostnames, comma separated.

.EXAMPLE
    For single entries.

    securebuild.ps1 -hosts nin-itd-cs4rx

.EXAMPLE
    For multiple entries, comma separate hostnames

    securebuild.ps1 -hosts nin-itd-cs4rx,nin-itd-cwbm
#>

param(
    [string[]]$hosts
)

$cred = get-credential
$computers = [System.Collections.ArrayList]@()
$missing = [System.Collections.ArrayList]@()
ipconfig /flushdns
clear-host

if (!$hosts)
{
    clear-host
    write-host "You did not specify a ComputerName." -foreground yellow
    $computers = read-host -Prompt "Enter the computername"
    clear-host
}

foreach ($i in $hosts)  
{ 
    $computers += $i
}

$JobTimeOut = 600
Write-Host (Get-Date) -ForegroundColor Yellow
write-host "Sending $($computers.count) jobs" -foreground yellow
Write-Host ("Waiting up to " + (($JobTimeOut / 60).ToString("0.0") ) + " minutes for job to complete") -ForegroundColor Yellow

$scriptBlock = {
        $array = @()
        $computername = $env:computername
        $UninstallKey="SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall" 
        $UninstallKey32="SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall" 
        $reg=[microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine',$computername) 
        $reg32=[microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine',$computername) 
        $regkey=$reg.OpenSubKey($UninstallKey) 
        $regkey32=$reg32.OpenSubKey($UninstallKey32) 
        $subkeys=$regkey.GetSubKeyNames() 
        $subkeys32=$regkey32.GetSubKeyNames()

        foreach($key in $subkeys){
            $thisKey=$UninstallKey+"\\"+$key 
            $thisSubKey=$reg.OpenSubKey($thisKey) 
            $obj = New-Object PSObject
            $obj | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:computername
            $obj | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $($thisSubKey.GetValue("DisplayName"))
            $obj | Add-Member -MemberType NoteProperty -Name "DisplayVersion" -Value $($thisSubKey.GetValue("DisplayVersion"))
            $obj | Add-Member -MemberType NoteProperty -Name "InstallLocation" -Value $($thisSubKey.GetValue("InstallLocation"))
            $obj | Add-Member -MemberType NoteProperty -Name "Publisher" -Value $($thisSubKey.GetValue("Publisher"))
            $array += $obj
        }

        foreach($key in $subkeys32){
            $thisKey=$UninstallKey32+"\\"+$key 
            $thisSubKey=$reg32.OpenSubKey($thisKey) 
            $obj = New-Object PSObject
            $obj | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $env:computername
            $obj | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $($thisSubKey.GetValue("DisplayName"))
            $obj | Add-Member -MemberType NoteProperty -Name "DisplayVersion" -Value $($thisSubKey.GetValue("DisplayVersion"))
            $obj | Add-Member -MemberType NoteProperty -Name "InstallLocation" -Value $($thisSubKey.GetValue("InstallLocation"))
            $obj | Add-Member -MemberType NoteProperty -Name "Publisher" -Value $($thisSubKey.GetValue("Publisher"))
            $array += $obj
        } 
        $array | Where-Object { $_.DisplayName -notlike "Update for Microsoft*" -and $_.DisplayName -notlike "Security Update for Microsoft*" -and ![string]::IsNullOrWhitespace($_.DisplayName) } | select ComputerName, DisplayName, DisplayVersion, Publisher | sort -unique DisplayName | ft -auto    
    }

$Session = New-PSSession -ComputerName $computers -Credential $cred -ErrorAction SilentlyContinue -ErrorVariable err
$job = Invoke-Command -Session $Session -ScriptBlock $ScriptBlock -ThrottleLimit 50 -AsJob -ErrorAction SilentlyContinue
$jobs = $job | Get-Job -IncludeChildJob
$null = $jobs | Wait-Job -Timeout $JobTimeOut
$ReturnValues = $jobs | Receive-Job -ErrorAction SilentlyContinue
clear-host
$returnedcomputers = $ReturnValues | select -Property PSComputerName -unique -ExpandProperty PSComputerName
$missing += $computers | where {$returnedcomputers -notcontains $_}

foreach($x in $returnedcomputers)
{
    $ReturnValues | where-object {$_.PSComputerName -eq $x} | out-string
}

foreach($x in $missing)
{
    Write-Host ("Could not reach: " + $x) -ForegroundColor Red
}