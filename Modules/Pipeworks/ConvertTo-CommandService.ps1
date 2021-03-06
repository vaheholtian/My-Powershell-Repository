function ConvertTo-CommandService
{
    <#
    .Synopsis
        Exports an ASP.NET handler to interact with a PowerShell command
    .Description
        Take a PowerShell function with nice help and turns it into a web page and REST service.                            
    .Link
        ConvertTo-ModuleService
    .Example
        function New-Password {                
            #.Synopsis
            # Generates a new password
            #.Description
            #Generates a new password in one line of somewhat creative PowerShell script.  
            #Pipes all available characters into Get-Random, and then joins those characters
            #.Example
            #New-Password
            #.Example
            #New-Password -Length 16        
            param(
            # The length of the password 
            #|Default 8
            [int]$length=8
            )          
            
            process {
                ([char[]](33..126) | Get-Random -Count $length) -join ''
            }                  
        }
        
        
        ConvertTo-CommandService -Command (Get-Command New-Password) -RunOnline -RunWithoutInput 
    
    #>
    [CmdletBinding(DefaultParameterSetName='CommandInfo')]   
    [OutputType([Nullable],[string])] 
    param(
    # The command to convert into a service.  
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,ParameterSetName='CommandInfo')]
    [Management.Automation.CommandInfo]
    $Command,
    
    # A scriptblock containing functions that will be embedded in the command handler
    [Parameter(Mandatory=$true,ParameterSetName='ScriptBlock', ValueFromPipeline=$true,Position=0)]
    [ScriptBlock]
    $ScriptBlock,    
    
    # A friendly name for the service
    [Parameter(Position=1)]
    [string]
    $FriendlyName,        

    # The order of the displayed parameters
    [Parameter(Position=2)]
    [string[]]$ParameterOrder,

            
    # If set, allows the command to be run interactively.
    [Switch]$RunOnline,
    
    # If set, allows the command to be run without any parameters.  This is especially useful for Get- commands.
    [switch]$RunWithoutInput,
    
    # If set, these parameters will be hidden from a command handler's input and output parameters.  
    # They will still be visible in help.
    [Parameter(Position=3)]
    [Alias('DenyParameter')]
    [string[]]$HideParameter,        
    
    # The ID to use for Google Analytics tracking
    [Parameter(Position=4)]
    [string]
    $AnalyticsId,
    
    # The AdSenseID used to monetize the command with Google AdSense
    [Parameter(Position=5)]
    [string]
    $AdSenseID,
    
    # The AdSlotId used to monetize the command with Google AdSense
    [Parameter(Position=6)]
    [string]
    $AdSlot,

    # The directory where the output files will be placed
    [string]
    $OutputDirectory,
    
    # If set, will overwrite existing files in the output directory
    [Switch]
    $Force,
    
    # If set, will link the command page to a parent page 
    [Uri]
    $ParentPage,

    # If SessionThrottle is set, the request handler will wait for at least the -SessionThrottle before 
    # allowing the user to re-run the command.  This can be useful in mitigating Denial of Service attacks
    # as well as providing an avenue to upsell (i.e. a free user can run a command once a minute, where as a premium user can run requests without the throttle)
    [Timespan]
    $SessionThrottle = "0:0:0",
        
    # If set, allows the command to be downloaded
    [switch]$AllowDownload,
    
    # If set, will cache the results of the command in the session.  If the user runs the same command 
    # with the same parameters as long as they are logged in, CacheInSession will supply the previous
    # result, instead of re-running the command.  The ServiceUrl/?SessionCacheId=$SessionCacheItemId 
    # will also render that item directly.
    [Switch]$CacheInSession,
    
    # If set, escapes the output from the command, so it can be embedded into a webpage
    [switch]$EscapeOutput,
    
    # The CSS Style section to use for the page
    [Hashtable]$Style,
    
    # Any config settings
    [Hashtable]$ConfigSetting,
    
    # If set, will output the results of the command without encasing it in a form
    [Switch]$PlainOutput,
    
    # If set, will output the results of the command with a particular content type
    [string]$ContentType,
    
    # Sets the method used for the web form.  By default, POST is used, but Get is required if the command outputs binary data (like image streams)
    [ValidateSet('POST', 'GET')]
    [string]$Method = "POST",
    
    # If set, will not add sharing links to the page 
    [Switch]$AntiSocial,
    
    # The Command Service URL.  
    # If this is not set, this will automatically be the url to the command directory.
    [Uri]$CommandServiceUrl,
    
    # The Web Front End for a command, declared in HTML.  Setting a Web Front End will override the default front end with any web page.
    [String]$WebFrontEnd,
    
    # The Mobile Web Front End for a command, declared in HTML.  Setting a Mobile Web Front End will override the default front end with any web page.
    [String]$MobileWebFrontEnd,
    
    # The front end for an android UI.  
    # For a complete list of elements available in the andorid UI, go to:
    # http://developer.android.com/guide/topics/ui/layout-objects.html    
    [string]$AndroidFrontEnd,
    
    # The front end for an iOS UI, declared in XIB
    [string]$iOsFrontEnd,
    
    # The front end for a Windows Mobile UI, declared in XAML
    [string]$WindowsMobileFrontEnd,
    
    # The front end for a Metro UI, declared in XAML
    [string]$MetroFrontEnd,
    
    # A table of parameters that will get their value from a cookie
    [Hashtable]$CookieParameter = @{},
    
    # If set, will save the output in a cookie.
    [string]$SaveInCookie,

    # A table of parameter URL aliases.  These allow URLs to the sevice to become shorter.
    [Hashtable]$ParameterAlias= @{},
 
    # Default values for the parameters
    [Alias('DefaultParameter')]
    [Hashtable]$ParameterDefaultValue = @{},
    
    # Parameters that are taken from the web.config settings
    [Alias('SettingParameter')]
    [Hashtable]$ParameterFromSetting= @{},
    
    
    # Parameters that are taken from the user settings
    [Alias('UserParameter')]
    [Hashtable]$ParameterFromUser= @{},
    
    # Any additional commands that the command can be piped into.    
    # In the Sandbox service, these commands will be allowed as well
    [string[]]$PipeInto,
    
    # If set, will allow the command to be run in a sandbox
    [Switch]$RunInSandBox,
    
    # The margin on either side of the module content.  Defaults to 7.5%.
    [ValidateRange(0,100)]
    [Double]
    $MarginPercent = 7.5,
    
    # The margin on the left side of the module content. Defaults to 7.5%.
    [ValidateRange(0,100)]
    [Double]
    $MarginPercentLeft = 7.5,
    
    # The margin on the left side of the module content. Defaults to 7.5%.
    [ValidateRange(0,100)]
    [Double]
    $MarginPercentRight = 7.5,
    
    # If set, will only allow logged-in users to run the command
    [Switch]
    $RequireLogin,
    
    # If set, will require an app key to run the command.  Logged in users will automatically use their app key
    [Switch]
    $RequireAppKey,
    
    # If set, will track uses of an appkey.
    [string]
    $UserTable,
    
    [string]
    $UserPartition,
    
    # If set, will track parameters the user supplied for a command, and when they ran it.
    [switch]
    $KeepUserHistory,
    
    [switch]
    $KeepHistory,
    
    [switch]
    $KeepResult,
    
    # If set, will track uses of the command.
    [string]
    $UseTrackingTable,
    
    # If set, will track unique properties of the output, such as the number of times an item with a particular ID is output.   
    [string[]]
    $TrackProperty,
    
    # If set, will track unique parameters in the input, such as the number of times an input value is used
    [string[]]
    $TrackParameter,        
        
    # The name of the web.config setting containing the storage account name.  Required for tracking.
    [string]
    $StorageAccountNameSetting = 'AzureStorageAccountName',
    
    # The name of the web.config setting containing the storage account key. Required for tracking.
    [string]
    $StorageAccountKeySetting = 'AzureStorageAccountKey',
    
    # A table of costs per run by locale
    [Hashtable]
    $CostPerRun,
    
    # A location to redirect to when the command is complete.
    [Uri]
    $RedirectTo,
    
    # If set, will redirect the browser to the URL returned in the result.
    [Switch]
    $RedirectToResult,
    
    # The amount of time to wait before redirecting (by default, no time)
    [Uri]
    $RedirectIn,
    
    # The cost to run the command
    [Double]
    $Cost,
    
    # A cost factor table
    [Hashtable]
    $CostFactor= @{},
    
    # If set, will email output of the command to yourself (requires appkey or login)
    [Switch]
    $EmailOutputToSelf,
    
    # If set, will run commands in a runspace for each user.  If not set, users will run in a pool
    [Switch]
    $IsolateRunspace,
    
    # The size of the runspace pool that will handle request.  
    [Uint16]
    $PoolSize = 1
    )
    
    
    begin {
    
    
        function issEmbed($cmd) {
@"
        SessionStateFunctionEntry $($cmd.Name.Replace('-',''))Command = new SessionStateFunctionEntry(
            "$($cmd.Name)", @"
            $($cmd.Definition.ToString().Replace('"','""'))
            "
        );
        iss.Commands.Add($($cmd.Name.Replace('-',''))Command);
"@
        }
    
        $functionBlackList = 65..90 | ForEach-Object -Begin {
            "ImportSystemModules", "Disable-PSRemoting", "Restart-Computer", "Clear-Host", "cd..", "cd\\", "more"
        } -Process { 
            [string][char]$_ + ":" 
        }


        if (-not $script:FunctionsInEveryRunspace) {
            $script:FunctionsInEveryRunspace = 'ConvertFrom-Markdown', 'Get-Web', 'Get-WebConfigurationSetting', 'Get-FunctionFromScript', 'Get-Walkthru', 
                'Get-WebInput', 'Request-CommandInput', 'New-Region', 'New-RssItem', 'New-WebPage', 'Out-Html', 'Out-RssFeed', 'Send-Email',
                'Write-Ajax', 'Write-Css', 'Write-Host', 'Write-Link', 'Write-ScriptHTML', 'Write-WalkthruHTML', 
                'Write-PowerShellHashtable', 'Compress-Data', 'Expand-Data', 'Import-PSData', 'Export-PSData'


        }
        $embedSection = foreach ($func in Get-Command -Module Pipeworks -Name $FunctionsInEveryRunspace -CommandType Function) {
            issEmbed $func
        }
        
        # Web handlers are essentially embedded C#, compiled on their first use.   The webCommandSequence class,
        # defined within this quite large herestring, is a bridge used to invoke PowerShell within a web handler.        
        $webCmdSequence = @"
public class WebCommandSequence {
    public static InitialSessionState InitializeRunspace(string[] module) {
        InitialSessionState iss = InitialSessionState.CreateDefault();
        
        if (module != null) {
            iss.ImportPSModule(module);
        }
        $embedSection
        
        string[] commandsToRemove = new String[] { "$($functionBlacklist -join '","')"};
        foreach (string cmdName in commandsToRemove) {
            iss.Commands.Remove(cmdName, null);
        }
        
        
        return iss;
        
    }
    
    public static void InvokeScript(string script, 
        HttpContext context, 
        object arguments,
        bool throwError,
        bool shareRunspace) {
        
        PowerShell powerShellCommand = PowerShell.Create();
        bool justLoaded = false;
        Runspace runspace;
        RunspacePool runspacePool;
        PSInvocationSettings invokeWithHistory = new PSInvocationSettings();
        invokeWithHistory.AddToHistory = true;
        PSInvocationSettings invokeWithoutHistory = new PSInvocationSettings();
        invokeWithHistory.AddToHistory = false;
        
        if (! shareRunspace) {

            if (context.Session["UserRunspace"] == null) {                        
                justLoaded = true;
                InitialSessionState iss = WebCommandSequence.InitializeRunspace(null);
                Runspace rs = RunspaceFactory.CreateRunspace(iss);
                rs.ApartmentState = System.Threading.ApartmentState.STA;            
                rs.ThreadOptions = PSThreadOptions.ReuseThread;
                rs.Open();                
                powerShellCommand.Runspace = rs;
                context.Session.Add("UserRunspace",powerShellCommand.Runspace);
                powerShellCommand.
                    AddCommand("Set-ExecutionPolicy", false).
                    AddParameter("Scope", "Process").
                    AddParameter("ExecutionPolicy", "Bypass").
                    AddParameter("Force", true).
                    Invoke(null, invokeWithoutHistory);
                powerShellCommand.Commands.Clear();
            }

        

            runspace = context.Session["UserRunspace"] as Runspace;
            if (context.Application["Runspaces"] == null) {
                context.Application["Runspaces"] = new Hashtable();
            }
            if (context.Application["RunspaceAccessTimes"] == null) {
                context.Application["RunspaceAccessTimes"] = new Hashtable();
            }
            if (context.Application["RunspaceAccessCount"] == null) {
                context.Application["RunspaceAccessCount"] = new Hashtable();
            }

            Hashtable runspaceTable = context.Application["Runspaces"] as Hashtable;
            Hashtable runspaceAccesses = context.Application["RunspaceAccessTimes"] as Hashtable;
            Hashtable runspaceAccessCounter = context.Application["RunspaceAccessCount"] as Hashtable;

            if (! runspaceAccessCounter.Contains(runspace.InstanceId.ToString())) {
                runspaceAccessCounter[runspace.InstanceId.ToString()] = (int)0;
            }
            runspaceAccessCounter[runspace.InstanceId.ToString()] = ((int)runspaceAccessCounter[runspace.InstanceId.ToString()]) + 1;

            runspaceAccesses[runspace.InstanceId.ToString()] = DateTime.Now;


                    
            if (! runspaceTable.Contains(runspace.InstanceId.ToString())) {
                runspaceTable[runspace.InstanceId.ToString()] = runspace;
            }


            runspace.SessionStateProxy.SetVariable("Request", context.Request);
            runspace.SessionStateProxy.SetVariable("Response", context.Response);
            runspace.SessionStateProxy.SetVariable("Session", context.Session);
            runspace.SessionStateProxy.SetVariable("Server", context.Server);
            runspace.SessionStateProxy.SetVariable("Cache", context.Cache);
            runspace.SessionStateProxy.SetVariable("Context", context);
            runspace.SessionStateProxy.SetVariable("Application", context.Application);
            runspace.SessionStateProxy.SetVariable("JustLoaded", justLoaded);
            runspace.SessionStateProxy.SetVariable("IsSharedRunspace", false);
            powerShellCommand.Runspace = runspace;
            powerShellCommand.AddScript(@"
`$timeout = (Get-Date).AddMinutes(-20)
`$oneTimeTimeout = (Get-Date).AddMinutes(-1)
foreach (`$key in @(`$application['Runspaces'].Keys)) {
    if ('Closed', 'Broken' -contains `$application['Runspaces'][`$key].RunspaceStateInfo.State) {
        `$application['Runspaces'][`$key].Dispose()
        `$application['Runspaces'].Remove(`$key)
        continue
    }
    
    if (`$application['RunspaceAccessTimes'][`$key] -lt `$Timeout) {
        
        `$application['Runspaces'][`$key].CloseAsync()
        continue
    }    
}
").Invoke();

            powerShellCommand.Commands.Clear();
            powerShellCommand.AddScript(script, false);
            
            if (arguments is IDictionary) {
                powerShellCommand.AddParameters((arguments as IDictionary));
            } else if (arguments is IList) {
                powerShellCommand.AddParameters((arguments as IList));
            }
            Collection<PSObject> results = powerShellCommand.Invoke();        

        } else {
            if (context.Application["RunspacePool"] == null) {                        
                justLoaded = true;
                InitialSessionState iss = WebCommandSequence.InitializeRunspace(null);
                RunspacePool rsPool = RunspaceFactory.CreateRunspacePool(iss);
                rsPool.SetMaxRunspaces($PoolSize);
                rsPool.ApartmentState = System.Threading.ApartmentState.STA;            
                rsPool.ThreadOptions = PSThreadOptions.ReuseThread;
                rsPool.Open();                
                powerShellCommand.RunspacePool = rsPool;
                context.Application.Add("RunspacePool",rsPool);
                
                // Initialize the pool
                Collection<IAsyncResult> resultCollection = new Collection<IAsyncResult>();
                for (int i =0; i < $poolSize; i++) {
                    PowerShell execPolicySet = PowerShell.Create().
                        AddCommand("Set-ExecutionPolicy", false).
                        AddParameter("Scope", "Process").
                        AddParameter("ExecutionPolicy", "Bypass").
                        AddParameter("Force", true);
                    execPolicySet.RunspacePool = rsPool;
                    resultCollection.Add(execPolicySet.BeginInvoke());
                }
                
                foreach (IAsyncResult lastResult in resultCollection) {
                    if (lastResult != null) {
                        lastResult.AsyncWaitHandle.WaitOne();
                    }
                }
                
                
                
                
                
                
                powerShellCommand.Commands.Clear();
            }
            

            powerShellCommand.RunspacePool = context.Application["RunspacePool"] as RunspacePool;
            
            
            string newScript = @"param(`$Request, `$Response, `$Server, `$session, `$Cache, `$Context, `$Application, `$JustLoaded, `$IsSharedRunspace, [Parameter(ValueFromRemainingArguments=`$true)]`$args)
            
            
            " + script;            
            powerShellCommand.AddScript(newScript, false);
            
            if (arguments is IDictionary) {
                powerShellCommand.AddParameters((arguments as IDictionary));
            } else if (arguments is IList) {
                powerShellCommand.AddParameters((arguments as IList));
            }
            
            powerShellCommand.AddParameter("Request", context.Request);
            powerShellCommand.AddParameter("Response", context.Response);
            powerShellCommand.AddParameter("Session", context.Session);
            powerShellCommand.AddParameter("Server", context.Server);
            powerShellCommand.AddParameter("Cache", context.Cache);
            powerShellCommand.AddParameter("Context", context);
            powerShellCommand.AddParameter("Application", context.Application);
            powerShellCommand.AddParameter("JustLoaded", justLoaded);
            powerShellCommand.AddParameter("IsSharedRunspace", true);
            Collection<PSObject> results = powerShellCommand.Invoke();        
            
                        
            
            
        }
        
        
      
        foreach (ErrorRecord err in powerShellCommand.Streams.Error) {
            if (throwError) {
                if (err.Exception != null) {                   
                    if (err.Exception.GetType().GetProperty("ErrorRecord") != null) {
                        ErrorRecord errRec = err.Exception.GetType().GetProperty("ErrorRecord").GetValue(err.Exception, null) as ErrorRecord;
                        if (errRec != null) {
                            //context.Response.StatusCode = (int)System.Net.HttpStatusCode.PreconditionFailed;
                            //context.Response.StatusDescription = errRec.InvocationInfo.PositionMessage;
                            context.Response.Write("<span class='ui-state-error' color='red'>" + err.Exception.ToString() + errRec.InvocationInfo.PositionMessage + "</span><br/>");
                        }                        
                        //context.Response.Flush();           
                    } else {
                        context.AddError(err.Exception);            
                    }
                }
            } else {
                context.Response.Write("<span class='ui-state-error'  color='red'>" + err.ToString() + "</span><br/>");
            }            
        }
        
        if (powerShellCommand.InvocationStateInfo.Reason != null) {
            if (throwError) {                
                context.AddError(powerShellCommand.InvocationStateInfo.Reason);
            } else {                
                context.Response.Write("<span class='ui-state-error' color='red'>" + powerShellCommand.InvocationStateInfo.Reason + "</span>");
            }
        }

        powerShellCommand.Dispose();
    
    }

}
"@      

        # Writing the handler for a command actually involves writing several handlers, 
        # so we'll make this it's own little inline tool.  
        $writeSimpleHandler = {param($cSharp, $webCommandSequence = $webCmdSequence, [Switch]$ShareRunspace, [Uint16]$PoolSize) 
@"
<%@ WebHandler Language="C#" Class="Handler" %>
<%@ Assembly Name="System.Management.Automation, Version=1.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" %>
using System;
using System.Web;
using System.Web.SessionState;
using System.Collections;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Management.Automation;
using System.Management.Automation.Runspaces;

$webCommandSequence

public class Handler : IHttpHandler, IRequiresSessionState  {        
    public void ProcessRequest (HttpContext context) {
        $cSharp
    }
    
    public bool IsReusable {
    	get {
    	    return true;
    	}
    }
}    

"@    
}
    }
    
    process {           
        if ($psCmdlet.ParameterSetName -eq 'ScriptBlock') {
            $func = Get-FunctionFromScript -ScriptBlock $ScriptBlock | Select-Object -First 1 
            . ([ScriptBlock]::Create($func))
            $matched = $func -match "function ((\w+-\w+)|(\w+))"
            if ($matched -and $matches[1]) {
                $command=Get-Command $matches[1]
            }                        
        }
        
        
        if ($CostPerRun -and (-not ($RequireLogin -or $RequireAppKey))) {
            $RequireLogin = $true
        }
        if (-not $outputDirectory) {
            $outputDirectory = "C:\inetpub\wwwroot\"            

            if (-not $command.Module) {

                $outputDirectory = Join-Path $outputDirectory "$($command.Name)"
            } else {
                $outputDirectory = Join-Path $outputDirectory "$($command.Module)\$($command.Name)"
            }
        } 
        if (-not $Style) {
            $Style = @{
                Body = @{
                    'Font-Family' = "Gisha, 'Franklin Gothic Book', Garamond"
                }                
            }
        }
        
        if (-not $psBoundParameters.MarginPercent -or ($psBoundParameters.MarginPercentLeft -and $psBoundParameters.MarginPercentRight)) {
            $marginPercentLeftString = "7.5%"
            $marginPercentRightString= "7.5%"
        } else {
            if ($psBoundParameters.MarginPercent) {
                $marginPercentLeftString = $MarginPercent + "%"
                $marginPercentRightString = $MarginPercent + "%"
            } else {
                $marginPercentLeftString = $MarginPercentLeft+ "%"
                $marginPercentRightString = $MarginPercentRight+ "%"
            }
        }         
        #region Extract Pipeworks Directives
        $help = $command | Get-Help
        if ($help -isnot [string] -and $help.alertSet.alert) {        
            $pipeworksCommandDirectives = $help.alertset.alert[0].text -split ("`n") |
                Where-Object { $_ -like "|*" } |
                ForEach-Object -Begin {
                    $r = @{}
                } {
                    $directiveEnd= $_.IndexofAny(": `n`r".ToCharArray())
                    $name, $rest = $_.Substring(1, $directiveEnd -1).Trim(), $_.Substring($directiveEnd +1).Trim()
                    $r.$Name = $rest
                } -End {
                    $r
                }
        }
        
        if ($pipeworksCommandDirectives.HideParameterOnline) {
            $hideParameter += ($pipeworksCommandDirectives.HideParameterOnline -split ",") | %{ $_.Trim() }
            $hideParameter  = $hideParameter | Select-Object -Unique
        }
        #endregion Extract Pipeworks Directives

        #region use callstack peeking to conditionally skip creating a directory
        $isCalledFromExportModuleHandler = Get-PSCallStack | ? { $_.Command -eq 'ConvertTo-ModuleService' }
        if (-not $isCalledFromExportModuleHandler) {        
            if ($psCmdlet.ParameterSetName -ne 'ScriptBlock') {
                if ((Test-Path $outputDirectory) -and (-not $force)) {
                    Write-Error "$outputDirectory exists, use -Force to overwrite"
                    return
                }                
            }                   
        }
        #endregion use callstack peeking to conditionally skip creating a directory
        
        Write-Progress "Creating Command Handler" "$outputDirectory"        
        if ($psCmdlet.ParameterSetName -ne 'ScriptBlock') {
            Remove-Item $outputDirectory -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable Issues
            if ($issues) { 
                Write-Verbose "$($issues | Out-String)"
            }
            $null = New-Item -Path $outputDirectory -Force -ItemType Directory        
            $null = New-Item -Path "$outputDirectory\bin" -Force -ItemType Directory        
        }
        
        # If this did not come from a module, or it didn't come from a dynamic script block, write a file to disk
        if (-not $command.Module -and (-not $psBoundParameters.ContainsKey('ScriptBlock'))) {
            # The command is a function, so write a copy to disk
            if ($command -is [Management.Automation.FunctionInfo]) {
        @"
function $($command.Name) {
    $($command.Definition)
}
"@ | Set-Content "$outputDirectory\bin\$($command.Name).ps1"            
            
            }
        }



        #region EmbedCommand
        $embedCommand = if (-not $command.Module) { 
            if (-not $psBoundParameters.ContainsKey('ScriptBlock')) {
         @"
`$searchDirectory = "`$(Split-Path `$Request['PATH_TRANSLATED'])"
`$searchOrder = @()
while (`$searchDirectory) {
    `$searchOrder += "`$searchDirectory\bin\$($command.Name).ps1"
    if (Test-Path "`$searchDirectory\bin\$($command.Name).ps1") {
        . "`$searchDirectory\bin\$($command.Name).ps1" 
        break
    }
    `$searchDirectory  = `$searchDirectory | Split-Path -ErrorAction SilentlyContinue
}

"@
        } else {
@"
function $($command.Name) {
    $($command.Definition)
}
"@ 
        }
        } elseif ($psCmdlet.ParameterSetName -eq 'ScriptBlock') {
@"
function $($command.Name) {
    $($command.Definition)
}
"@ 

        } else {             
            if (-not $isCalledFromExportModuleHandler) {
                Write-Progress "Copying $($command.Module.name)" " "
                $moduleDir = (Split-Path $command.Module.Path)
                Get-ChildItem -Path $moduleDir -Recurse -Force |
                    Where-Object { -not $_.PsIsContainer } |
                    Copy-Item -Destination {
                        if (-not $_.PsIsContainer) {                            
                            $relativePath = $_.FullName.Replace("$moduleDir\", "")
                            $newPath = "$outputDirectory\bin\$($command.Module.Name)\$relativePath"
                            if (-not (Test-Path "$outputDirectory\bin\$($req.Name)\")) {
                                $null = New-Item -ItemType Directory -Path "$outputDirectory\bin\$($req.Name)" -Force
                            }
                            Write-Progress "Copying $($req.name)" "$newPath"
                            $newPath 
                        } else {
                            return $null 
                        }
                    } -Force #-ErrorAction SilentlyContinue
            }
            
            $importChunk = @"
`$searchDirectory = "`$(Split-Path `$Request['PATH_TRANSLATED'])"
`$searchOrder = @()
while (`$searchDirectory) {
    `$searchOrder += "`$searchDirectory\bin\$($command.Module.Name)"
    if (Test-Path "`$searchDirectory\bin\$($command.Module.Name)") {
        #ImportRequiredModulesFirst
        Import-Module "`$searchDirectory\bin\$($command.Module.Name)\$($command.Module.Name)" 
        break
    }
    `$searchDirectory = `$searchDirectory | Split-Path   
}
"@

            if ($command.Module.RequiredModules) {

                $importRequired = foreach ($req in $command.Module.RequiredModules) {
                    # Make this callstack aware later                    
                    if (-not $isCalledFromExportModuleHandler) {
                    $moduleDir = (Split-Path $req.Path)
                    Get-ChildItem -Path $moduleDir -Recurse -Force |
                        Where-Object { -not $_.PsIsContainer } |
                        Copy-Item -Destination {
                            if (-not $_.PsIsContainer) {                            
                                $relativePath = $_.FullName.Replace("$moduleDir\", "")
                                $newPath = "$outputDirectory\bin\$($req.Name)\$relativePath"
                                if (-not (Test-Path "$outputDirectory\bin\$($req.Name)\")) {
                                    $null = New-Item -ItemType Directory -Path "$outputDirectory\bin\$($req.Name)" -Force
                                }
                                Write-Progress "Copying $($req.name)" "$newPath"
                                $newPath 
                            } else {
                                return $null 
                            }
                        } -Force #-ErrorAction SilentlyContinue
                    }

                    $reqDir = Split-Path $req.Path 
                    "$(' ' * 8)Import-Module `"`$searchDirectory\bin\$($req.Name)\$($req.Name)`""
                }               
                $importChunk = $importChunk.Replace("#ImportRequiredModulesFirst", 
                    $importRequired -join ([Environment]::NewLine))
            }
            $importChunk            
        }       
        
        
        
        $cmdRef = if ($command.Module -and -not $psboundParameters.ScriptBlock -and $command -is [Management.Automation.FunctionInfo]) {
"`$cmd = Get-Command -Module '$($command.Module.name)' -CommandType Function -Name '$($command.Name)'"
        } else {
"`$cmd = Get-Command -Name '$($command.Name)'"
        }        
        $embedCommand = $embedCommand + @"

$cmdRef
if (-not `$cmd) { `$response.Write(`$searchOrder -join '<BR/>'); `$response.Flush()  } 
`$cmdMd = [Management.Automation.CommandMetaData]`$cmd
`$cssStyle = $(Write-PowerShellHashtable $Style)
`$HideParameter = '$($HideParameter -join "','")'

`$cmdOptions = @{
    runWithoutInput = $(if ($runWithoutInput) { '$true' } else { '$false' })
    runOnline = $(if ($runOnline) { '$true' } else { '$false' })
    RunInSandBox = $(if ($RunInSandBox) { '$true' } else { '$false' })
    allowDownload = $(if ($allowDownload) { '$true' } else { '$false' })
    ParameterDefaultValue = $(Write-PowerShellHashtable $ParameterDefaultValue)
    ParameterFromSetting = $(Write-PowerShellHashtable $ParameterFromSetting)
    ParameterFromUser = $(Write-PowerShellHashtable $ParameterFromUser)
    CookieParameter = $(Write-PowerShellHashtable $CookieParameter)
    saveInCookie = '$saveInCookie'
    parameterAliases = $(Write-PowerShellHashtable $ParameterAlias)
    cacheInSession = $(if ($cacheInSession) { '$true' } else { '$false' })
    sessionThrottle = [Timespan]::FromMilliseconds($($SessionThrottle.TotalMilliseconds))
    escapeOutput = $(if ($escapeOutput) { '$true' } else { '$false' })
    plainOutput = $(if ($plainOutput) { '$true' } else { '$false' })
    requireLogin = $(if ($requireLogin) { '$true' } else { '$false' })
    requireAppKey = $(if ($requireAppKey) { '$true' } else { '$false' })
    useTrackingTable = '$(if ($useTrackingTable) { $useTrackingTable } else { '' })'
    KeepUserHistory = $(if ($keepUserHistory) { '$true' } else { '$false' })
    KeepHistory = $(if ($keepHistory) { '$true' } else { '$false' })
    KeepResult = $(if ($KeepResult) { '$true' } else { '$false' })
    UserTable = '$(if ($userTable) { $userTable } else { '' })'
    UserPartition= '$(if ($UserPartition) { $UserPartition} else { '' })'
    TrackProperty = '$(if ($trackProperty) { $trackproperty -join "','" } else { '' })'
    TrackParameter= '$(if ($TrackParameter) { $TrackParameter -join "','" } else { '' })'
    StorageAccountNameSetting = '$(if ($StorageAccountNameSetting) { $StorageAccountNameSetting } else { '' })'
    StorageAccountKeySetting = '$(if ($StorageAccountKeySetting) { $StorageAccountKeySetting } else { '' })'
    contentType = '$contentType'
    method = '$method'
    parentPage = '$parentPage'    
    antiSocial = $(if ($antiSocial) { '$true' } else { '$false' })
    moduleUrl = '$moduleUrl'
    CommandServiceUrl = '$commandServiceUrl'
    AllowInPipeline = @('$($PipeInto -join "','")')
    MarginPercentLeft = '$MarginPercentLeftString'
    MarginPercentRight = '$MarginPercentRightString'
    Cost = '$Cost'
    CostFactor = $(Write-PowerShellHashtable -InputObject $costFactor)
    RedirectToResult = $(if ($RedirectToResult) { '$true' } else { '$false' })
    RedirectTo = '$RedirectTo'
    
    WebFrontEnd = @"
$webFrontEnd
`"@
    MobileWebFrontEnd = @"
$mobileWebFrontEnd
`"@
    AndroidFrontEnd = @"
$androidFrontEnd
`"@       
    iOSFrontEnd = @"
$iOSFrontEnd
`"@
    MetroFrontEnd = @"
$MetroFrontEnd
`"@
    WindowsMobileFrontEnd = @"
$WindowsMobileFrontEnd
`"@
    WPFFrontEnd = @"
$WPFFrontEnd
`"@
    SilverlightFrontEnd = @"
$SilverlightFrontEnd
`"@
}

# Clear the front ends that weren't there.  
# A simple if -not won't work because of newlines
if (-not `$cmdOptions.WebFrontEnd.Trim()) {
    `$null = `$cmdOptions.Remove('WebFrontEnd')
}

if (-not `$cmdOptions.MobileWebFrontEnd.Trim()) {
    `$null = `$cmdOptions.Remove('MobileWebFrontEnd')
}

if (-not `$cmdOptions.AndroidFrontEnd.Trim()) {
    `$null = `$cmdOptions.Remove('AndroidFrontEnd')    
}

if (-not `$cmdOptions.MetroFrontEnd.Trim()) {
    `$null = `$cmdOptions.Remove('MetroFrontEnd')
}

if (-not `$cmdOptions.WindowsMobileFrontEnd.Trim()) {
    `$null = `$cmdOptions.Remove('WindowsMobileFrontEnd')
}

if (-not `$cmdOptions.SilverlightFrontEnd.Trim()) {
    `$null = `$cmdOptions.Remove('SilverlightFrontEnd')
}

if (-not `$cmdOptions.WPFFrontEnd.Trim()) {
    `$null = `$cmdOptions.Remove('WPFFrontEnd')
}


"@          
        
        #endregion EmbedCommand        
        
        
        #region Example Handler 
        
        #ToDo: Implement Example Handler 
        # The example handler will do it's darnest to show examples from PowerShell well
        # It will try to create a clickable single-item handler for the command, and, if that fails,
        # Failing that, it will try to treat the example as a walkthru.  
        # Failing that, it will be converted into a scriptblock and rendered as colorized HTML
        # Failing that, it will be rendered as preformatted text.
        
        function Get-SinglePipelineExample([PSObject]$Help) {
            foreach ($ex in $Help.Examples.example) {
                try { 
                    $remarksText = ($ex.remarks | Select-Object -ExpandProperty Text) -join ([Environment]::NewLine)
                    
                    $exText = $ex.code + $(if ($remarksText -notlike "*-----------*") {
                        $remarksText 
                    } else {"" } )
                    
                    $null = [ScriptBlock]::Create(
                        $exText
                    ).GetPowerShell()    
                    
                    $exText 
                } catch {
                    
                    continue
                }
            } 
        }

        #endregion
        

        #region Confirm Script Handler
        $confirmScriptHandler = {
if (-not $cmdOptions.UseTrackingTable -and $cmdOptions.ExecutionQueueTable) {
    Write-Error "Use tracking must be enabled for script confirmation"
    return
}
$storageAccount = Get-WebConfigurationSetting -Setting $cmdOptions.StorageAccountNameSetting
$storageKey = Get-WebConfigurationSetting -Setting $cmdOptions.StorageAccountKeySetting
$trackingTable = Get-AzureTable -TableName $cmdOptions.UseTrackingTable -StorageAccount $storageAccount -StorageKey $storageKey
$confirm = $request['Confirm']

$sb  =[scriptblock]::Create("`$_.RowKey -eq '$confirm'")
$pendingExecution = Search-AzureTable -TableName $cmdOptions.ExecutionQueueTable -Where $sb

        }         
        #endregion Confirm Script Handler
        
        #region Sandbox Handler
        $sandboxHandler = {
$sandboxAllowed = $cmdOptions.RunInSandbox
if (-not $sandboxAllowed) {
    
}
$allowInPipeline = @($cmdOptions.AllowInPipeline) + 
    $cmd.Name + 
    "Add-Member", "Sort-Object", "Select-Object", "Group-Object", "Measure-Object", "Select-String", "Select-Xml" |
    Select-Object -Unique

$webPage = New-WebPage -Title "$cmd Sandbox" -AnalyticsID $cmdOptions.AnalyticsId -UseJQueryUI -PageBody @"
<form method="POST">
<h1>$($cmd) Sandbox</h1>
<h4>Allowed Commands:$($allowInPipeline -join ' | ')</h4>

<textarea name='SandboxScript' rows='20' cols='120' width='100%'>
</textarea>
<br/>
<input type='submit' value='Run' />
</form>
"@
$response.Write("$webPage")

}
        
        
        $sandboxScriptHandler = {

if (-not $cmdOptions.RunInSandBox) {
    throw "Sandbox not enabled for $($cmd)"
}
$value = $request['SandboxScript']
if ($value.Trim()[-1] -eq '=') {
    # Make everything handle base64 input (as long as it's not to short to be an accident)
    $valueFromBase64 = try { 
        [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($value))
    } catch {
    
    }
}
# If the value was passed in base64, convert it
if ($valueFromBase64) { 
    $value = $valueFromBase64 
} 

$sb = [ScriptBlock]::Create($value)

if (-not $sb) { return }
$noLanguageMode = $sb.GetPowerShell()
if (-not $NoLanguageMode) { return }
$allowInPipeline = @($cmdOptions.AllowInPipeline) + 
    $cmd.Name + 
    "Add-Member", "Sort-Object", "Select-Object", "Group-Object", "Measure-Object", "Select-String", "Select-Xml" |
    Select-Object -Unique
$thePipeline = @($noLanguageMode.Commands | 
    Select-Object -ExpandProperty Commands | 
    Select-Object -ExpandProperty CommandText)

if ($thePipeline[0] -ne $cmd.Name) {
    throw "$($cmd.Name) must be the first command in the pipeline"
}     

$badParams = @($noLanguageMode.Commands)[0].Commands | 
    Where-Object  {$hideParameter -contains $_.Name } 
    
if ($badParams) {
    throw "$($badParams | Select-Object -ExpandProperty Name)"
}


foreach ($commandName in $thePipeline) {
    if ($allowInPipeline -notcontains $commandName) {
        throw "$CommandName is not allowed in the pipeline in this sandbox.  These commands are:  $($allowInPipeline -join ',')"        
    }
}

# Honor the content type if one exists
if ($cmdOptions.ContentType) {
    $response.ContentType = $cmdOptions.ContentType
} 
# We've gotten this far, so go ahead and run it, but be sure to respect plain output
$resultToOutput = & $sb
$resultAsBytes = $resultToOutput -as [Byte[]]
if ($resultAsBytes) {                    
    $response.BufferOutput = $true
    $response.BinaryWrite($resultAsBytes )
    $response.Flush()
    
} else {
    if ($cmdOptions.PlainOutput) {
        if ($resultToOutput -is [xml]) {
            $strWrite = New-Object IO.StringWriter
            $resultToOutput.Save($strWrite)
            $resultToOutput  = "$strWrite"
            if (-not $cmdOptions.ContentType) {
                $response.ContentType ="text/xml"
            }
        }
        $response.Write("$resultToOutput")    
    } else {
        $response.Write("$($resultToOutput | Out-HTML)")
    }
    
}


        }
        #endregion
        
        #region Download Proxy Command        
        $downloadProxy = {

# Start with the core command, 
$proxyCommandMetaData = [Management.Automation.CommandMetaData]$cmd
# then strip off hidden parameters
foreach ($p in $hideParameters){
    $null = $proxyCommandMetaData.Parameters.Remove($p)    
}

$paramBlock = [Management.Automation.ProxyCommand]::GetParamBlock($proxyCommandMetaData)

# Determine the root URL, if it is not set in Command Option
if (-not $cmdOptions.CommandServiceUrl) {
    $protocol = ($request['Server_Protocol'] -split '/')[0]
    $serverName= $request['Server_Name']
    $shortPath = Split-Path $request['PATH_INFO']
    $remoteCommandUrl= $Protocol + '://' + 
        $ServerName.Replace('\', '/').TrimEnd('/') + '/' + 
        $shortPath.Replace('\','/').TrimStart('/')
} else {
    $remoteCommandUrl = $cmdOptions.CommandServiceUrl
}


$handleResponseScript  = 
"
    if (`$getWebCommandLink) { return `$str }
    `$xmlResult = `$str -as [xml]

    if (`$xmlResult) {
        Write-Verbose 'Response is XML'
        if (`$str -like '*<Object*') {
            Write-Verbose 'Response is Object Xml'
            `$str | 
                Select-Xml //Object |
                ForEach-Object {
                    `$_.Node
                } | 
                ForEach-Object {
                    if (`$_.Type -eq 'System.String') {
                        `$_.'#text'
                    } elseif (`$_.Property) {
                        `$_ | 
                            Select-Object -ExpandProperty Property | 
                            ForEach-Object -Begin {
                                `$outObject = @{}
                            } {
                                `$name = `$_.Name
                                `$value = `$_.'#Text'
                                `$outObject[`$name] = `$value
                            } -End {
                                New-Object PSObject -Property `$outObject
                            }
                    }
                }
        } else { 
            Write-Verbose 'Response is Normal Xml'
            `$strWrite = New-Object IO.StringWriter
            `$xmlResult.Save(`$strWrite)
            `$strOut = `"`$strWrite`"
            `$strOut.Substring(`$strOut.IndexOf([environment]::NewLine) + 2)
        }
    } elseif (`$str -and 
        (`$str -notlike '*://*' -or
        (`$str.ToCharArray()[1..100] | ? { `$_ -eq ' '} ))) {
        Write-Verbose 'Response is Text with spaces'
        `$str.ResponseText
    } elseif (`$xmlHttp.ResponseBody) {
        Write-Verbose 'Response is Data'
        `$r
    } elseif (`$xmlHttp.ResponseText) {
        Write-Verbose 'Response is Text'
        `$str
    } else {
        Write-Verbose 'Unknown Response'
    }
"        

$proxyCommandText = "
function $($cmd.Name) {
    $([Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($proxyCommandMetaData))
    param(
    $paramBlock,
    [Timespan]`$WebCommandTimeout = '0:0:45',
    $(if ($CmdOptions.RequireAppKey) {
    "[string]`$AppKey,"
    })
    [switch]`$GetWebCommandLink
    )
    begin {
        Add-Type -AssemblyName System.Web
        `$xmlHttp = New-Object -ComObject Microsoft.XmlHttp 
        `$remoteCommandUrl = '$RemoteCommandUrl'
        `$wc = New-Object Net.Webclient
    }
    process {
        `$result = `$null
        `$nvc = New-Object Collections.Specialized.NameValueCollection
        `$urlParts = foreach (`$param in `$psBoundParameters.Keys) {
            if ('WebCommandTimeout', 'GetWebCommandLink' -contains `$param) { continue }            
            `$null = `$nvc.Add(`"Add-SensorReading_`$param`", `"`$(`$psBoundParameters[`$param])`")
            `"$($cmd.Name)_`$param=`$([Web.HttpUtility]::UrlEncode(`$psBoundParameters[`$param]))`" 
        }
        `$urlParts = `$urlParts -join '&' 
        `$fullUrl = `$RemoteCommandUrl + '?' + `$urlParts
        if (`$GetWebCommandLink) {
            `$fullUrl += '&-GetLink=true'
            `$null = `$nvc.Add('GetLink', 'true')
        } else {
            $(if (-not $cmdOptions.PlainOutput) { "`$fullUrl += '&AsXml=true'" })             
            `$null = `$nvc.Add('AsXml', 'true')
        }
        
        
        `$sendTime  = Get-Date
        Write-Verbose `"`$fullUrl - Sent `$sendTime`"        
        `$r = `$wc.UploadValues(`"`$remoteCommandUrl/`", `"POST`", `$nvc)                    
        if (-not `$?) {
            return
        }
        `$str = [Text.Encoding]::UTF8.GetString(`$r)
        
        Write-Verbose `"`$fullUrl - Response Received `$(Get-Date)`"        
        $handleResponseScript            
        
       
                
        
    }
    
}
"

$webPage = New-WebPage -Css $cssStyle -UseJQueryUI -Title "$($cmdMd.Name) | Proxy" -AnalyticsID '$analyticsId' -PageBody (Write-ScriptHtml ([ScriptBlock]::create($proxyCommandText)) )
$response.Write($webPage )
}.ToString()
        
                                                             
        $allowDownloadChunk = if ($allowDownload) {
@"
$($embedCommand.Replace('"','""'))
`$proxyCmd =  [Management.Automation.ProxyCommand]::Create(`$cmdMd)
`$proxyCmd = `$proxyCmd.Substring(0,`$proxyCmd.LastIndexOf('<#'))
`$newCmd = ""function `$(`$cmd.Name) {
`$(`$cmd.Definition)
}""
`$response.ContentType = 'text/plain'
`$response.Write(`$newCmd)
"@
} elseif ($RunOnline) {
@"
$($embedCommand.Replace('"','""'))
$($downloadProxy.Replace('"', '""'))
"@
} else {
"
`$response.ContentType = 'text/html'
Write-Error 'This command may not be downloaded'"
}
        #endregion
        
        $allowColorizedDownloadChunk = if ($allowDownload) {
@"
$($embedCommand.Replace('"','""'))
`$proxyCmd =  [Management.Automation.ProxyCommand]::Create(`$cmdMd)
`$proxyCmd = `$proxyCmd.Substring(0,`$proxyCmd.LastIndexOf('<#'))
`$newCmd = ""function `$(`$cmd.Name) {
`$(`$cmd.Definition)
}""
`$newCmd = ([ScriptBlock]::Create(`$newcmd))
`$response.ContentType = 'text/html'
`$response.Write((New-WebPage -Css `$cssStyle -UseJQueryUI -Title `$cmdMd.Name -AnalyticsID '$analyticsId' -PageBody (Write-ScriptHtml `$newCmd)))

"@
} else {
"Write-Error 'This command may not be downloaded'"
}
        #region Execution Handler
        $RunInput = @"
`$commandParameters = Get-WebInput -ParameterAlias `$cmdOptions.ParameterAliases -CommandMetaData `$cmdMd -DenyParameter `$HideParameter
"@ + {


$command = Get-Command $cmdMd.Name

$cmdHasErrors = $null

$escape = $cmdOptions.EscapeOutput
if ($cmdOptions.RequireLogin -and (-not $session['User'])) {
    return
}




# Prefer supplied parameters to default values, but remove one or the other or the commands will not run
$defaultValues = $cmdOptions.parameterDefaultValue
$cmdParamNames = $commandParameters.Keys 
foreach ($k in @($defaultValues.Keys))
{
    if ($cmdParamNames -contains $k -and $commandParameters[$k]) {
        $null = $defaultValues.Remove($k)
    }
}



$parametersFromCookies = @{}
foreach ($parameterCookieInfo in $cmdOptions.CookieParameter.GetEnumerator()) {
    if ($cmdMetaData.Parameters[$parameterCookieInfo.Key]) {    
        $cookie = $request.Cookies[$parameterCookieInfo.Value]
        if ($cookie) {
            $parametersFromCookies[$parameterCookieInfo.Key] = $cookie
        }            
    }
}

foreach ($k in @($parametersFromCookies.Keys))
{
    if ($cmdParamNames -contains $k -and $commandParameters[$k]) {
        $null = $parametersFromCookies.Remove($k)
    }
}


$parametersFromSettings = @{}
foreach ($parameterSettingInfo in $cmdOptions.parameterFromSetting.GetEnumerator()) {
    if ($cmdMetaData.Parameters[$parameterSettingInfo.Key]) {    
        $webConfsetting = Get-WebConfigurationSetting -Setting $parameterSettingInfo.Value
        if ($webConfsetting ) {
            $parametersFromSettings[$parameterSettingInfo.Key] = $webConfsetting
        }            
    }
}

foreach ($k in @($parametersFromSettings.Keys))
{
    if ($cmdParamNames -contains $k -and $commandParameters[$k]) {
        $null = $parametersFromSettings.Remove($k)
    }
}


$parametersFromUser = @{}
foreach ($parameterUserInfo in $cmdOptions.parameterFromSetting.GetEnumerator()) {
    if ($cmdMetaData.Parameters[$parameterUserInfo.Key]) {    
        $userSetting = if ($session -and $session['User'].($parameterUserInfo.Key)) {
            $session['User'].($parameterUserInfo.Key)
        }  else {
            $null
        }
        if ($userSetting ) {
            $parametersFromUser[$parameterUserInfo.Key] = $userSetting 
        }            
    }
}

foreach ($k in @($parametersFromUser.Keys))
{
    if ($cmdParamNames -contains $k -and $commandParameters[$k]) {
        $null = $parametersFromUser.Remove($k)
    }
}

if ($cmdOptions.RequireAppKey) {
    
}


$mergedParameters = $commandParameters + $defaultValues + $parametersFromCookies + $parametersFromSettings + $parametersFromUser
if ($request['Bare'] -eq $true -or $request['-Bare'] -eq $true) {
    $cmdoptions.PlainOutput = $true
}

if ($Request['GetLink'] -eq $true -or $request['-GetLink'] -eq $true) {
    # Get a link
    $response.contentType = 'text/plain'
    $responseString = $request.Url.ToString()
    if ($responseString.Contains('?')) {
        $responseString = $responseString.Substring(0, $responseString.IndexOf("?"))
    }
    $responseString+='?'
    foreach ($cp in $commandParameters.GetEnumerator()) {
        $b64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cp.Value))
        $responseString +="$($CmdMd.Name)_$($cp.Key)=${b64}&"
    }
    $response.Write($responseString)
    return
}

$result = $null
if ($cmdOptions.runWithoutInput -or $commandParameters.Count) {        
    if ($cmdOptions.RequireAppKey) {
        $appKey = if ($session['User'].SecondaryApiKey -and 
            -not $request['AppKey']) {
            $session['User'].SecondaryApiKey
        } elseif ($request['AppKey']) {
            $request['AppKey']
        } else {
            Write-Error "App Key is Required.  The user must be logged in, or a parameter named AppKey must be passed with the request"
            return
        }
        
        
        if (-not $cmdOptions.UserTable) {
            Write-Error "Cannot Validate AppKey without a User Table."
            return
        }
        
        
        
        $storageAccount = Get-WebConfigurationSetting -Setting $cmdOptions.StorageAccountNameSetting
        $storageKey = Get-WebConfigurationSetting -Setting $cmdOptions.StorageAccountKeySetting
        $userTableExists = Get-AzureTable -TableName $cmdOptions.UserTable -StorageAccount $storageAccount -StorageKey $storageKey
        if (-not $userTableExists) { 
            return
        }
        
        
        $userExists = Search-AzureTable -TableName $cmdOptions.UserTable -Filter "PartitionKey eq '$($cmdOptions.UserPartition)' and SecondaryApiKey eq '$appKey'"
        if (-not $UserExists) {
            Write-Error "User not found"
            return
        }
        
        
    } elseif ($cmdOptions.RequireLogin -and $session['User']) {
        $userExists = $session['User']
    }
    
    
    # There are parameters, or the command knows it can run without them.

    # First, clear out empty parameters from the structure
    if ($mergedParameters.Count) {
        $toRemove = @()
        foreach ($kv in $mergedParameters.GetEnumerator()) {
            if (-not $kv.Value) { $toRemove += $kv.Key } 
        }
        foreach ($to in $toRemove) {
            $null = $mergedParameters.Remove($to)
        }
    }                    
 
    # Then, Enforce the Session Throttle       
    $doNotRunCommand = $true
    if ($cmdOptions.SessionThrottle.TotalMilliseconds) {
        if (-not $session["$($cmdMd.Name)_LastRun"]) {
            $session["$($cmdMd.Name)_LastRun"] = Get-Date
            $doNotRunCommand = $false
        } elseif (($session["$($cmdMd.Name)_LastRun"] + $cmdOptions.SessionThrottle) -lt (Get-Date)) {
            $session["$($cmdMd.Name)_LastRun"] = Get-Date
            $doNotRunCommand = $false
        } else {
            $timeUntilICanRunAgain = (Get-Date) - ($session["$($cmdMd.Name)_LastRun"] + $cmdOptions.SessionThrottle)
            "<span style='color:red'>Can run the command again in $(-$timeUntilICanRunAgain.TotalSeconds) Seconds</span>"
            $doNotRunCommand = $true
        }        
    } else {
        $doNotRunCommand = $false
    }

    
    if (-not $cmdOptions.CacheInSession) {
        # Default behavior, do not cache
        if (-not $doNotRunCommand) {                       
            # Run the command 
            $useId = [GUID]::NewGuid()
            if ($cmdOptions.ModeratedBy -and $cmdOptions.ExecutionQueueTable) {
                # If the command was moderated, 'running' the command is really putting 
                # the parameters into table storage for someone to approve
                $subject = "Would you like to run $($cmdMd.Name)?"
                $confirmId = $useId
                $pendingExecutionRequest = New-Object PSObject -Property $commandParameters
                $requestAsString = $request.Url.ToString()
                $finalUrl = $requestAsString.Substring(0,$requestAsString.LastIndexOf("/"))
                
                $canReply = if ($session['User'].UserEmail) {
                    "<a href='$finalUrl?sendreply=$confirmId'>Reply</a>"
                } else {
                    ""
                }
                
                
                $message = "
$userInfo has requested that you run $($cmdMd.Name) with the following parameters:

$($pendingExecutionRequest | Out-HTML) 

               
<a href='$finalUrl?confirm=$confirmId'>Run this</a>
<a href='$finalUrl?deny=$confirmId'>Don't run this</a>
$canReply
"
                Send-Email -To $cmdOptions.ModeratedBy -UseWebConfiguration -Subject $subject -Body $Message -BodyAsHtml -AsJob                
                
                
                $pendingExecutionRequest | 
                    Set-AzureTable -TableName $cmdOptions.ExecutionQueueTable -PartitionKey $cmdMd.Name -RowKey $useId
                
                $result = "Your request has been sent to the moderator"
                                                                            
            } else {
                $anyProblem = ""
                $result = & $command @mergedParameters -ErrorVariable AnyProblem
            }                        
            
            
     
            $worked = $?
            $cmdresult = $result
            
            
            
            # If it worked, charge them 
            if ($worked -and $userExists) {
                $userRecord = Search-AzureTable -TableName $cmdOptions.UserTable -Filter "PartitionKey eq '$($cmdOptions.UserPartition)' and RowKey eq '$($userExists.UserId)'"


                

                if ($cmdOptions.Cost) {
                    # If there was a fixed cost, apply this cost to the user
                    $balance = 
                        $userRecord.Balance -as [Double]
                    
                        
                    $balance += $cmdOptions.Cost -as [Double]
                    $userRecord  |
                        Add-Member NoteProperty Balance $balance -Force -PassThru |                        
                        Update-AzureTable -TableName $cmdOptions.UserTable -Value { $_ } 
                }
                
                if ($cmdOptions.CostFactor) {
                    $factoredCost = 0
                    
                    foreach ($kv in $cmdOptions.CostFactor.getEnumerator()) {                        
                        
                        $parameterValue = $mergedParameters["$($kv.Value.Parameter)"]
                        if ($kv.Value.CostMap) {
                            $factoredCost += $kv.Value.CostMap[$parameterValue]
                        } elseif ($kv.Value.CostPerValue) {
                            $factoredCost += $kv.Value.CostPerValue * $parameterValue
                        }
                        
                    }

                    # If there was a fixed cost, apply this cost to the user
                    $balance = 
                        $userRecord.Balance -as [Double]
                    if (-not $balance) {
                        $balance = 0
                    } 
                    $balance += $factoredCost
                    $userRecord |
                        Add-Member NoteProperty Balance $balance -Force -PassThru |                        
                        Update-AzureTable -TableName $cmdOptions.UserTable -Value { $_ } 

                }
                
                
                if ($EmailOutputToSelf) {
                    
                    Send-Email -To $userRecord.UserEmail -UseWebConfiguration -Subject "$($Command.Name)" -Body ($result | Out-HTML) -BodyAsHTML -AsJob
                }
            }
            
            
            
            # Immediately track its use before it is rendered, if the cmdoptions say so
            if ($cmdOptions.UseTrackingTable) {
                $storageAccount = Get-WebConfigurationSetting -Setting $cmdOptions.StorageAccountNameSetting
                $storageKey = Get-WebConfigurationSetting -Setting $cmdOptions.StorageAccountKeySetting
                $trackingTable = Get-AzureTable -TableName $cmdOptions.UseTrackingTable -StorageAccount $storageAccount -StorageKey $storageKey
                if (-not $trackingTable) { 
                    return
                }
                
                
                $useInfo = New-Object PSObject -Property @{
                    UseId = $useID
                    Worked = $worked
                }                    
                
                
                if (-not $worked) {
                    $ht = Write-PowerShellHashtable -InputObject $commandParameters
                    $useInfo | Add-Member NoteProperty Parameters $ht -Force
                }
                if ($session['User'].UserId) {
                    $useInfo | Add-Member NoteProperty UserId $session['User'].UserId -Force
                }
                
                if ($appKey) {
                    $useInfo | Add-Member NoteProperty AppKey $appKey -Force
                }
                
                
                
                $useInfo | 
                    Set-AzureTable -TableName $cmdoptions.UseTrackingTable -PartitionKey "$($cmdMd.Name)_TimesUsed" -RowKey $useId
                
                if ($cmdOptions.TrackProperty) {
                    $result | 
                        Select-Object $cmdOptions.TrackProperty |
                        ForEach-Object { $_.psobject.properties } |
                        ForEach-Object {
                            $propName = $_.Name
                            $md5 = [Security.Cryptography.MD5]::Create()
                            $content = [Text.Encoding]::Unicode.GetBytes(("$($_.Value)"))
                            $part = [BitConverter]::ToString($md5.ComputeHash($content))
                            $useInfo |
                                Set-AzureTable -TableName $cmdoptions.UseTrackingTable -PartitionKey "$($cmdMd.Name)_$($propName)_${Part}" -RowKey $useID
                        }
                }
                
                
                
                
                
                if ($cmdOptions.TrackParameter) {
                    New-Object PSObject -Property $commandParameters |                    
                        Select-Object $cmdOptions.TrackParameter |
                        ForEach-Object { $_.psobject.properties } |
                        ForEach-Object {
                            $propName = $_.Name
                            $md5 = [Security.Cryptography.MD5]::Create()
                            $content = [Text.Encoding]::Unicode.GetBytes(("$($_.Value)"))
                            $part = [BitConverter]::ToString($md5.ComputeHash($content))
                            $useInfo |
                                Set-AzureTable -TableName $cmdoptions.UseTrackingTable -PartitionKey "$($cmdMd.Name)_$($propName)_Input_${Part}" -RowKey $useID
                        }
                }
                
                if ($cmdOptions.KeepResult -and $result) {
                    if ($session['User'].UserId) {
                        $result | Add-Member NoteProperty __UserId $session['User'].UserId -Force
                    }
                    
                    if ($appKey) {
                        $result | Add-Member NoteProperty __AppKey $appKey -Force
                    }
                    
                    $result | 
                        Add-Member NoteProperty __UseId $useId -Force
                        
                    $result |
                        Set-AzureTable -TableName $cmdoptions.UseTrackingTable -PartitionKey "$($cmdMd.Name)_Results" -RowKey $useID
                }
                
                
                if ($cmdOptions.KeepUserHistory) {
                    $ht = Write-PowerShellHashtable -InputObject $commandParameters 
                    $md5 = [Security.Cryptography.MD5]::Create()
                    $content = [Text.Encoding]::Unicode.GetBytes(("$($ht)"))
                    $part = [BitConverter]::ToString($md5.ComputeHash($content))
                    New-Object PSObject -Property @{
                        UseId = $useID
                        CompressedInput = Compress-Data -String $ht
                    }
                    $useInfo |
                        Set-AzureTable -TableName $cmdoptions.UseTrackingTable -PartitionKey "$($cmdMd.Name)_$($propName)_Input_${Part}" -RowKey $useID
                }
                
                
                if ($cmdOptions.KeepHistory) {                    
                    $ht = Write-PowerShellHashtable -InputObject $commandParameters 
                    $md5 = [Security.Cryptography.MD5]::Create()
                    $content = [Text.Encoding]::Unicode.GetBytes(("$($ht)"))
                    $part = [BitConverter]::ToString($md5.ComputeHash($content))
                    New-Object PSObject -Property @{
                        UseId = $useID
                        CompressedInput = Compress-Data -String $ht
                        CompressedResult = Compress-Data -String ($result | ConvertTo-Xml) 
                    }
                }
                
                
                
                                                
            }
            
            
            
            if (($request['AsXml'] -eq $true) -or ($request['-AsXml'] -eq $true)) {
                $response.contentType = 'text/xml'
                $result = [string]($result | ConvertTo-Xml -as String)
                $response.Write("$result     ")                                        
                return 
            }
            
            if (($request['AsCsv'] -eq $true) -or ($request['-AsCsv'] -eq $true)) {
                $response.contentType = 'text/csv'
                $csvFile = [io.path]::GetTempFileName() + ".csv"
                $result | Export-Csv -Path $csvFile                                 
                $response.Write("$([IO.File]::ReadAllText($csvFile))")                                        
                Remove-Item -Path $csvFile -ErrorAction SilentlyContinue 
                return 
            }                             
            $result | Out-HTML -Id "${CommandId}Output" -Escape:$escape                                        
            if (($request['AsRss'] -eq $true) -or ($request['-AsRss'] -eq $true)) {
                $response.contentType = 'text/xml'
                
                $requestAsString = $request.Url.ToString() 
                $pageUrl = $requestAsString  -ireplace "AsRss=true", ""
                $pageUrl = $pageUrl.TrimEnd("&")
                $shorturl = $requestAsString.Substring(0, $requestAsString.IndexOf("?"))
                $description = (Get-Help $command.Name).Description
                if ($description) {
                    $description = $description[0].text.Replace('"',"'").Replace('<', '&lt;').Replace('>', '&gt;').Replace('$', '`$')
                }
                
                
                $getDateScript = {
                    if ($_.DatePublished) {
                        [DateTime]$_.DatePublished
                    } elseif ($_.TimeCreated) {
                        [DateTime]$_.TimeCreated
                    } elseif ($_.TimeGenerated) {
                        [DateTime]$_.TimeGenerated
                    } elseif ($_.Timestamp) {
                        [DateTime]$_.Timestamp
                    } else {
                        Get-Date
                    }
                }
                # DCR: Make RSS support multiple results
                $resultFeed = 
                    $result | 
                        Sort-Object $getDateScript  -Descending | 
                        New-RssItem -DatePublished $getDateScript  -Author { 
                            if ($_.Author) { $_.Author } else { "$($command.Name)" }
                        } -Link {
                            $pageUrl 
                        } -Title {
                            if ($_.Title) { 
                                $_.Title 
                            } elseif ($_.Name) { 
                                $_.Name 
                            } else {
                                "$($command.Name) - $(Get-Date)"
                            } 
                        } -Description {
                            if ($_.Description) {
                                $_.Description
                            } elseif ($_.ArticleBody) {
                                $_.ArticleBody
                            } elseif ($_.Readings) {
                                $_.Readings | Out-HTML
                            } else {
                                $_  | Out-HTML
                            }
                        }  |
                        Out-RssFeed -Link $shorturl -Title "$($command.Name)" -Description "$description"                     
                $response.Write("$resultFeed")                    
                return 
            } 

            if ($cmdOptions.PlainOutput) {
                if ($cmdOptions.ContentType) {
                    $response.ContentType = $cmdOptions.ContentType
                }
                $resultAsBytes = $result -as [Byte[]]
                if ($resultAsBytes) {                    
                    # If the result was a set of bytes, flush them all as one so that the handler can produce a complex content type.
                    $response.BufferOutput = $true
                    $response.BinaryWrite($resultAsBytes )
                    $response.Flush()
                    
                } else {
                    # If the result is an XmlDocument, then render it as XML.
                    if ($result -is [xml]) {
                        $strWrite = New-Object IO.StringWriter
                        $result.Save($strWrite)
                        $result  = "$strWrite"
                        # And, if the content type hasn't been set, set the content type
                        if (-not $cmdOptions.ContentType) {
                            $result.ContentType ="text/xml"
                        }
                    }

                    $response.Write("$result")
                }
                return
            }  
            if ($cmdOptions.RedirectTo -and $worked -and (-not $AnyProblem)) {
                if (-not $cmdOptions.RedirectIn) {
$response.Write(@"
<script type="text/javascript">
setTimeout('window.location = "$($cmdoptions.redirectTo)"', 250)
</script>
"@)            
                } else {
$response.Write(@"
<script type="text/javascript">
setTimeout('window.location = "$($cmdoptions.redirectTo)"', $($cmdOptions.RedirectIn.TotalMilliseconds))
</script>
"@)                
                }
            }   
            
            if ($cmdOptions.RedirectToResult -and $result) {
                if(-not $cmdOptions.RedirectIn) {
$response.Write(@"
<script type="text/javascript">
setTimeout('window.location = "$result"', 250)
</script>
"@)                
                } else {
$response.Write(@"
<script type="text/javascript">
setTimeout('window.location = "$result"', $($cmdOptions.RedirectIn.TotalMilliseconds))
</script>
"@)                 
                }
                
            }


            if ($cmdOptons.showCode) {
                if (($request['AsXml'] -eq $true) -or ($request['-AsXml'] -eq $true)) {
                    $response.contentType = 'text/xml'
                    $response.Clear()
                    $response.BufferOutput = $false
                    $result = [string]($result | ConvertTo-Xml -As String)
                    $response.Write("$result        ")                    
                    return 
                } else {
                $result | Out-HTML 
                "
                $([Security.SecurityElement]::Escape($result))
                <hr/>
                Code
                <br/>
                <textarea cols='80' rows='30'>$([Security.SecurityElement]::Escape($result))</textarea>"
                }
            } 
        }             
    } else {
        
        if (-not $session["$($cmdMd.Name)_Cache"]) {
            $session["$($cmdMd.Name)_Cache"] = @{}
        }
        if ($session["$($cmdMd.Name)_Cache"]) {
            $matchedItem = $false
            foreach ($value in $session["$($cmdMd.Name)_Cache"].Values) {
                if ($matchedItem) {
                    break
                } 
                $notMatch = $false
                foreach ($key in $value.Parameters.Keys) {                
                    if ("$($mergedParameters[$key])" -ne "$($value.Parameters[$key])") {
                        $notMatch = $true                        
                        break
                    }
                }
                
                if (-not $notMatch) { 
                    $matchedItem = "$($value.id)"    
                    break
                }                
            }
            if (-not $matchedItem) {
                # Run a command and store the results in session       
                if (-not $doNotRunCommand) {         
                    $result = & $command @mergedParameters     
                    
                    $resultId = [GUID]::NewGuid().ToString().Replace('-','')
                    $matchedItem = $resultId
                    $session["$($cmdMd.Name)_Cache"][$resultId] = @{
                        Id = $resultId 
                        Result = $result
                        HtmlResult = "<!-- $($cmdMd.Name)CacheID $resultId -->" + ($result | Out-HTML)
                        Parameters = $mergedParameters
                        Timestamp = Get-Date
                    }
                }
            }
            
            if ($matchedItem) {
                if ($cmdOptions.PlainOutput) {
                    if ($cmdOptions.ContentType) {
                        $response.ContentType = $cmdOptions.ContentType
                    }
                    $resultAsBytes = $session["$($cmdMd.Name)_Cache"][$matchedItem].Result  -as [Byte[]]
                    if ($resultAsBytes ) {
                        $response.BinaryWrite($resultAsBytes )
                    } else {
                        $response.Write("$($session["$($cmdMd.Name)_Cache"][$matchedItem].Result)")
                    }
                
                    return
                }                
                if (($request['AsXml'] -eq $true) -or ($request['-AsXml'] -eq $true)) {
                    $response.contentType = 'text/xml'
                    $response.Clear()

                    $outString = [string]($session["$($cmdMd.Name)_Cache"][$matchedItem].Result | ConvertTo-Xml -as string)
                    $response.Write("$outString                  ")                   
                    
                    return 
                } else {
                    $session["$($cmdMd.Name)_Cache"][$matchedItem].HtmlResult           
                }                                             
            }
        }
    }
    
                                           
                    
}
            
}.ToString().Replace('"','""')       
        #endregion        
        $description = (Get-Help $command.Name).Description
        if ($description) {
            $description = $description[0].text.Replace('"',"'").Replace('<', '&lt;').Replace('>', '&gt;').Replace('$', '`$')
        }
        $description = $description -replace "`n", "
<BR/>
"        
        $coreCommandHandler = @"
$($embedCommand.Replace('"','""'))
`$help = Get-Help `$cmdMd.Name

"@ + {




if ($request -and (
    ($request.QueryString.ToString() -ieq '-Text') -or
    ($request['SmsSid'] -and $request['AccountSid'] -and $request['From'] -and $request['To'] -and $request['Body'])
    )) {

    
    # The command is being texted.  If the command contains parameters that match, use them, otherwise, pass the whole
    # body as an embedded script in data language mode.
    $cmdParams = @{}
    
    if (! $cmdOptions.RunOnline) {
        # Text Back the Description
        
        $helpObj= (Get-Help $cmdMd.Name)
        $description  = if ($helpObj.Description) {
            $helpObj.Description[0].text.Replace('"',"'").Replace('<', '&lt;').Replace('>', '&gt;').Replace('$', '`$')
        } else {
            ""
        }
        
        $response.contentType = 'text/xml'
        
        
        $response.Write("<?xml version='1.0' encoding='UTF-8'?>
<Response>
    <Sms>$($cmdMd.name): $([Security.SecurityElement]::Escape($Description))</Sms>
</Response>        ") 
        $response.Flush()
        
        
        return                  
    }
    
    #region Conditionally move any parameters found into the cmdparams  
    if ($command.Parameters.From -and $request['From']) {
        $cmdParams["From"] = $request['From']
    }
    
    if ($command.Parameters.To -and $request['To']) {
        $cmdParams["To"] = $request['To']
    }
       
    
    if ($command.Parameters.Body -and $request['Body']) {
        $cmdParams["Body"] = $request['Body']
    }
    
    if ($command.Parameters.AccountSid -and $request['AccountSid']) {
        $cmdParams["Accountsid"] = $request['Accountsid']
    }
    
    if ($command.Parameters.SmsSid -and $request['SmsSid']) {
        $cmdParams["SmsSid"] = $request['SmsSid']
    }
    
    if ($command.Parameters.FromCity -and $request['FromCity']) {
        $cmdParams["FromCity"] = $request['FromCity']
    }
    
    if ($command.Parameters.FromState -and $request['FromState']) {
        $cmdParams["FromState"] = $request['FromState']
    }
    
    if ($command.Parameters.FromZip -and $request['FromZip']) {
        $cmdParams["FromZip"] = $request['FromZip']
    }
    
    if ($command.Parameters.FromCountry -and $request['FromCountry']) {
        $cmdParams["FromCountry"] = $request['FromCountry']
    }
    
    
    if ($command.Parameters.ToCity -and $request['ToCity']) {
        $cmdParams["ToCity"] = $request['ToCity']
    }
    
    if ($command.Parameters.ToState -and $request['ToState']) {
        $cmdParams["ToState"] = $request['ToState']
    }
    
    if ($command.Parameters.ToZip -and $request['ToZip']) {
        $cmdParams["ToZip"] = $request['ToZip']
    }
    
    if ($command.Parameters.ToCountry -and $request['ToCountry']) {
        $cmdParams["ToCountry"] = $request['ToCountry']
    }
    #endregion
    

    # Prefer supplied parameters to default values, but remove one or the other or the commands will not run
    $defaultValues = $cmdOptions.parameterDefaultValue
    $cmdParamNames = $cmdParams.Keys 
    foreach ($k in @($defaultValues.Keys))
    {
        if ($cmdParamNames -contains $k -and $commandParameters[$k]) {
            $null = $defaultValues.Remove($k)
        }
    }



    $parametersFromCookies = @{}
    foreach ($parameterCookieInfo in $cmdOptions.CookieParameter.GetEnumerator()) {
        if ($cmdMetaData.Parameters[$parameterCookieInfo.Key]) {    
            $cookie = $request.Cookies[$parameterCookieInfo.Value]
            if ($cookie) {
                $parametersFromCookies[$parameterCookieInfo.Key] = $cookie
            }            
        }
    }

    foreach ($k in @($parametersFromCookies.Keys))
    {
        if ($cmdParamNames -contains $k -and $commandParameters[$k]) {
            $null = $parametersFromCookies.Remove($k)
        }
    }


    $parametersFromSettings = @{}
    foreach ($parameterSettingInfo in $cmdOptions.parameterFromSetting.GetEnumerator()) {
        if ($cmdMetaData.Parameters[$parameterSettingInfo.Key]) {    
            $webConfsetting = Get-WebConfigurationSetting -Setting $parameterSettingInfo.Value
            if ($webConfsetting ) {
                $parametersFromSettings[$parameterSettingInfo.Key] = $webConfsetting
            }            
        }
    }

    foreach ($k in @($parametersFromSettings.Keys))
    {
        if ($cmdParamNames -contains $k -and $commandParameters[$k]) {
            $null = $parametersFromSettings.Remove($k)
        }
    }


    $parametersFromUser = @{}
    foreach ($parameterUserInfo in $cmdOptions.parameterFromSetting.GetEnumerator()) {
        if ($cmdMetaData.Parameters[$parameterUserInfo.Key]) {    
            $userSetting = if ($session -and $session['User'].($parameterUserInfo.Key)) {
                $session['User'].($parameterUserInfo.Key)
            }  else {
                $null
            }
            if ($userSetting ) {
                $parametersFromUser[$parameterUserInfo.Key] = $userSetting 
            }            
        }
    }

    foreach ($k in @($parametersFromUser.Keys)) {
        if ($cmdParamNames -contains $k -and $commandParameters[$k]) {
            $null = $parametersFromUser.Remove($k)
        }
    }
    $cmdParams += ($defaultValues + $parametersFromCookies + $parametersFromSettings + $parametersFromUser)

    
    if (-not $cmdParams.Count) {
        $body = 
            if ($request -and $request.Params -and $request.Params['Body']) {
                $request.Params['Body']
            } else {
                ""
            }
            

        # The body should strip off the command specifier, so that the input could be easily redirected from a module
        $possibleCmdNames = 
            @(Get-Alias -Definition "$($cmdMd.Name)" -ErrorAction SilentlyContinue) + "$($cmdMd.Name)"
        
        foreach ($pcn in $possibleCmdNames) {
            if ($body -like "$pcn*") {
                $body = $body.Susbstring("$pcn".Length).TrimStart(":").TrimStart("-")
            }
        }
        
        
        $dataScriptBlock = [ScriptBlock]::create("
        $($cmdMd.Name) $body
        ")
        
        $dataScriptBlock = [ScriptBlock]::Create("data  -SupportedCommand $($cmdMd.Name) { $dataScriptBlock } ")        
        
        $outputData = & $dataScriptBlock               

        
    } else {


if ($cmdOptions.RequireAppKey) {
    
}


        $outputData = & $command @mergedParameters 2>&1     
    }
    
    if ($outputData -is [string]) {
        $response.contentType = 'text/xml'
        $response.Write("<?xml version='1.0' encoding='UTF-8'?>
<Response>
    <Sms>$([Security.SecurityElement]::Escape($OutputData))</Sms>
</Response>")
    } else {
        $outputText = ""        
        
        # Loop thru each object and concatenate properties
        foreach ($outputItem in $outputData) {
            foreach ($kv in $outputItem.psObject.properties) {
                $outputText += "$($kv.Name):$($kv.Value)$([Environment]::NewLine)"
            }
        }
                
        $response.contentType = 'text/xml'
        $response.Write("<?xml version='1.0' encoding='UTF-8'?>
<Response>
    <Sms>$($outputText)</Sms>
</Response>")
    }
        

     
    
    
    
    
    return
}



if ($request.QueryString.ToString() -ieq '-GetMetaData') {
    
    
    # Resolve the remote command Url
    $protocol = ($request['Server_Protocol'] -split '/')[0]
    $serverName= $request['Server_Name']
    $shortPath = Split-Path $request['PATH_INFO']
    $remoteCommandUrl= $Protocol + '://' + $ServerName.Replace('\', '/').TrimEnd('/') + '/' + $shortPath.Replace('\','/').TrimStart('/')
    
    # Create the XML chunk derived from help
    
    $descriptionChunk = ""
    $helpXmlChunk = if ($help.Description) {
        $descriptionChunk = 
            "<Description>$([Security.SecurityElement]::Escape($help.Description[0].Text))</Description>"
        "<Parameters>" + $(foreach ($p in $help.Parameters.parameter) {
            # Skip hidden parameters
            if ($hideParameter -contains $p.Name) { continue } 
            
            # Bring out the buried parameter type property            
            $paramType = $cmd.Parameters[$p.Name].ParameterType.Fullname
            
            # Create the attributes out of the combined strings
            $paramAttributes = "Name='$($p.Name)' Type='$paramType'"
            "<Parameter $paramAttributes>"
            
            # The the parameter description, and add a <ParameterDescription> element if it exists.
            $description = try { $help.parameters.parameter[0].description[0].Text } catch {} 
            if ($description) {
                "<ParameterDescription>$([Security.SecurityElement]::Escape($description))</ParameterDescription>"
            }
            
            # Walk thru the parameters
            foreach ($paramSet in $cmdMd.Parameters[$p.Name].ParameterSets.GetEnumerator()) {                
                $position = -1
                if ($paramSet.Value.Position -ge 0) {
                    $position = $paramSet.Value.Position 
                }
                $vfp = $paramSet.Value.ValueFromPipeline
                $vfpbpn = $paramSet.Value.ValueFromPipelineByPropertyName
                $vfra = $paramSet.Value.ValueFromRemainingArguments 
                $IsMandatory = $paramSet.Value.IsMandatory
                "<ParameterSet 
                    Name='$($ParamSet.Key)' 
                    Position='$position' 
                    ValueFromPipelineByPropertyName='$vfpbpn' 
                    ValueFromPipeline='$vfp' 
                    ValueFromRemainingArgs='$vfra'
                    Mandatory='$isMandatory'/>"                
            }
            "</Parameter>"
            
            
            if (-not $p) {continue } 
        }) + "</Parameters>"
    }
        
    $moduleUrlChunk = if ($cmdOptions.moduleUrl) {
        "<Module>$($cmdOptions.moduleUrl)</Module>"
    } else { "" }
    $manifestXml = [xml]"<CommandManifest Name='$($cmdmd.Name)' Url='$RemoteCommandUrl' RunOnline='$($cmdOptions.RunOnline.ToString().ToLower())' AllowDownload='$($cmdOptions.AllowDownload.ToString().ToLower())'>
        <Name>$($cmdMd.Name)</Name>
        <Url>$remoteCommandUrl</Url>                
        $moduleUrlChunk
        $descriptionChunk        
        $helpXmlChunk            
    </CommandManifest>"
    $strWrite = New-Object IO.StringWriter
    $manifestXml.Save($strWrite)
    $response.ContentType = 'text/xml'
    $strWrite = "$strWrite"
    
    $response.Write("$($strWrite.Substring($strWrite.IndexOf('>') + 3))")    
    return
}
}.ToString().Replace('"','""') +@"
`$layers = @{}
`$layerOrder = @()
`$output = . { 
    `$RunWithoutInput = `$cmdOptions.runWithoutInput
    $RunInput
}
"@ +{

    # At this point we've run.  
    # There are a couple of conditions that should make the service stop processing now.
    
    # The -AsXml flag was passed
    if ($request['AsXml'] -eq $true -or $request['-AsXml'] -eq $true) {
        return
    }
    
    if ($request['AsRss'] -eq $true -or $request['-AsRss'] -eq $true) {
        return
    }

    if ($Request['GetLink'] -eq $true -or $request['-GetLink'] -eq $true) {
        return 
    }
    # The -Bare option was passed
    if ($request['Bare'] -eq $true -or 
        $request['-Bare'] -eq $true) {
        return
    }
    
    # There was an attempt to send parameters to the command, 
    # and the cmd options requested plain output   
    if ($cmdOptions.PlainOutput -and ($cmdOptions.runWithoutInput -or $commandParameters.Count)) {
        return
    }


    
    # If we're to this point, the service is going to display it's front end or handle an option
    
    # If the web service uses a custom front end, display it
    $webFrontEndHtml = if ($CmdOptions.WebFrontEnd -or $cmdOptions.MobileWebFrontEnd) {
        
        # If the user agent is mobile
        $isMobile = $Request.UserAgent -ilike "*iOs*" -or
            $Request.UserAgent -ilike "*Mobile*" -or
            $Request.UserAgent -ilike "*Android*" -or 
            $Request.UserAgent -ilike "*Symbian*" -or
            ($Request.UserAgent -notlike  "*Windows*" -and
             $Request.UserAgent -notlike  "*Linux*" -and
             $Request.UserAgent -notlike  "*Sun*" -and
             $Request.UserAgent -notlike  "*BSD*" -and
             $Request.UserAgent -notlike  "*BeOS*" -and
             $Request.UserAgent -notlike  "*Mac*")
                     
        if ($isMobile -and $cmdOptions.MobileWebFrontEnd -or (-not $cmdOptions.WebFrontEnd)) {
            # If it's a mobile browser, and has a mobile front end or the corner case: 
            # someone has a mobile web front end, but not a real web front end
            $webFrontEndAsScript = try {
                & ([ScriptBlock]::Create("
data -SupportedCommand New-Region, Out-Html, Write-Ajax, Write-Link  {
    $($cmdOptions.MobileWebFrontEnd)
}"))
            } catch {
                Write-Verbose "$($_ | Out-String)"
            }
            
            # If the web front end was a safe script, then get it's value as a string
            if ($webFrontEndAsScript) {
                "$webFrontEndAsScript" 
            } else {
                # Otherwise, display the normal front end                
                $cmdOptions.MobileWebFrontEnd
            }
        } else {
            # Display the web front end
            
            # Determine if the web front end is a safe script
            $webFrontEndAsScript = try {
                & ([ScriptBlock]::Create("
data -SupportedCommand New-Region, Out-Html, Write-Ajax, Write-Link  {
    $($cmdOptions.WebFrontEnd)           
}"))
            } catch {
                Write-Verbose "$($_ | Out-String)"
            }
            
            # If the web front end was a safe script, then get it's value as a string
            if ($webFrontEndAsScript) {
                "$webFrontEndAsScript" 
            } else {
                # Otherwise, display the normal front end                
                $cmdOptions.WebFrontEnd
            }
            
        }
    }        
    
    # If there is no friendly name, take the friendly name from command metadata
    if (-not $psBoundParameters.FriendlyName) { $friendlyName = $CmdMd.Name } 
            
    if ($help.Description) {
        $description = [Security.SecurityElement]::Escape($help.Description[0].text)
        $description = $description.Replace('`n', '<br/>')
    }
    
    $mainContent = ""
    if ($cmdOptions.runOnline -and (-not $CmdOptions.WebFrontEnd -or $cmdOptions.MobileWebFrontEnd)) {    
        $isFirstLayer  = $layers.Count -eq 0
        $inputOutputLayers  = @{
            "Run" = Request-CommandInput -CommandMetaData $cmdMd -DenyParameter $hideParameter -Method $cmdOptions.Method
        }        
        if ($cmdOptions.RequireLogin -and (-not $session['User'])) {
            $inputOutputLayers."Run" = '<span style="color:red" class="ui-state-error">User must be logged in</span>'    
        }
        
        $inputOutputLayerOrder = @("Run")
        if ($output) {
            $inputOutputLayers.Output = $output
            $inputOutputLayerOrder = @("Output") + $inputOutputLayerOrder 
        }
        
        
        $layers."$friendlyName" = "
    <div style='margin-left:$($cmdOptions.MarginPercentLeft);margin-right:$($cmdOptions.MarginPercentRight)'>
    $(if ($isFirstLayer -and $cmdOptions.parentPage) { (Write-Link -Caption '<span class="ui-icon ui-icon-home"></span>' -Url $cmdOptions.parentPage) + '<br/>' })
    $(if ($isFirstLayer -and -not $cmdOptions.antiSocial) { 
        '<p style=''text-align:right''>' + (Write-Link -Horizontal 'facebook:share', 'twitter:tweet')
        '</p>'           
    })
    <p>$($description -replace "[$([Environment]::newline)]", '<br/>')</p>
    " + (New-Region -Layer $inputOutputLayers -Order $inputOutputLayerOrder -AsTab) + "    
    </div>
    "
        if ($isFirstLayer) { 
            $mainContent = $layers."$friendlyName"
        }
        $layerOrder += $friendlyName
    }    
    
    if ($cmdOptions.allowDownload) {
        $isFirstLayer  = $layers.Count -eq 0
        $layerOrder += "$($cmdMd.Name) | Code"
        $cmd = Get-Command $cmdMd.Name | Select-Object -First 1 
        $newCmd = "
function $($cmd.Name) {
$($cmd.Definition)
}
"
        $layers."$($cmdMd.Name) | Code" = (
    "<div class='CodeContainer'>
$(if ($isFirstLayer -and $cmdOptions.parentPage) { (Write-Link -Caption '<-' -Url $cmdOptions.parentPage) + '<br/>' })
<a href='?-Download'>Download</a><br/>
" + (New-Region -Style @{
    'Margin-Left' = $cmdOptions.MarginPercentLeft
    'Margin-Right' = $cmdOptions.MarginPercentRight
} -LayerID CodeContainer -Content (Write-ScriptHTML -Text ([ScriptBlock]::Create($newCmd)))) + '</div>')
        
        if ($isFirstLayer) { 
            $mainContent = $layers."$($cmdMd.Name) | Code"
        }
    }
    if ($help -isnot [string]) {
        $isFirstLayer  = $layers.Count -eq 0
        $layers."$($cmdMd.Name) Help" = "
        $(if ($isFirstLayer -and $cmdOptions.parentPage) { (Write-Link -Caption '<-' -Url $cmdOptions.parentPage) + '<br/>' })
        <pre style='margin:10px'>$(($help | Out-String).Replace('"', '""').Replace('<', '&lt').Replace('>', '&gt'))</pre>"
        $layerOrder += "$($cmdMd.Name) Help"
        if ($isFirstLayer) { 
            $mainContent = $layers."$($cmdMd.Name) Help"
        }

        if ($help.Parameters.parameter.Length -gt 0) {
            if (-not $hideParameter) {
                $layers.Parameters = "<pre style='margin:10px'>$(($help.Parameters | Out-String).Replace('"', '""').Replace('<', '&lt').Replace('>', '&gt'))</pre>"   
                $layerOrder += 'Parameters'
            }

            foreach ($p in $help.Parameters.Parameter) {
                if ($hideParameter -contains $p.Name) { continue } 
                $parameterText = (@($p.description)[0].Text -split ('`n') |? { $_ -notlike '|*' }) -join ([Environment]::Newline)
                $layers."Parameters:$($p.Name)" = "<p style='margin:10px'>$($parameterText.Replace('"', '""').Replace('<', '&lt').Replace('>', '&gt').Replace('`n', '<br/>'))</p>"                
                $layerOrder += "Parameters:$($p.Name)"
            }            
        }

        $exCount = 1
        foreach ($ex in $help.examples.example) {
            if (-not $ex) { continue }
            $layers."Example ${exCount}" = "<pre style='margin:10px'>$(($ex | Out-String).Replace('"', '""').Replace('<', '&lt').Replace('>', '&gt'))</pre>"        
            $layerOrder += "Example ${exCount}"
            $exCount++
        }
    }    
}.ToString().Replace('"','""') + @"   
`$adSlot = '$adSlot'
`$adSenseId = '$adSenseId'
`$adRegion = if (`$adSlot) {
    New-Region  -LayerId AdRegion -Style @{
        'Margin-Left'='`$(`$cmdOptions.MarginPercentLeft)'
        'Margin-Right'='`$(`$cmdOptions.MarginPercentRight)'
    } -Content '<div style=''text-align:center;margin-left:auto;margin-right:auto''>
<div style=''padding:10px''>
<script type=''text/javascript''>
<!--
google_ad_client = ''ca-pub-$adSenseId'';
/* AdSense Banner */
google_ad_slot = ''$adslot'';
google_ad_width = 728;
google_ad_height = 90;
//-->
</script>
<script type=''text/javascript''
src=''http://pagead2.googlesyndication.com/pagead/show_ads.js''>
</script>
</div>
</div>
'
} else { ''}
`$mainContent = ""<div style='margin-left:`$(`$cmdOptions.MarginPercentLeft);margin-right:`$(`$cmdOptions.MarginPercentRight)'><h1>"" + 
    
    `$cmdMd.Name + 
    ""</h1></div>"" + 
    `$mainContent
`$response.ContentType = 'text/html'
if (-not `$CmdOptions.WebFrontEnd -or `$cmdOptions.MobileWebFrontEnd) {
    `$synopsis = `$help.Synopsis
`$page = New-WebPage -UseJQueryUI -Css `$cssStyle -Title `$cmdMd.Name -AnalyticsID '$analyticsId' -Keyword `$cmd.Name -Description `$synopsis -PinnedSiteName `$cmdMd.Name -PinnedSiteTooltip ((`$help.Description | Out-String).Trim()) -PageBody (
    `$mainContent 
),(
    `$adRegion 
)
} else {
    `$page = New-WebPage -UseJQueryUI -Css `$cssStyle -Title `$cmdMd.Name -AnalyticsID '$analyticsId' -Keyword `$cmd.Name -Description `$synopsis -PinnedSiteName `$cmdMd.Name -PinnedSiteTooltip ((`$help.Description | Out-String).Trim()) -PageBody (
    `$webFrontEndHtml
)
}
`$response.Write(""
`$page
"")
"@       


        
        
        $defaultHandlerAction = if ($RunOnline) {
            if ($NoFrontEnd) {
                $RunInput 
            } else {
                $coreCommandHandler
            }
        } else {
            $coreCommandHandler
        }
                        
        $commandHandlerCSharp = @"
// If -GetHelpComments is the QueryString, then output the help comments
if (String.Compare(context.Request.QueryString.ToString(), "-FullHelp", 
    StringComparison.OrdinalIgnoreCase) == 0) {
    WebCommandSequence.InvokeScript(@"
$($embedCommand.Replace('"','""'))
`$response.ContentType = 'text/html'
`$helpObject = Get-Help `$cmdMd.Name -Full
`$comments = `$helpObject | Out-String -Width 1024
`$webPage = New-WebPage -Css `$cssStyle -Title ""`$(`$cmdMd.Name) | Full Help"" -AnalyticsID '$analyticsId' -PageBody ""<pre>`$comments</pre>""
`$response.Write(`$webPage)
", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()));
} else if (String.Compare(context.Request.QueryString.ToString(), "-Examples", 
    StringComparison.OrdinalIgnoreCase) == 0) {
    WebCommandSequence.InvokeScript(@"
$($embedCommand.Replace('"','""'))
`$response.ContentType = 'text/plain'
`$helpObject = Get-Help `$cmdMd.Name -Examples
`$comments = `$helpObject | Out-String -Width 1024
`$webPage = New-WebPage -UseJQueryUI -Css `$cssStyle -Title ""`$(`$cmdMd.Name) | Examples"" -AnalyticsID '$analyticsId' -PageBody ""<pre>`$comments</pre>""
`$response.Write(`$webPage)
", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()));
} else if (String.Compare(context.Request.QueryString.ToString(), 
    "-Stub", 
    StringComparison.OrdinalIgnoreCase) == 0) {
WebCommandSequence.InvokeScript(@"
$($embedCommand.Replace('"','""'))
`$helpObject = Get-Help `$cmdMd.Name
`$helpComments = try { [Management.Automation.ProxyCommand]::GetHelpComments(`$helpObject) } catch {}

`$newCmd = ""function `$(`$cmd.Name) {
<#
`$helpComments
#>
`$([Management.Automation.ProxyCommand]::GetCmdletBindingAttribute(`$cmdMd))
param(
`$([Management.Automation.ProxyCommand]::GetParamBlock(`$cmdMd))
)

}""
`$response.ContentType = 'text/plain'
`$response.Write(`$newCmd)
", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()));

} else if (String.Compare(context.Request.QueryString.ToString(), 
    "-Download", 
    StringComparison.OrdinalIgnoreCase) == 0) {
    context.Response.ContentType = "text/plain";
    WebCommandSequence.InvokeScript(@"
$allowColorizedDownloadChunk
", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()));

} else if (String.Compare(context.Request.QueryString.ToString(), 
    "-DownloadProxy", 
    StringComparison.OrdinalIgnoreCase) == 0) {    
    WebCommandSequence.InvokeScript(@"
$($embedCommand.Replace('"','""'))
$($downloadProxy.Replace('"', '""'))

", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()));

} else if (String.Compare(context.Request.QueryString.ToString(), 
    "-Android", 
    StringComparison.OrdinalIgnoreCase) == 0) {
    context.Response.ContentType = "text/xml";
    WebCommandSequence.InvokeScript(@"
$($embedCommand.Replace('"','""'))
if (-not `$cmdOptions.AndroidFrontEnd) {
    `$cmdOptions['AndroidFrontEnd'] = Request-CommandInput -CommandMetaData `$cmdMd -DenyParameter `$hideParameter -Platform Android
}
`$response.Write(""`$(`$cmdOptions.AndroidFrontEnd)"")
", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()));

} else if (String.Compare(context.Request.QueryString.ToString(), 
    "-Metro", 
    StringComparison.OrdinalIgnoreCase) == 0) {
    context.Response.ContentType = "text/xml";
    WebCommandSequence.InvokeScript(@"
$($embedCommand.Replace('"','""'))
`$response.Write(""`$(`$cmdOptions.MetroFrontEnd)"")
", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()));

} else if (String.Compare(context.Request.QueryString.ToString(), 
    "-WindowsPhone", 
    StringComparison.OrdinalIgnoreCase) == 0) {
    context.Response.ContentType = "text/xml";
    WebCommandSequence.InvokeScript(@"
$($embedCommand.Replace('"','""'))
if (-not `$cmdOptions.WindowsMobileFrontEnd) {
    `$cmdOptions.WindowsMobileFrontEnd = Request-CommandInput -CommandMetaData `$cmdMd -DenyParameter `$hideParameter -Platform WindowsMobile
}
`$response.Write(""`$(`$cmdOptions.WindowsMobileFrontEnd)"")
", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()));

} else if (String.Compare(context.Request.QueryString.ToString(), 
    "-WPF", 
    StringComparison.OrdinalIgnoreCase) == 0) {
    context.Response.ContentType = "text/xml";
    WebCommandSequence.InvokeScript(@"
$($embedCommand.Replace('"','""'))
if (-not `$cmdOptions.WPFFrontEnd) {
    `$cmdOptions.WPFFrontEnd = Request-CommandInput -CommandMetaData `$cmdMd -DenyParameter `$hideParameter -Platform WPF
}
`$response.Write(""`$(`$cmdOptions.WPFFrontEnd)"")
", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()));

} else if (String.Compare(context.Request.QueryString.ToString(), 
    "-Silverlight", 
    StringComparison.OrdinalIgnoreCase) == 0) {
    context.Response.ContentType = "text/xml";
    WebCommandSequence.InvokeScript(@"
$($embedCommand.Replace('"','""'))
if (-not `$cmdOptions.SilverlightFrontEnd) {
    `$cmdOptions.SilverlightFrontEnd = Request-CommandInput -CommandMetaData `$cmdMd -DenyParameter `$hideParameter -Platform Silverlight
}
`$response.Write(""`$(`$cmdOptions.SilverlightFrontEnd)"")
", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()));

} else if (String.Compare(context.Request.QueryString.ToString(), 
    "-iOSFrontEnd", 
    StringComparison.OrdinalIgnoreCase) == 0) {
    context.Response.ContentType = "text/xml";
    WebCommandSequence.InvokeScript(@"
$($embedCommand.Replace('"','""'))
if (-not `$cmdOptions.IosFrontEnd) {
    `$cmdOptions['IosFrontEnd']= Request-CommandInput -CommandMetaData `$cmdMd -DenyParameter `$hideParameter -Platform Ios
}
`$response.ContentType ='text/xml'
`$response.Write(""`$cmdOptions.iOsFrontEnd"")
", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()) );

}  else if (String.Compare(context.Request.QueryString.ToString(), 
    "-Colorized", 
    StringComparison.OrdinalIgnoreCase) == 0) {
    context.Response.ContentType = "text/html";
    WebCommandSequence.InvokeScript(@"
$allowColorizedDownloadChunk
", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()) );

} else if (String.Compare(context.Request.QueryString.ToString(),
    "-Widget",
    StringComparison.OrdinalIgnoreCase) == 0) {
    WebCommandSequence.InvokeScript(@"
$($embedCommand.Replace('"','""'))
`$serviceUrl = `$request.Url.ToString()
`$serviceUrl = `$serviceUrl.Substring(0, `$serviceUrl.IndexOf('?'))
if (`$cmdOptions.RequireLogin -and (-not `$session['User'])) {
    `$webInput = '<span class='ui-state-error'>User must be logged in</span>'    
} else {
    `$webInput = Request-CommandInput -Action `$serviceUrl -CommandMetaData `$cmdMd -DenyParameter `$hideParameter 
}

`$response.ContentType ='text/html'
`$response.Write(""`$webInput"")

", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()));
} else if (String.Compare(context.Request.QueryString.ToString(),
    "-WebFrontEnd",
    StringComparison.OrdinalIgnoreCase) == 0) {
    context.Response.ContentType = "text/plain";    
    WebCommandSequence.InvokeScript(@"
$($embedCommand.Replace('"','""'))
`$serviceUrl = `$request.Url.ToString()
`$serviceUrl = `$serviceUrl.Substring(0, `$serviceUrl.IndexOf('?'))
`$webInput = Request-CommandInput -Action `$serviceUrl -CommandMetaData `$cmdMd -DenyParameter `$hideParameter 
`$response.ContentType ='text/html'
`$response.Write(""`$webInput"")

", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()));
} else if (! String.IsNullOrEmpty(context.Request.QueryString["SessionCacheId"])) {
    if (context.Session["$($command.Name)_Cache"] != null && 
        context.Session["$($command.Name)_Cache"] is Hashtable) {
            Hashtable commandCache = context.Session["$($command.Name)_Cache"]  as Hashtable;
            if (commandCache.Contains(context.Request.QueryString["SessionCacheId"])) {
                Object cachedCommandResult = commandCache[context.Request.QueryString["SessionCacheId"]];
                if (cachedCommandResult is Hashtable) {
                    Hashtable ccr = cachedCommandResult as Hashtable;
                    if (ccr.Contains("ContentType")) {
                        context.Response.ContentType = (string)ccr["ContentType"];
                    }
                    if (ccr.Contains("Result")) {
                        context.Response.Write(ccr["Result"] ==null);
                    }
                    context.Response.Write("<span style='color:red'>Cached command doesn't contain a result?</span>");
                }  else {
                    context.Response.Write("<span style='color:red'>Cached command result isn't a hashtable?" + cachedCommandResult.GetType().ToString() + "</span>");
                }               
            } else {
                context.Response.Write("<span style='color:red'>Cache Item Not Found</span>");
                
                foreach (string str in commandCache.Keys) {
                    context.Response.Write(str + "<br/>");
                }
            }
                      
        } else {
            context.Response.Write("<span style='color:red'>Session Cache Not Found</span>");
            
            foreach (string str in context.Session.Keys) {
                context.Response.Write(str + "<br/>");
            }
        }    
} else if (context.Request.Params["Confirm"] != null) {
    WebCommandSequence.InvokeScript(@"
$($embedCommand.Replace('"','""'))
$($confirmScriptHandler.ToString().Replace('"', '""'))

", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()));

} else if (context.Request.Params["Deny"] != null) {
    WebCommandSequence.InvokeScript(@"
$($embedCommand.Replace('"','""'))
$($confirmScriptHandler.ToString().Replace('"', '""'))

", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()));

} else if (context.Request.Params["SendReply"] != null) {
    WebCommandSequence.InvokeScript(@"
$($embedCommand.Replace('"','""'))
$($confirmScriptHandler.ToString().Replace('"', '""'))

", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()));

} else if (context.Request.Params["SandboxScript"] != null) {
    WebCommandSequence.InvokeScript(@"
$($embedCommand.Replace('"','""'))
$($sandboxScriptHandler.ToString().Replace('"', '""'))

", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()));

} else if (String.Compare(context.Request.QueryString.ToString(),
    "-Sandbox",
    StringComparison.OrdinalIgnoreCase) == 0) {
    WebCommandSequence.InvokeScript(@"
$($embedCommand.Replace('"','""'))
$($sandboxHandler.ToString().Replace('"', '""'))

", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()));

} else {
    // Default view, show help within regions
    WebCommandSequence.InvokeScript(@"
$defaultHandlerAction
", context, null, true, $((-not $IsolateRunspace).ToString().ToLower()));


}
"@        

        # Given config settings, create the XML
        $configSettingsChunk = ''        
        if ($psBoundParameters.ConfigSetting) {
             $configSettingsChunk = "<appSettings>" + (@(foreach ($kv in $configSetting.GetEnumerator()) {"
        <add key='$($kv.Key)' value='$($kv.Value)'/>"                
             }) -join ('')) + "</appSettings>"
        }
        
        # When not creating a handler from a script block, set content into the directory
        if ($psCmdlet.ParameterSetName -ne 'ScriptBlock') {
            
                
            & $writeSimpleHandler -csharp $commandHandlerCSharp -shareRunspace:(-not $isolateRunspace) -poolSize $poolSize| 
                Set-Content "$outputDirectory\Default.ashx"
            if (-not $isCalledFromExportModuleHandler){ 
@"
<configuration>
    $ConfigSettingsChunk
    <system.webServer>
        <defaultDocument>
            <files>
                <add value="default.ashx" />
            </files>
        </defaultDocument>
    </system.webServer>
</configuration>
"@ |
                Set-Content "$outputDirectory\web.config"
            }
        } else {
            & $writeSimpleHandler -csharp $commandHandlerCSharp -shareRunspace:(-not $isolateRunspace) -poolSize $poolSize
        }      
        
    }
}

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUlrUeuMKndsxnTqjXGF+IP/o/
# YqSgggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTE0MDcxNzAwMDAwMFoXDTE1MDcy
# MjEyMDAwMFowaTELMAkGA1UEBhMCQ0ExCzAJBgNVBAgTAk9OMREwDwYDVQQHEwhI
# YW1pbHRvbjEcMBoGA1UEChMTRGF2aWQgV2F5bmUgSm9obnNvbjEcMBoGA1UEAxMT
# RGF2aWQgV2F5bmUgSm9obnNvbjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
# ggEBAM3+T+61MoGxUHnoK0b2GgO17e0sW8ugwAH966Z1JIzQvXFa707SZvTJgmra
# ZsCn9fU+i9KhC0nUpA4hAv/b1MCeqGq1O0f3ffiwsxhTG3Z4J8mEl5eSdcRgeb+1
# jaKI3oHkbX+zxqOLSaRSQPn3XygMAfrcD/QI4vsx8o2lTUsPJEy2c0z57e1VzWlq
# KHqo18lVxDq/YF+fKCAJL57zjXSBPPmb/sNj8VgoxXS6EUAC5c3tb+CJfNP2U9vV
# oy5YeUP9bNwq2aXkW0+xZIipbJonZwN+bIsbgCC5eb2aqapBgJrgds8cw8WKiZvy
# Zx2qT7hy9HT+LUOI0l0K0w31dF8CAwEAAaOCAbswggG3MB8GA1UdIwQYMBaAFFrE
# uXsqCqOl6nEDwGD5LfZldQ5YMB0GA1UdDgQWBBTnMIKoGnZIswBx8nuJckJGsFDU
# lDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwdwYDVR0fBHAw
# bjA1oDOgMYYvaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1j
# cy1nMS5jcmwwNaAzoDGGL2h0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFz
# c3VyZWQtY3MtZzEuY3JsMEIGA1UdIAQ7MDkwNwYJYIZIAYb9bAMBMCowKAYIKwYB
# BQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwgYQGCCsGAQUFBwEB
# BHgwdjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tME4GCCsG
# AQUFBzAChkJodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRTSEEy
# QXNzdXJlZElEQ29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG
# 9w0BAQsFAAOCAQEAVlkBmOEKRw2O66aloy9tNoQNIWz3AduGBfnf9gvyRFvSuKm0
# Zq3A6lRej8FPxC5Kbwswxtl2L/pjyrlYzUs+XuYe9Ua9YMIdhbyjUol4Z46jhOrO
# TDl18txaoNpGE9JXo8SLZHibwz97H3+paRm16aygM5R3uQ0xSQ1NFqDJ53YRvOqT
# 60/tF9E8zNx4hOH1lw1CDPu0K3nL2PusLUVzCpwNunQzGoZfVtlnV2x4EgXyZ9G1
# x4odcYZwKpkWPKA4bWAG+Img5+dgGEOqoUHh4jm2IKijm1jz7BRcJUMAwa2Qcbc2
# ttQbSj/7xZXL470VG3WjLWNWkRaRQAkzOajhpTCCBTAwggQYoAMCAQICEAQJGBtf
# 1btmdVNDtW+VUAgwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIG
# A1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTEzMTAyMjEyMDAw
# MFoXDTI4MTAyMjEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lD
# ZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGln
# aUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAPjTsxx/DhGvZ3cH0wsxSRnP0PtFmbE620T1
# f+Wondsy13Hqdp0FLreP+pJDwKX5idQ3Gde2qvCchqXYJawOeSg6funRZ9PG+ykn
# x9N7I5TkkSOWkHeC+aGEI2YSVDNQdLEoJrskacLCUvIUZ4qJRdQtoaPpiCwgla4c
# SocI3wz14k1gGL6qxLKucDFmM3E+rHCiq85/6XzLkqHlOzEcz+ryCuRXu0q16XTm
# K/5sy350OTYNkO/ktU6kqepqCquE86xnTrXE94zRICUj6whkPlKWwfIPEvTFjg/B
# ougsUfdzvL2FsWKDc0GCB+Q4i2pzINAPZHM8np+mM6n9Gd8lk9ECAwEAAaOCAc0w
# ggHJMBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQM
# MAoGCCsGAQUFBwMDMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MIGBBgNVHR8E
# ejB4MDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1
# cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsME8GA1UdIARIMEYwOAYKYIZIAYb9
# bAACBDAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BT
# MAoGCGCGSAGG/WwDMB0GA1UdDgQWBBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAfBgNV
# HSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG9w0BAQsFAAOCAQEA
# PuwNWiSz8yLRFcgsfCUpdqgdXRwtOhrE7zBh134LYP3DPQ/Er4v97yrfIFU3sOH2
# 0ZJ1D1G0bqWOWuJeJIFOEKTuP3GOYw4TS63XX0R58zYUBor3nEZOXP+QsRsHDpEV
# +7qvtVHCjSSuJMbHJyqhKSgaOnEoAjwukaPAJRHinBRHoXpoaK+bp1wgXNlxsQyP
# u6j4xRJon89Ay0BEpRPw5mQMJQhCMrI2iiQC/i9yfhzXSUWW6Fkd6fp0ZGuy62ZD
# 2rOwjNXpDd32ASDOmTFjPQgaGLOBm0/GkxAG/AeB+ova+YJJ92JuoVP6EpQYhS6S
# kepobEQysmah5xikmmRR7zGCAigwggIkAgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20x
# MTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcg
# Q0ECEALqUCMY8xpTBaBPvax53DkwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwx
# CjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGC
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFKJ22WA8QZz/uelB
# P5yRS6gQiScEMA0GCSqGSIb3DQEBAQUABIIBABBbkyQborZ8VGPA7S1USK2PMuM3
# xnsd1TvA5FzVZ1bO3ddXxzbGIcHm77R5gdPgfj7/ozgD2p6vHaPY92l5j1F9843Y
# cthvWlbBbKuF2ckaazmjTfMKn1TAmvUrzXfcJBobpg0H6lnHHcLzKyqj4T+xEYta
# BeHEusf6SxwoIQewAtq3pO5/OqXo9kkGeAjFdU5G2b8P/Z9xqEWpnHCACRjE3qWM
# aF2Qo/pe7105njpS1Ph1oo8rqWvWZVZ8Qydh31CO9jeEAcZAOsbYK4h2Hpbja83u
# hnwWfaCPClTUjmsda6qYmVpanYWE5VPObgOaAaKmforYm+Z2aRwPXl8/fD0=
# SIG # End signature block
