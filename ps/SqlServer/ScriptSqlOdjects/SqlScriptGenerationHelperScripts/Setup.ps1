#Author: Ayo Ijidakinro
#Date: 09/01/2012

$nl = [Environment]::NewLine
$0 = [String]::Empty
[Environment]::CurrentDirectory= (Get-Location -PSProvider "FileSystem").ProviderPath <#PowerShell doesn't start with a correct base directory, so as part of setup we need to resolve this. #>