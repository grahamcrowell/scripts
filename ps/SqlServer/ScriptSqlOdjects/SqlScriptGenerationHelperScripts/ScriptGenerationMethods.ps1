#Author: Ayo Ijidakinro
#Date: 09/01/2012

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

$scriptdirectory = Get-ScriptDirectory

. "$scriptdirectory\Setup.ps1" <#placing a '.' before the script to ensure the script's variables 
                                                                                                are created in the current scope (see: Language reference 3.5.5)
                                                                                                
                                                                                                This script will setup System.IO's current directory and some common string
                                                                                                constants that will be needed later.
                                                                                                #>
. "$scriptdirectory\ScriptHelperMethods.ps1"

#completed initial setup

function GenerateSqlWithTables(
    [string[]]$schemasToScript,
    [string[]]$rolesToScript,
    [string]$outputFilepath,
    [string]$servername,
    [string]$dbname)
{
    GenerateSqlImp $schemasToScript $rolesToScript $outputFilepath $servername $dbname $true
}

function GenerateSqlWithoutTables(
    [string[]]$schemasToScript,
    [string[]]$rolesToScript,
    [string]$outputFilepath,
    [string]$servername,
    [string]$dbname)
{
    GenerateSqlImp $schemasToScript $rolesToScript $outputFilepath $servername $dbname $false
}
    
