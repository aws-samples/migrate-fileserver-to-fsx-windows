# Export Users from Source Domain
$users = Get-ADUser -SearchBase "OU=Users,DC=source,DC=local" -Properties *
$users | Export-Csv -Path "C:\temp\source_users.csv" -NoTypeInformation

# Import Users in Destination Domain
$importedUsers = Import-Csv -Path "C:\migration\source_users.csv"
foreach ($user in $importedUsers) {
    New-ADUser -Name $user.Name -UserPrincipalName $user.UserPrincipalName -AccountPassword (ConvertTo-SecureString -String "P@ssw0rd" -AsPlainText -Force) -Enabled $true
}

# Export Groups and their members from Source Domain
$groups = Get-ADGroup -SearchBase "OU=Groups,DC=source,DC=local" -Properties *
$groupMembers = @()
foreach ($group in $groups) {
    $members = Get-ADGroupMember -Identity $group.DistinguishedName
    $groupMembers += [pscustomobject]@{
        GroupName = $group.Name
        Members = ($members.Name -join ",")
    }
}
$groupMembers | Export-Csv -Path "C:\migration\source_groups.csv" -NoTypeInformation

# Import Groups and their members in Destination Domain
$importedGroups = Import-Csv -Path "C:\temp\source_groups.csv"
foreach ($group in $importedGroups) {
    $newGroup = New-ADGroup -Name $group.GroupName -GroupScope Global
    $memberNames = $group.Members -split ","
    foreach ($memberName in $memberNames) {
        $member = Get-ADUser -Filter "Name -eq '$memberName'"
        Add-ADGroupMember -Identity $newGroup -Members $member
    }
}
