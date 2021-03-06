function Repair-Command
{
    <#
    .Synopsis
        Repair-Command attempts to fix your scripts.
    .Description
        Repair-Command will use a set of repair scripts to attempt to automatically
        resolve an issue uncovered with ScriptCop.

        Repair-Command will take all issues thru the pipeline, and will output 
        an object with the Rule, Problem, ItemWithProblem, and WasFixed.    
    .Link
        Test-Command
    .Example
        Get-Module MyModule | Test-Command | Repair-Command
    #>
    param(
    # The Rule that flagged the problem
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [ValidateScript({
        if ($_ -is [Management.Automation.CommandInfo]) {
            return $true
        }
        if ($_ -is [Management.Automation.PSModuleInfo]) {        
            return $true
        } 
        
        throw 'Must be a CommandInfo or a PSModuleInfo'            
    })]
    [PSObject]$Rule,
    
    # The Problem
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [Management.Automation.ErrorRecord]
    $Problem,
    
    # The Item with the Problem
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [ValidateScript({
        if ($_ -is [Management.Automation.CommandInfo]) {
            return $true
        }
        if ($_ -is [Management.Automation.PSModuleInfo]) {        
            return $true
        } 
        
        throw 'Must be a CommandInfo or a PSModuleInfo'            
    })]
    [PSObject]$ItemWithProblem,
    
    # If set, only fixers which have indicated they will not require user interaction will be run.
    [Switch]$NotInteractive
    )
    
    #region Initialize The List of Problems
    begin {

        # Make a quick pair of functions to help people output the right thing
        function CouldNotFixProblem
        {
            param([string]$ErrorId)
            
            $info = @{
                WasIdentified=$false
                CouldFix=$false                
                WasFixed=$false
                ErrorId = $errorID
                Problem=$Problem
                ItemWithProblem=$ItemWithProblem
                Rule=$Rule
                FixRequiresRescan=$false
            }
            
            New-Object PSObject -Property $Info
        }                        
                
        function TriedToFixProblem
        {
            param([string]$ErrorId,
            [Switch]$FixRequiresRescan)
            
            $stillHasThisProblem = $ItemWithProblem | 
                Test-Command -Rule "$Rule" |
                Where-Object {                     
                    $_.Problem.FullyQualifiedErrorId -like "$ErrorId*"                    
                }
                        
            New-Object PSObject -Property @{
                WasIdentified = $true
                CouldFix = $true
                WasFixed = -not ($stillHasThisProblem -as [bool])
                ErrorId = $errorId
                Problem=$Problem
                ItemWithProblem=$ItemWithProblem
                Rule=$Rule
                FixRequiresRescan=$FixRequiresRescan
            } 
        }        

        
        # Declare a list to hold the problems (for speed)
        $problems = New-Object Collections.ArrayList
        
        
    }  
    #endregion 
    
    #region Add Each Problem to the List
    process {
        $null = $problems.Add((New-Object PSObject -Property $psBoundParameters))
        Write-Verbose "Processing
$($_ | Out-String)
" 
    }
    #endregion  
    
    
    end {
        try {
            #region Fix the Problems That You Can
            $script:ScriptCopFixers |
                ForEach-Object -Begin {
                    $holdUp = $false
                } {
                    $fixer = $_
                                    
                    $problems | 
                        & $fixer | 
                        ForEach-Object {
                            $fix = $_
                            if ($_.FixRequiresRescan) {
                                $holdUp = $true
                            }
                            throw $holdup
                        }
                        
                    trap 
                    {
                        if (-not (Get-Variable -Scope 1 -Name holdUp -ErrorAction SilentlyContinue)) { 
                            throw $_ 
                        } else { break }                                         
                    }                    
                }
        } catch {
            if ($_.InvocationInfo.Line -like '*throw $holdup*') {
                Write-Warning "Fixed $($fix.Problem) on $($Fix.ItemWithProblem), but that fix changed files, so you must rescan"
                return
            } else {
                Write-Error -ErrorRecord $_
                return
            }
        }
        #endregion                                          
    }       
} 

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUdzoZRaBuJrh05X2YVzxMmH8Y
# fTGgggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFBSi4a/0m/+UYcnB
# XOShxINlqkHQMA0GCSqGSIb3DQEBAQUABIIBAC38htBnIwU0UbXTldqp/4aiQp3t
# 1LPVtgxYm5unVwDrT93wXrjzNiRTuCGA3NTv8jJX0drzNxTglYDp/dyVCi9cruAZ
# yFpA2k7kTHW+q4Tw3nzOCG15FtSmbb6mDHUMTcYVE+MuHkMA9ny1HypNrkm1FWPP
# 1888QW/OKu8wkzaJ3MLqJPipVzI/VL4+pHoTXfmOES/V/gVDXj4sIwQ0YcyOFIp9
# 83SJXQ0c8qFUjV7vMY1zq7wby5+8bKaspkqPCUKDmcXW5XKLuCotVlSzVoMJRtag
# +y73AfeLMWgy5toE3y2KIqrO1eTqPGwrT5PqOP/4B8BrZMnJnPOinnSu5T8=
# SIG # End signature block
