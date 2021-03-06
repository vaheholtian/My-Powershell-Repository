function Start-PSNode
{
    <#
    .Synopsis
        Starts a lightweight local server
    .Description
        Starts a lightweight local server that uses the HttpListener class to create a simple server.  
        
        This server is unlike the Pipeworks in ASP.NET in many interesting ways:
        
        - Unlike Pipeworks within ASP.NET which lets each user have their own runspace, PSNode puts all users in the same runspace.  
        This makes it faster, and means all people connected share a lot of the same information (for better and worse).  
        Additionally, this runspace does not contain any modules, but can load any modules you have.
        - Unlike Pipeworks within ASP.NET, which runs in an Application Pool as the context of that restricted user, PSNode is always running as you and under and administrative account.
        This means a lot.  On the good side, it means you can do things ASP.NET cannot, like popping up a window on the desktop.  On the darker side, it means that if you allow arbitrary code execution in what you put up on PSNode, you have an endpoint that can do anything to a box in the context of the current user.
        - Unlike Pipeworks within ASP.NET, PSNode runs in any .exe
        This also means a lot.  
        PSNode may run within any process, and, because it is running in a process, certain components that require a permission associated with an interactive process will execute in PSNode and not in Pipeworks under ASP.NET    
    
    
        PSNode was inspired by a presentation from Bruce Payette at the PowerShell Deep Dive @ TEC2011 in Frankfurt, Germany
    .Example
        Start-PSNode -Server http://localhost:9090 -Command {
            "Hello World"
        }
    .Example
        Start-PSNode -Server http://localhost:9092/ -AuthenticationType IntegratedWindowsAuthentication -Command {
            "Hello $($User.Identity.Name)"
        }    
    #>
    [OutputType([Management.Automation.Job])]    
    param(
    # The server url, ie. http://localhost:9090/
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [string]$Server,
    
    # The command to run within the server
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]   
    [ScriptBlock]$Command,
    
    # The authentication type
    [Net.AuthenticationSchemes]
    $AuthenticationType = "Anonymous", 
    
    # If set, will not return
    [Switch]$DoNotReturn    
    )

    begin {
        $ll = @()
        $lc  = @()
        $definePSNode = {
        Add-Type -IgnoreWarnings @'
using System;
using System.Collections.Generic;
using System.Text;
using System.Net;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;
using System.Security.Principal;

public class PSNode
{
    RunspacePool Pool
    {
        get
        {
            if (_pool == null)
            {
                _pool = RunspaceFactory.CreateRunspacePool();
                _pool.ThreadOptions = PSThreadOptions.ReuseThread;
                _pool.ApartmentState = System.Threading.ApartmentState.STA;
                _pool.Open();
            }
            return _pool;
        }
    }
    RunspacePool _pool;
    ScriptBlock action;
    
    private PSNode(ScriptBlock command)
    {
        WindowsIdentity current = System.Security.Principal.WindowsIdentity.GetCurrent();
        WindowsPrincipal principal = new WindowsPrincipal(current);
        if (!principal.IsInRole(WindowsBuiltInRole.Administrator))
        {
            throw new UnauthorizedAccessException();
        }

        this.action = command;        
    }
    
    
        
    public static AsyncCallback GetCallback(ScriptBlock action)
    {
        PSNode instance = new PSNode(action);
        
        return new AsyncCallback(instance.ListenerCallback);
    }

    public void ListenerCallback(IAsyncResult result)
    {
        try
        {
            HttpListener listener = (HttpListener)result.AsyncState;

            // Call EndGetContext to complete the asynchronous operation.        
            HttpListenerContext context = listener.EndGetContext(result);
            HttpListenerRequest request = context.Request;

            // Obtain a response object.
            HttpListenerResponse response = context.Response;

            string responseString = "";
            using (
                PowerShell command = PowerShell.Create()
                                            .AddScript(action.ToString(), false)
                                                .AddArgument(request)
                                                    .AddArgument(response)
                                                        .AddArgument(context)
                                                            .AddArgument(context.User)
            )
            {
                command.RunspacePool = Pool;
                
                int offset = 0;

                try
                {
                    foreach (PSObject psObject in command.Invoke<PSObject>())
                    {
                        if (psObject.BaseObject == null) { continue; }
                        byte[] buffer = System.Text.Encoding.UTF8.GetBytes(psObject.ToString());
                        response.OutputStream.Write(buffer, offset, buffer.Length);
                        offset += buffer.Length;
                    }
                    foreach (ErrorRecord error in command.Streams.Error)
                    {
                        byte[] buffer = System.Text.Encoding.UTF8.GetBytes("<span style='color:red'>"  + error.Exception.Message  + " at "  + error.InvocationInfo.PositionMessage + "</span>");
                        response.OutputStream.Write(buffer, offset, buffer.Length);
                        offset += buffer.Length;
                    }
                }
                catch (Exception ex)
                {
                    byte[] buffer = System.Text.Encoding.UTF8.GetBytes(ex.Message);
                    response.StatusCode = 500;
                    response.OutputStream.Write(buffer, offset, buffer.Length);
                    offset += buffer.Length;
                }
                finally
                {
                    response.Close();
                }
            }
        }
        catch (Exception e)
        {
        }
    }


}
'@    
        }
    }

    process {
        
        $listenerLocation = $server
        if ($listenerLocation -notlike "*/") {
            $listenerLocation += "/"
        }
        $ListenerCommand = $command
        
        $ll += $listenerLocation
        $lc += $listenerCommand
    } 

    end {
        $StartTime  =Get-Date
          
         
        
             
        
        $node = for ($i = 0; $i -lt $ll.Count; $i++) {
            $listenerLocation = $ll[$i]
            $listenerCommand = $lc[$i]
            
            Start-Job -InitializationScript $definePSNode -ArgumentList $listenerLocation, $ListenerCommand, $AuthenticationType -Name $listenerLocation -ScriptBlock {
                param($listenerLocation, $listenerCommand, $AuthenticationType) 
                
                # Create a listener and add the prefixes.
                $listener = New-Object System.Net.HttpListener
                $listener.AuthenticationSchemes =$AuthenticationType
                $listener.Prefixes.Add($ListenerLocation);

                # Start the listener to begin listening for requests.
                $listener.Start();
                $callBack = [PSNode]::GetCallback(
                    [ScriptBLock]::create('param($request, $response, $context, $user)
                    if ("$($request.QueryString)") {        
                        $query = ([uri]$request.RawUrl -split "/")[-1]                
                        $query.TrimStart("?") -split "&" |
                            ForEach-Object -Begin {
                                $requestParams = @{}
                            } -Process { 
                                $key, $value = $_ -split "="
                                $requestParams[[Web.HttpUtility]::UrlDecode($key)] = [Web.HttpUtility]::UrlDecode($value)
                            } -End {
                                $request | 
                                    Add-Member NoteProperty Params $RequestParams -Force 
                            }                                
                    }
                ' + $ListenerCommand)) 

                if (-not $callback) { return } 

                while (1)
                {
                    $result = $listener.BeginGetContext($callback, $listener);    
                    $null = $result.AsyncWaitHandle.WaitOne();    
                }

                $listener.Close()            
            }
        }
         
        
        if ($DoNotReturn) {
            do {
                Write-Progress "Pipeworks PSNode Running on $ListenerLocation" "Since $StartTime" 
                $node | Receive-Job
                Start-Sleep -Seconds 1 
            } while(1)
            return   
        }        
        
        
        $node
        

    }

} 

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUz5ctHQBW5acs2/pv8blOfMtr
# WQWgggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFDCGTfacaI0b9X/R
# uPbbiFNViZeIMA0GCSqGSIb3DQEBAQUABIIBALDwHb9o4ZN9cxEnoaHs+4XhcVTS
# u64NsTc75KdykOvVKfgVYYCcnvpPhQsfH14HbvDc5gzgcdMPg9i0aLx07UJr8DoW
# hXiYl7Cwfftw52aHpqTXtG4m1DVtfK6HYGL5J/JSVsN5dUJzG6CvIsXa/ybaMxlv
# /zixbSbhURgXkYFA5EhELMv0JVvYcSqXF9ugAi7DbsTtVY6mZu5RVWskMBw2JE3I
# QvvEIX/N2n0Pmrxqw1DvTan6UTKrjd1BfBFnjWtU+3g5MLCxVrvD/dV2Ld/uM0Rr
# CPEvYm2/SPFtzYD8YaEzcfK1PE5E+X5sVD+ANnphcMSydZjPOgq32WtfbaQ=
# SIG # End signature block
