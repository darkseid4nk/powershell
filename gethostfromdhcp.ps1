$hostname = read-host ("Enter hostname or press Enter for all hosts: ")
$site = read-host ("Enter 3 letter site code or press Enter for all Vlans: ")

$array = @()

$dhcpserver = ((Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "DHCPEnabled=$true" | Select DHCPServer -ExpandProperty DHCPServer) -as [IPAddress]).IPAddressToString
$dnsname = Get-DhcpServerInDC -ErrorAction stop | where-object {$_.IPAddress -like "$dhcpserver"} | select DnsName -ExpandProperty DnsName

foreach ($scope in $(Get-DhcpServerv4Scope -ComputerName $dnsname -ErrorAction stop | Where-Object {$_.Name -like "$($site)*" -and $_.State -eq "Active"}))
{ 
    foreach ($lease in $(Get-DhcpServerv4Lease -ComputerName $dnsname -ScopeId $scope.ScopeId -ErrorAction stop | Where-Object {($_.AddressState -eq "Active" -or $_.AddressState -eq "ActiveReservation") -and $_.Hostname -like "$($hostname)*"}))
    {
        $obj = New-Object PSObject
        $obj | Add-Member -MemberType NoteProperty -Name "Vlan" -Value $scope.Name
        $obj | Add-Member -MemberType NoteProperty -Name "ScopeId" -Value $scope.ScopeId
        $obj | Add-Member -MemberType NoteProperty -Name "IPAddress" -Value $lease.IPAddress
        $obj | Add-Member -MemberType NoteProperty -Name "HostName" -Value $lease.HostName
        $obj | Add-Member -MemberType NoteProperty -Name "AddressState" -Value $lease.AddressState
        $obj | Add-Member -MemberType NoteProperty -Name "LeaseExpiryTime" -Value $lease.LeaseExpiryTime
        $array += $obj
    }
}

$array | sort-object Vlan, HostName | Where-Object { $_.ScopeId } | select Vlan, ScopeId, IPAddress, Hostname, AddressState, LeaseExpiryTime | ft -auto

