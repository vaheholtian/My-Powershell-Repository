function Enable-EC2Remoting
{
    <#
    .Synopsis
        Enables an EC2 instance for various remote access
    .Description
        Enables common services on an EC2 instance
    .Example
        Get-EC2 |
            Enable-EC2Remoting -PowerShell    
    .Link
        Open-EC2Port
    #>
    param(
    # The EC2 Instance ID
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [string]$InstanceId,

    # If set, will open the port for PowerShell remote management and attempt to enable it on the box.
    [switch]$PowerShell,
    
    # If set, will open the port for PowerShell remote management with CredSSP and attempt to enable it on the box.
    [Switch]$PowerShellCredSSP,
    
    # If set, will open SSH
    [Switch]$Ssh,
    
    # If set, will open Echo (aka Ping)
    [Alias('Ping')]
    [Switch]$Echo,
    
    # If set, will open HTTP
    [Switch]$Http,
    
    # If set, will open HTTPS
    [Switch]$Https,
    
    # If set, will open RemoteDesktop
    [Switch]$RemoteDesktop
    )
    
    
    process {
        $ec2Instance = Get-EC2 -InstanceId $InstanceId 
        if ($Ssh) {
            $ec2Instance  | 
                Open-EC2Port -Range 22 -ErrorAction SilentlyContinue                
        }
        
        if ($echo) {
            $ec2Instance  | 
                Open-EC2Port -Range 7 -ErrorAction SilentlyContinue                                 
        }
        
        if ($ftp) {
            $ec2Instance  | 
                Open-EC2Port -Range 21 -ErrorAction SilentlyContinue                
        }
        
        if ($http) {
            $ec2Instance  | 
                Open-EC2Port -Range 80 -ErrorAction SilentlyContinue
        }
        
        if ($https) {
            $ec2Instance  | 
                Open-EC2Port -Range 443 -ErrorAction SilentlyContinue
        }
        
        if ($remoteDesktop -or $PowerShellCredSSP) {
            $ec2Instance  | 
                Open-EC2Port -Range 3389 -ErrorAction SilentlyContinue
        }
        
        if ($PowerShell -or $PowerShellCredSSP) {
            $ec2Instance  | 
                Open-EC2Port -Range 5985 -PassThru -ErrorAction SilentlyContinue | 
                Open-EC2Port -Range 5986 -ErrorAction SilentlyContinue 
        }
        
        if ($PowerShellCredSSP) {
            <#
            $ec2Pwd = $ec2Instance | 
                Get-EC2InstancePassword | 
                Select-Object -ExpandProperty Password |
                ConvertTo-SecureString -AsPlainText -Force
            $cred = New-Object Management.Automation.PSCredential 'Administrator', $ec2Pwd 
            
            
            # This is an incredibly useful yet dirty trick.
            
            # Remoting can be enabled, but enabling CredSSP on a target box technically requires CredSSP itself.  
            # So does nearly anything else that requires a credential.  
            # I can register a task (but only thru the command line tool), but said task actually requires someone to be logged on
            # in order to run
            # And so...
            
            
            $ec2Instance |
                Connect-EC2 
            
            
            
            Invoke-Command -ComputerName $ec2Instance.PublicDnsName -Credential $cred -ScriptBlock {
                $Soon= [DateTime]::Now.AddSeconds(45)
                $Soon= "{0:00}:{1:00}:{2:00}" -f $Soon.Hour,$Soon.Minute, $soon.Second
                $enableTaskNAme = "EnableTask$(Get-Random)"
                $r = schtasks /create /s localhost /tn $enableTaskNAme  /rl highest /st $Soon /SC Once /tr 'powershell.exe -command Enable-WSManCredSSP -Role Server -Force'
                $Soon= [DateTime]::Now.AddSeconds(45)
                $Soon= "{0:00}:{1:00}:{2:00}" -f $Soon.Hour,$Soon.Minute, $soon.Second
                $enableTaskNAme = "EnableTask$(Get-Random)"
                $r = schtasks /create /s localhost /tn $enableTaskNAme  /rl highest /st $Soon /SC Once /tr 'powershell.exe -command Enable-WSManCredSSP -Role Client -DelegateComputer * -Force'
            }
            
            Start-Sleep -Seconds 60
            
            $connectedWithCredSSP =
                Invoke-Command -ComputerName $ec2Instance.PublicDnsName -Credential $cred -ScriptBlock { "Connected with CredSSP" } -Authentication CredSSP                            
                
            New-Object PSObject |
                Add-Member NoteProperty ComputerName $ec2Instance.PublicDnsName -PassThru |
                Add-Member NoteProperty IsConnected ($connectedWithCredSSP -as [bool]) -PassThru
            #>
        }
        
    }
}



# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUmXYgArr6qei9zSBFQxHs1IBZ
# KpCgggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFKkdtt9r8RdX8D3y
# LQoNpPe4JgZmMA0GCSqGSIb3DQEBAQUABIIBAE2R4NF4ZHr4ruoisIssjoQzO9lJ
# gtJBRyLwaoa+IZ2h/llnWKklQ+Eeq29RPpuPmrmWZVrkFlJh09SJg5peHydaQXhr
# uOl2zvFlh0aQ8WLcslwptt1jga0vxX5f1GryvP/lpycbSSOIOVqIbWowNyc96eGA
# MxpDG/HNdk7dSVmwp1pYNWo1U2e6x8tZkv8A56cxNYQy4gfzntenIe3uNt1kB3pw
# EhJV2WIEbitwhwmWmRZHoLYwRy60IAKZlZd4Yi3DEXxfLr+F8t0TeHSZpmRUVzaT
# 7WNUi9XfwGiOukC9Jc0UlAh4iwUKzDc4ngW/YkDNrCHsCWfUWA/JqxRU9vQ=
# SIG # End signature block
