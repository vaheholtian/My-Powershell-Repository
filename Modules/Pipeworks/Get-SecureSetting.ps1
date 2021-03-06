function Get-SecureSetting
{
    <#
    .Synopsis
        Gets encrypted settings stored in the registry
    .Description
        Gets secured user settings stored in the registry
    .Example
        Get-SecureSetting
    .Example
        Get-SecureSetting MySetting
    .Example
        Get-SecureSetting MySetting -Decrypt
    .Example
        Get-SecureSetting MySetting -ValueOnly
    .Link
        Add-SecureSetting
    .Link
        Remove-SecureSetting
    .Link
        ConvertTo-SecureString
    .Link
        ConvertFrom-SecureString
    #>    
    [OutputType('SecureSetting')]
    param(
    # The name of the secure setting
    [Parameter(Position=0,ValueFromPipelineByPropertyName=$true)]
    [String]
    $Name,
    
    # The type of the secure setting
    [Parameter(Position=1,ValueFromPipelineByPropertyName=$true)]
    [Type]
    $Type,
    
    # If set, will decrypt the setting value
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $Decrypted,
    
    # If set, will decrypt the setting value and return the data
    [switch]
    $ValueOnly    
    )
    
    begin {
        $getSecureSetting = {
            $Obj = $_
            $typeName = $_.pschildName
            foreach ($propName in ($obj.psobject.properties | Select-Object -ExpandProperty Name)) {
                if ('PSPath', 'PSParentPath', 'PSChildName', 'PSProvider' -contains $propName) {
                    $obj.psobject.properties.Remove($propname)
                }
            }
            $Obj.psobject.properties | 
                ForEach-Object {
                    $secureSetting = New-Object PSObject 
                    $null = $secureSetting.pstypenames.add('SecureSetting')
                    $secureSetting | 
                        Add-Member NoteProperty Name $_.Name -PassThru |
                        Add-Member NoteProperty Type ($typename -as [Type]) -PassThru |
                        Add-Member NoteProperty EncryptedData $_.Value -PassThru 

                }
        }
    }
   
    process {
        # If Request and Response are present, Get-SecureSetting acts like Get-WebConfigurationSetting
        if ($Request -and $Response) {
            
            if ($Request -and $request.Params -and $request.Params['Path_Info']) {        
                $path  ="$((Split-Path $request['Path_Info']))"    
                            
                $webConfigStore = [Web.Configuration.WebConfigurationManager]::OpenWebConfiguration($path)                                                                                  
            } else {
                # Otherwise, use the global one
                $webConfigStore = [Web.Configuration.WebConfigurationManager]::OpenWebConfiguration($null)                                                                                              
            }    
            #endregion Load Config Store
            
            if ($name) {

                # Get the custom setting
                $customSetting = $webConfigStore.AppSettings.Settings["$name"];
                
                # If there is a value, return it.
                if ($CustomSetting) {
                    $CustomSetting.Value
                }
            }
            return
        } 
    
    
    
        #region Create Registry Location If It Doesn't Exist 
        $registryPath = "HKCU:\Software\Start-Automating\$($myInvocation.MyCommand.ScriptBlock.Module.Name)"
        $fullRegistryPath = "$registryPath\$($psCmdlet.ParameterSetName)"
        if (-not (Test-Path $fullRegistryPath)) {
            $null = New-Item $fullRegistryPath  -Force
        }   
        #endregion Create Registry Location If It Doesn't Exist
        
        Get-ChildItem $registryPath | 
            Get-ItemProperty | 
            ForEach-Object $getSecureSetting |
            Where-Object {
                if ($psBoundParameters.Name -and $_.Name -notlike "$name*") { return } 
                if ($psBoundParameters.Type -and $_.Type -ne $Type) { return } 
                $true
            } |
            ForEach-Object -Begin {
                $TempCredTable = @{}
            } -Process {
                if (-not ($decrypted -or $ValueOnly)) { return $_ }
                
                #region Decrypt and Convert Output
                $inputObject = $_
                if ([Hashtable], [string] -contains $_.Type) {
                    # Create a credential to unpack it
                    $convertedAgain  = 
                        New-Object Management.Automation.PSCredential ' ', ($_.EncryptedData | ConvertTo-SecureString)
                        
                    $decryptedValue= $convertedAgain.GetNetworkCredential().Password  
                    
                    if ($_.Type -eq [Hashtable]) {
                        $decryptedValue = . ([ScriptBlock]::Create($decryptedValue))
                    }
                } elseif ($_.Type -eq [Security.SecureString]) {
                    $decryptedValue= ($_.EncryptedData | ConvertTo-SecureString)
                } elseif ($_.Type -eq [Management.Automation.PSCredential]) {
                    # Create a credential to unpack the username, then create a credential with the unpacked password
                    $baseName = $_.Name -ireplace "_UserName", ""
                    if ($_.Name -like "*_UserName") {
                        $convertedAgain  = 
                            New-Object Management.Automation.PSCredential ' ', ($_.EncryptedData | ConvertTo-SecureString)
                            
                        $decryptedValue= $convertedAgain.GetNetworkCredential().Password  
                                
                        $tempCredTable["UserName"] = $decryptedValue
                    } elseif ($_.Name -like "*_Password") {                        
                                
                        $tempCredTable["Password"] = ($_.EncryptedData | ConvertTo-SecureString)
                    }
                }
                $null = $inputObject.psobject.properties.Remove('EncryptedData')
                if ($inputObject.Name -notlike "*_UserName") {
                    if ($inputObject.Name -like "*_Password") {
                        $inputObject | 
                            Add-Member NoteProperty Name $baseName -Force
                        $decryptedValue  =New-Object Management.Automation.PSCredential $tempCredTable["UserName"], $tempCredTable["PassWord"]
                    } 
                    $inputObject | 
                        Add-Member NoteProperty DecryptedData $decryptedValue -PassThru |
                        ForEach-Object {
                            if ($ValueOnly) {
                                $_.DecryptedData
                            } else {
                                $_
                            }
                        }               
                }
                #endregion Decrypt and Convert Output
            }
                    
    }

} 
 

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUqL6TWNuVrUvtYZc9qESErs3B
# x86gggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFEX1L8AK5yPgFwAI
# tG3YpbW5IqMKMA0GCSqGSIb3DQEBAQUABIIBADhKt9H3345JUXSg+2ExZJl3Yfnl
# zgKF1j2L5e7AIQKWqbrR8yW8OEKXQSLTEpK0Nc2BDV6VmRlKrwMlM/Mua4ciF3hL
# s9qbJ4Ob70UR+q1xG21Pkf3ct79B1RdiVcu/qI3QETg/bs2N8jzsIVBS5t5ahJXZ
# F9p9dsPCnT5qB3yqTOiR8BrxS6Jb3jpOyCKcmuMdVkb+QSjUrZS/OGWIdczIdKIZ
# nRJw9/2XkYj+th4Ddg88XGMzlLGFR6SpbyadAJ3k9AeORyEUe0DJP+dyuDBtQ7iD
# JKn6re0X5qwVeQ2BRLI+3yhsLOyAl9t593Io7lty8EibsFfmE7kB5Mw46B8=
# SIG # End signature block