function GenerateSqlImp(
    [string[]]$schemasToScript,
    [string[]]$rolesToScript,
    [string]$outputFilepath,
    [string]$servername,
    [string]$dbname,
    [bool]$scriptTables)
{    
    $includeTables = $scriptTables #change name to a name more applicable to the filter callback method

    Write-Host ("Including tables: {0}" -f $includeTables) -Foreground Yellow
    
    #print out a header                                                                                                
    echo $0
    echo "=================="
    echo "Generating scripts"
    echo "=================="
    echo $0

    echo "Generating scripts for the following schemas..."
    echo $0
    foreach($schema in $schemasToScript) { echo $schema }
    echo $0

    echo "and for the following roles..."
    echo $0
    foreach($role in $rolesToScript) { echo $role }
    echo $0

    #Load needed assemblies into memory
    $assemblyName = "Microsoft.SqlServer.SMO, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91, processorArchitecture=MSIL"

    echo ("Loading assembly, {0}, into the current PowerShell domain." -f $assemblyName)
    [System.Reflection.Assembly]::Load($assemblyName) #Load the assembly we're going to obtain our scripting objects and db objects from
    #Finished loading assemblies

    echo $0

    #Obtain connection to database
    Write-Host ("Obtaining connection to the database using the following parameters: server={0};db={1}" -f $servername, $dbname) -ForegroundColor Green
    [Microsoft.SqlServer.Management.Smo.Server]$server = New-Object "Microsoft.SqlServer.Management.Smo.Server" $servername
    echo "A new server object has been created..."
    echo $0

    Write-Host "The following connection string will be used:"
    Write-Host ("{0}" -f $server.ConnectionContext.ConnectionString) -ForegroundColor Green
    echo $0

    echo "Connecting to database..."

    $server.ConnectionContext.Connect()
    if($server.ConnectionContext.IsOpen -eq $true)
    {
        echo "Successfully connected..."
    }
    else
    { 
        echo "Connection to the database failed..."
    }
    #finished connecting to the database

    #now let's find all of the objects that need to be scripted

    [array]$found_objects = @()

    if($server.ConnectionContext.IsOpen -eq $true) #if our connection to the database was successful
    {
        $db = $server.Databases[$dbname]
        [Microsoft.SqlServer.Management.Smo.SqlSmoObject[]]$found_objects = @()
        [Microsoft.SqlServer.Management.Smo.SqlSmoObject[]]$found_assemblies = @()
        [Microsoft.SqlServer.Management.Smo.SqlSmoObject[]]$found_schemas = @()
        [Microsoft.SqlServer.Management.Smo.SqlSmoObject[]]$found_tables = @()
        [Microsoft.SqlServer.Management.Smo.SqlSmoObject[]]$found_views = @()    
        [Microsoft.SqlServer.Management.Smo.SqlSmoObject[]]$found_sprocs = @()    
        [Microsoft.SqlServer.Management.Smo.SqlSmoObject[]]$found_roles = @()
        [Microsoft.SqlServer.Management.Smo.SqlSmoObject[]]$found_triggers = @()
        [Microsoft.SqlServer.Management.Smo.SqlSmoObject[]]$found_foreignKeys = @()
        [Microsoft.SqlServer.Management.Smo.SqlSmoObject[]]$found_indexes = @()
        [Microsoft.SqlServer.Management.Smo.SqlSmoObject[]]$found_userDefinedFunctions = @()
        [Microsoft.SqlServer.Management.Smo.SqlSmoObject[]]$found_userDefinedAggregates = @()
        [Microsoft.SqlServer.Management.Smo.SqlSmoObject[]]$found_userDefinedDataTypes = @()
        [Microsoft.SqlServer.Management.Smo.SqlSmoObject[]]$found_userDefinedTablesTypes = @()
        [Microsoft.SqlServer.Management.Smo.SqlSmoObject[]]$found_userDefinedTypes = @()
        
        <#  First extract schemas and make sure all were found, otherwise throw an exception
            as we don't want to check-in a script that is missing objects. #>
        $found_schemas = $db.Schemas | where { $schemasToScript -contains $_.Name }
        
        if($found_schemas.Length -ne $schemasToScript.Length)
        {
            throw "At least one of the indicated schemas to script was not found."
        }
        
        $found_roles = $db.Roles | where { $rolesToScript -contains $_.Name }
        
        if(($rolesToScript.Count -gt 0) -and ($found_roles.Length -ne $rolesToScript.Length))
        {
            throw "At least one of the indicated roles to script was not found."
        }
        
        #now let's shift gears to looking for all of the other objects
        $found_tables = $db.Tables | where { $schemasToScript -contains $_.Schema }
        
        #look for objects hanging off of tables
        foreach($table in $found_tables)
        {
            $found_keys = $table.ForeignKeys
            if($found_keys.Count -gt 0)
            {
                echo ("Foreign keys found for table: {0}" -f $table.Name)
                $found_foreignKeys += $found_keys
            }
            else
            {
                echo ("No foreign keys found for table: {0}" -f $table.Name)
            }
            
            $table_triggers = $table.Triggers
            if($table_triggers.Count -gt 0)
            {
                echo ("Triggers found for table: {0}" -f $table.Name)
                $found_triggers += $table_triggers
            }
            else
            {
                echo ("No triggers were found for table: {0}" -f $table.Name)
            }
            
            $table_indexes = $table.Indexes
            if($table_indexes.Count -gt 0)
            {
                echo ("Indexes found for table: {0}" -f $table.Name)
                $found_indexes += $table_indexes
            }
            else
            {
                echo ("No indexes were found for table: {0}" -f $table.Name)
            }
        }
        
        $found_assemblies = $db.Assemblies | where { "Microsoft.SqlServer.Types" -ne $_.Name }
        $found_views = $db.Views | where { $schemasToScript -contains $_.Schema }    
        $found_sprocs = $db.StoredProcedures | where { $schemasToScript -contains $_.Schema }        
        $found_userDefinedFunctions = $db.UserDefinedFunctions | where { $schemasToScript -contains $_.Schema }
        $found_userDefinedAggregates = $db.UserDefinedAggregates | where { $schemasToScript -contains $_.Schema }
        $found_userDefinedDataTypes = $db.UserDefinedDataTypes | where { $schemasToScript -contains $_.Schema }
        $found_userDefinedTablesTypes = $db.UserDefinedTableTypes | where { $schemasToScript -contains $_.Schema }
        $found_userDefinedTypes = $db.UserDefinedTypes | where { $schemasToScript -contains $_.Schema }
        
        #add everything that can be sorted by the dependecy walker. This does not include schemas, assemblies and roles
        if($found_tables.Count -gt 0) { $found_objects += $found_tables }    
        if($found_views.Count -gt 0) { $found_objects += $found_views } 
        if($found_sprocs.Count -gt 0) { $found_objects += $found_sprocs }            
        if($found_userDefinedFunctions.Count -gt 0) { $found_objects += $found_userDefinedFunctions }
        if($found_userDefinedAggregates.Count -gt 0) { $found_objects += $found_userDefinedAggregates }
        if($found_userDefinedDataTypes.Count -gt 0) { $found_objects += $found_userDefinedDataTypes }
        if($found_userDefinedTablesTypes.Count -gt 0) { $found_objects += $found_userDefinedTablesTypes }
        if($found_userDefinedTypes.Count -gt 0) { $found_objects += $found_userDefinedTypes }
        
        echo "The following objects were found and will be scripted..."
        
        foreach($object in $found_objects)
        {
            if($object -ne $null)
            {
                echo ("type: {0} name: {1}" -f $object.GetType().Name, $object.Name)
            }
        }
    }

    if(($found_objects -ne $null) -and ($found_objects.Length -gt 0)) #relying on short-circuit "and" to avoid an exception in the null case
    {
        #grab the drop and create script objects
        $dropScriptObject = Get-ScriptObjectDrop $server
        $createScriptObject = Get-ScriptObjectCreate $server        
        $filterCallbackFunction = Get-FilterCallbackFunction $schemasToScript $includeTables <# This method will be used to ensure that 
                                                                                                only objects in a target schema get scripted. #>
        
        #for now we set the filtering function to null
        $createScriptObject.FilterCallbackFunction = $null
        $dropScriptObject.FilterCallbackFunction = $null
        
        #grab the path we're writing to and verify it exists...
        [string]$parentPath = [System.IO.Path]::GetDirectoryName($outputFilePath)
        
        echo ("Looking for the parent path: {0}" -f $parentPath)
        
        if((Test-Path $parentPath) -ne $true) #check for the existence of the output folder
        {
            Write-Warning "Path not found... Will create directory upon your confirmation..."
            md $parentPath -confirm
            
            if((Test-Path $parentPath) -ne $true) #check for result of the "md" statement
            {
                throw "The directory of the file in the provided output file path does not exist. Thus script generation is unable to continue..."
            }
        }
        else
        {
            echo "Path found..."
        }
        
        if((Test-Path $outputFilePath) -eq $true) #if an existing file is already in our output location, let's delete it
        {
            del $outputFilePath #let's delete the old file that we're going to be overwriting
            
            if((Test-Path $outputFilePath) -eq $true) #check the result of the "del" statement
            {
                throw "A file already exists at the target location. The file must be deleted in order to continue."
            }
        }
        
        #write out the USE [DB_NAME] statements
        [string]$useDBStatements = ("USE [{0}]{1}GO" -f $dbname, $nl)
        
        echo  ("Added the following USE [DB] statements to the beginning of the output file: {0}{1}" -f $nl, $useDBStatements)
        
        Add-Content -path $outputFilePath -value $useDBStatements -Encoding Unicode
        
        #set the output filename for the script objects
        $dropScriptObject.Options.Filename = $outputFilePath    
        $createScriptObject.Options.Filename = $outputFilePath
        
        #first get a list of the objects sorted by their dependencies in drop order
        
        echo "Sorting dependencies for drops"
        
        $tree = $dropScriptObject.DiscoverDependencies($found_objects,  $false)        
        $depwalker = New-Object "Microsoft.SqlServer.Management.SMO.DependencyWalker"
        $depcoll = $depwalker.WalkDependencies($tree)

        #script the drops
        echo "Scripting drops"
        
        $dropScriptObject.FilterCallbackFunction = $null #opt-out of filtering
        
        #drop foreign keys
        $dropScriptObject.Script($found_foreignKeys)        
        #drop triggers
        $dropScriptObject.Script($found_triggers)
        #drop indexes
        $dropScriptObject.Script($found_indexes)
        
        #===
        #SPECIAL REGION - ANY SCRIPTING DONE IN THIS BLOCK WILL USE FILTERING
        #===
        
        #dropping objects in dependency sorted order
        $dropScriptObject.FilterCallbackFunction = $filterCallbackFunction #opt into filtering
        $dropScriptObject.ScriptWithList($depcoll)
        $dropScriptObject.FilterCallbackFunction = $null #opt-out of filtering
        
        #===
        #END
        #===
        
        if($found_assemblies.Count -gt 0) #script drop assemblies if any were found
        {
            #drop assemblies
            $dropScriptObject.Script($found_assemblies)   
        }
        
        if($includeTables -eq $true) #only include schemas if tables are included
        {
            $dropScriptObject.Script($found_schemas) #then drop the schemas
        }
        
        if($rolesToScript.Count -gt 0)
        {
            $dropScriptObject.Script($found_roles) #finally drop the roles
        }
        
        echo "Finished scripting drops..."
        
        #get a list of the objects sorted by their dependencies in create order
        
        echo "Sorting dependencies for creates"        
        $tree = $createScriptObject.DiscoverDependencies($found_objects,  $true)            
        $depwalker = New-Object "Microsoft.SqlServer.Management.SMO.DependencyWalker"    
        $depcoll = $depwalker.WalkDependencies($tree)
        
        #script the creates
        echo "Scripting creates"
        
        if($includeTables -eq $true) #only include schemas if tables are included
        {
            $createScriptObject.Script($found_schemas) #create the schemas
        }
        
        if($rolesToScript.Count -gt 0)
        {
            $createScriptObject.Script($found_roles) #create the roles
        }
        
        if($found_assemblies.Count -gt 0)
        {
            $createScriptObject.Script($found_assemblies) #create any found assemblies
        }        
                
        #===
        #SPECIAL REGION - ANY SCRIPTING DONE IN THIS BLOCK WILL USE FILTERING
        #===
        
        #creating objects in dependency sorted order
        $createScriptObject.FilterCallbackFunction = $filterCallbackFunction #opt into filtering
        $createScriptObject.ScriptWithList($depcoll)
        $createScriptObject.FilterCallbackFunction = $null #opt-out of filtering
        
        #===
        #END
        #===
        
        #script indexes
        $createScriptObject.Script($found_indexes)

        #script triggers
        $createScriptObject.Script($found_triggers)
        
        #script foreign keys
        $createScriptObject.Script($found_foreignKeys)
        
        echo "Finished scripting..."
    }

    #complete final cleanup
    echo "Completing final cleanup..."
    echo $0
    #cleanup completed
}