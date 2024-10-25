param (
    [string]$DatabaseName = "",         
    [string]$ServerInstance = "",   
    [string]$username = '',
    [string]$password = '',
    [string]$identValue = '',
	[string]$userId = ''
)

$currentDir = Get-Location
Write-Host $currentDir.Path

# Define the location of the OIM tools
$oim_tools_location="C:\IAMTools\tools_9.2\UDEV"
# Define the output file path
$outputPath = "C:\Temp\"
$outputFile = "TransportTemplate.xml"

# Force PowerShell to use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Define the connection string (TrustServerCertificate=True if using untrusted SSL)
$connectionString = "Server=$ServerInstance;Database=$DatabaseName;Integrated Security=True;TrustServerCertificate=True"
Write-Host "Connection String: $connectionString"

# SQL query to get UID_DialogTag (PK) based on Ident_DialogTag
$sqlQuery = "SELECT UID_DialogTag FROM DialogTag WHERE Ident_DialogTag = '$identValue'"


# Execute the SQL query and get the results
try {
    $result = Invoke-Sqlcmd -ConnectionString $connectionString -Query $sqlQuery -MaxCharLength 2147483647
    $pkValue = $result[0]
    Write-Host "Result: $result"
    Write-Host "UID_DialogTag: $pkValue"
} catch {
    Write-Host "Error querying the database: $_"
    exit
}

# Define the XML structure
$xmlTemplate = @"
<TransportTemplate Version="1.0">
  <Header>
    <Parameter Name="Description">$identValue</Parameter>
  </Header>
  <Tasks>
    <Task Class="VI.Transport.TagTransport, VI.Transport" Display="TagTransport">
      <Parameter Name="Tags">
        <Parameter Name="PK">$pkValue</Parameter>
      </Parameter>
      <Parameter Name="Options">
        <Parameter Name="LockTags">1</Parameter>
        <Parameter Name="UseRelations">0</Parameter>
      </Parameter>
    </Task>
  </Tasks>
</TransportTemplate>
"@

# Write the XML to a file
$location = "${outputPath}${outputFile}"
$xmlTemplate | Out-File -FilePath $location -Encoding UTF8

Write-Host "XML file generated successfully at $location"
$dateStr = Get-Date -Format "yyyyMMdd"

$transportFilename="${outputPath}Transport_${identValue}_${userId}_${dateStr}.zip"

Write-Host $transportFilename

$trasporterParams = " /File=""${transportFilename}"" /Conn=""Server=${ServerInstance}; Database=${DatabaseName}; Integrated Security=SSPI;"" /Auth=""Module=DialogUser;User=${username};Password=${password}"" /template=""c:\temp\${outputFile}"""

Set-Location -Path $oim_tools_location
Start-Process ".\DBTransporterCmd.exe" -ArgumentList $trasporterParams
Set-Location -Path $currentDir
