function Join-Website
{
    param(        
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Hashtable]$RequiredInfo,
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Hashtable]$OptionalInfo,
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$StorageAccountSetting = "AzureStorageAccountName",
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$StorageKeySetting = "AzureStorageAccountKey",
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$SmtpServer,
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]$UseSsl,
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$FromEmail,
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$FromUser,
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$EmailPasswordSetting,
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$TermsOfService,
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$ExchangeServer,
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$UserTable,
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$IntroMessage,

    [Parameter(ValueFromPipelineByPropertyName=$true)]    
    [string]$ConfirmationMailSentMessage,
        
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$userPartition = "Users",
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$FacebookAppId,
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Double]$InitialBalance = 0,
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Double]$LockoutBalance = -10,
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$BlacklistParition,
    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$WhitelistPartition,
    
    # The URL for the website
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [string]$WebsiteUrl
    )
    
    process {
        if (-not ($Request -and $Response -and $Session)) {
            throw "Must run within a web site"
        }
        
        $finalUrl = if ($WebSiteUrl -like "*Module.ashx") {
            $WebSiteUrl 
        } else {
            "$WebSiteUrl".TrimEnd("/") += "/Module.ashx"
        }
    
        $siteName = if ($module.Name) {
            $module.Name
        } else {
            "Website"
        }
        $DisplayForm = $false
        $FormErrors = ""
                                    
        if (-not $request["Join-${siteName}_EmailAddress"]) {
            #$missingFields 
            $displayForm = $true
        }
        
        $newUserData =@{}
        
        $missingFields = @()
        $paramBlock = @()
        if ($session['ProfileEditMode'] -eq $true) {
            $editMode = $true
        }
        $defaultValue = if ($editMode -and $session['User'].UserEmail) {
            "|Default $($session['User'].UserEmail)"
        } else {
            ""
        }
        
        if ($Request['ReferredBy']) {
            $session['ReferredBy'] = $Request['ReferredBy']
        }
        
        $paramBlock += "
        #$defaultValue
        [Parameter(Mandatory=`$true,Position=0)]
        [string]
        `$EmailAddress
        "
        
        if ($RequiredInfo) {
        
            $Position = 1
        
            foreach ($k in $RequiredInfo.Keys) {
                $newUserData[$k] = $request["Join-${siteName}_${k}"] -as $RequiredInfo[$k]
                $defaultValue = if ($session['User'].$k) {
                    "|Default $($session['User'].$k)"
                } else {
                    ""
                }
                
                $paramBlock += "
        #$defaultValue
        [Parameter(Mandatory=`$true,Position=$position)]
        [$($RequiredInfo[$k].Fullname)]
        `$$k
        "
                $Position++
                if (-not $newUserData[$k]) { 
                    $missingFields += $k
                }
            }
        
        }
        
        
        if ($OptionalInfo) {
        
            foreach ($k in $OptionalInfo.Keys) {
                $newUserData[$k] = $request["Join-${siteName}_${k}"] -as $OptionalInfo[$k]
                $defaultValue = if ($session['User'].$k) {
                    "|Default $($session['User'].$k)"
                } else {
                    ""
                }
                $paramBlock += "
        #${defaultValue}
        [Parameter(Position=$position)]
        [$($OptionalInfo[$k].Fullname)]
        `$$k
        "
            }
        
        }
        
        
        if ($TermsOfService) {
        
        }
        
        .([ScriptBlock]::Create(
            "function Join-$Sitename {
                <#
                .Synopsis
                    Joins $Sitename or edits a profile
                .Description
                       
                #>
                param(
                $($paramBlock -join ",$([Environment]::NewLine)")
                )
            }                
            "))
        
        $cmdInput = Get-WebInput -CommandMetaData (Get-Command "Join-$Sitename" -CommandType Function)
        if ($cmdInput.Count -gt 0) {
            $DisplayForm = $false
        }
        
        
        if ($missingFields) {
            $email = $request["Join-${siteName}_EmailAddress"]
            $emailFound = [ScriptBlock]::Create("`$_.UserEmail -eq '$email'")
            $storageAccount = (Get-WebConfigurationSetting -Setting $StorageAccountSetting)
            $storageKey = (Get-WebConfigurationSetting -Setting $StorageKeySetting)

            $mailAlreadyExists = 
                Search-AzureTable -TableName $UserTable -StorageAccount $storageAccount -StorageKey $storageKey  -Where $emailFound

            if (-not $mailAlreadyExists) {
                # Get required fields
                $DisplayForm = $true
            } elseif ($editMode -and $session['User']) {
                # Get required fields
                $DisplayForm = $true
            } else {
                # Reconfirm
                $DisplayForm = $false
            }
            
        }

                
        $sendMailParams = @{
            BodyAsHtml = $true
            To = $request["Join-${siteName}_EmailAddress"]
            
        }
        
        $sendMailCommand = if ($SmtpServer -and $FromEmail -and $FromUser -and $EmailPasswordSetting) {
            $($ExecutionContext.InvokeCommand.GetCommand("Send-MailMessage", "All"))
            $un  = $FromUser
            $pass = Get-WebConfigurationSetting -Setting $EmailPasswordSetting
            $pass = ConvertTo-SecureString $pass  -AsPlainText -Force 
            $cred = 
                New-Object Management.Automation.PSCredential ".\$un", $pass 
                    
            $sendMailParams += @{
                SmtpServer = $SmtpServer 
                From = $FromEmail
                Credential = $cred
                UseSsl = $useSsl
            }

        } else {
            $($ExecutionContext.InvokeCommand.GetCommand("Send-Email", "All"))
            $sendMailParams += @{
                UseWebConfiguration = $true
                AsJob = $true
            }
        }
        
        
        if ($displayForm) {
            $formErrors = if ($missingFields -and ($cmdInput.Count -ne 0)) {
                "Missing $missingFields"
            } else {
            
            }                                
            
            $buttonText = if ($mailAlreadyExists -or $session['User']) {
                "Edit Profile"                    
            } else {
                "Join / Login"
            }

            
            "
            $FormErrors
            $(Request-CommandInput -ButtonText $buttonText -Action "${WebsiteUrl}?join=true" -CommandMetaData (Get-Command "Join-${siteName}" -CommandType Function))
            "
            
        } else {
            $session['UserEmail'] = $request["Join-${siteName}_EmailAddress"]
            $session['UserData'] = $newUserData
            $session['EditMode'] = $editMode
            
            
            $storageAccount = (Get-WebConfigurationSetting -Setting $StorageAccountSetting)
            $storageKey = (Get-WebConfigurationSetting -Setting $StorageKeySetting)

            $email = $Session['UserEmail']
            $editMode = $session['EditMode']
            $session['EditMode'] = $null
            $emailFound = [ScriptBlock]::Create("`$_.UserEmail -eq '$email'")

            $userProfilePartition = $userPartition                

            
            $mailAlreadyExists = 
                Search-AzureTable -TableName $UserTable -StorageAccount $storageAccount -StorageKey $storageKey  -Where $emailFound |
                Where-Object {
                    $_.PartitionKey -eq $userProfilePartition
                }
            
            
            $newUserObject = New-Object PSObject -Property @{
                UserEmail = $Session['UserEmail']
                UserID = [GUID]::NewGuid()
                Confirmed = $false
                Created = Get-Date                
            }
            
            
            $ConfirmCode = [Guid]::NewGuid()
            $newUserObject.pstypenames.clear()
            $newUserObject.pstypenames.add("${siteName}_UserInfo")
            
            $extraPropCommonParameters = @{
                InputObject = $newUserObject
                MemberType = 'NoteProperty'
            }
                    
            Add-Member @extraPropCommonParameters -Name ConfirmCode -Value "$confirmCode"
            if ($session['UserData']) {
                foreach ($kvp in $session['UserData'].GetEnumerator()) {
                    Add-Member @extraPropCommonParameters -Name $kvp.Key -Value $kvp.Value
                }
            }
            
            $commonAzureParameters = @{
                TableName = $UserTable
                PartitionKey = $userProfilePartition
            }
            
            
            
            if ($mailAlreadyExists) {
                                                
                if ((-not $editMode) -or (-not $session['User'])) {
                
                    # Creating a brand new item via the email system.  Email the confirmation code out.                                
                    $rootLocation= "$finalUrl".Substring(0, $finalUrl.LAstIndexOf("/"))
                    $introMessage = if ($IntroMessage) {
                        $IntroMessage + "<br/> <a href='${finalUrl}?confirmUser=$confirmCode'>Confirm Email Address</a>"
                    } else {
                        "<br/> <a href='${finalUrl}?confirmUser=$confirmCode'>Re-confirm Email Address to login</a>"
                    }
                    
                    $sendMailParams += @{
                        Subject= "Please re-confirm your email for ${siteName}"
                        Body = $introMessage
                    }                    
                    
                    
                    & $sendMailcommand @sendMailParams 
                    
                    "Account already exists.  A request to login has been sent to $($mailAlreadyExists.UserEmail)." |
                        New-WebPage -Title "Email address is already registered, sending reconfirmation mail" -RedirectTo $rootLocation -RedirectIn "0:0:5"  |
                        Out-HTML -WriteResponse                                                           #
                        
                    <# Send-Email -To $newUserObject.UserEmail -UseWebConfiguration - -Body $introMessage -BodyAsHtml -AsJob                
                    "Account already exists.  A request to login has been sent to $($mailAlreadyExists.UserEmail)." |
                        New-WebPage -Title "Email address is already registered, sending reconfirmation mail" -RedirectTo $rootLocation -RedirectIn "0:0:5"  |
                        Out-HTML -WriteResponse                                                           #>
                    
                    $mailAlreadyExists |
                        Add-Member NoteProperty ConfirmCode "$confirmCode" -Force -PassThru | 
                        Update-AzureTable @commonAzureParameters -RowKey $mailAlreadyExists.RowKey -Value { $_}
                } else {
                    
                    # Reconfirmation of Changes.  If the user is logged in via facebook, then simply make the change.  Otherwise, make the changes pending.
                    if (-not $FacebookAppId) {
                    
                        $introMessage = 
                        "<br/> <a href='${finalUrl}?confirmUser=$confirmCode'>Please confirm changes to your ${siteName} account</a>"                   
                        
                        $introMessage += "<br/><br/>"
                        $introMessage += New-Object PSObject -Property $session['UserData'] |
                            Out-HTML
                     
                        $sendMailParams += @{
                            Subject= "Please confirm changes to your ${siteName} account"
                            Body = $introMessage
                        }   
                        
                        & $sendMailcommand @sendMailParams
                        
                        "An email has been sent to $($mailAlreadyExists.UserEmail) to confirm the changes to your acccount" |
                            New-WebPage -Title "Confirming Changes" -RedirectTo $rootLocation -RedirectIn "0:0:5" |
                            Out-HTML -WriteResponse
                        
                        $mailAlreadyExists |
                            Add-Member NoteProperty ConfirmCode "$confirmCode" -Force -PassThru | 
                            Update-AzureTable @commonAzureParameters -RowKey $mailAlreadyExists.RowKey -Value { $_}
                        $changeToMake = @{} + $commonAzureParameters
                        
                        $changeToMake.PartitionKey = "${userProfilePartition}_PendingChanges"
                                            
                        # Create a row in the pending change table
                        $newUserObject.psobject.properties.Remove('ConfirmCode')
                        $newUserObject |
                            Set-AzureTable @changeToMake -RowKey {[GUID]::NewGuid() } 
                    } else {
                        # Make the profile change
                        $newUserObject |
                            Update-AzureTable @commonAzureParameters -RowKey $mailAlreadyExists.RowKey
                    }
                    
                        
                        
                }
                
                
            } else {
                # Check for a whitelist or blacklist within the user table
                if ($BlacklistPartition) {
                    $blackList = 
                        Search-AzureTable -TableName $pipeworks.UserTable.Name -Filter "PartitionKey eq '$($BlacklistPartition)'"                        
                        
                    if ($blacklist) {
                        foreach ($uInfo in $Blacklist) {
                            if ($newUserObject.UserEmail -like "*$uInfo*") {
                                Write-Error "$($newUserObject.UserEmai) is blacklisted from ${siteName}"
                                return
                            }
                        }
                    }
                }
                
                if ($WhitelistPartition) {
                    $whiteList = 
                        Search-AzureTable -TableName $pipeworks.UserTable.Name -Filter "PartitionKey eq '$($WhitelistParition)'"                        
                        
                    if ($whiteList) {
                        $inWhiteList = $false
                        foreach ($uInfo in $whiteList) {
                            if ($newUserObject.UserEmail -like "*$uInfo*") {
                                $inWhiteList = $true
                                break
                            }
                        }
                        if (-not $inWhiteList) {
                            Write-Error "$($newUserObject.UserEmai) is not on the whitelist for ${siteName}"
                        }
                    }

                }
                
                if ($InitialBalance) {
                    $newUserObject | 
                        Add-Member NoteProperty Balance (0- ([Double]$pipeworksManifest.UserTable.InitialBalance))
                }
            
                if ($session['RefferedBy']) {
                    $newUserObject |
                        Add-Member NoteProperty RefferedBy $session['RefferedBy'] -PassThru |
                        Add-Member NoteProperty RefferalCreditApplied $false 
                }
            
                $newUserObject |
                    Set-AzureTable @commonAzureParameters -RowKey $newUserObject.UserId
                    
                    
                $introMessage = if ($IntroMessage) {
                    $IntroMessage + "<br/> <a href='${finalUrl}?confirmUser=$confirmCode'>Confirm Email Address</a>"
                } else {
                    "<br/> <a href='${finalUrl}?confirmUser=$confirmCode'>Confirm Email Address</a>"
                }
                
                $sendMailParams += @{
                    Subject= "Please confirm your email for ${siteName}"
                    Body = $introMessage
                }
                & $sendMailcommand @sendMailParams
                                
                if ($passThru) {
                    $newUserObject
                }
                
                $almostWelcomeScreen  = if ($ConfirmationMailSentMessage) {
                    $ConfirmationMailSentMessage
                } else {
                    "A confirmation mail has been sent to $($newUserObject.UserEmail)"
                }
                                
                $html = New-Region -Content $almostWelcomeScreen -AsWidget -Style @{
                    'margin-left' = $MarginPercentLeftString
                    'margin-right' = $MarginPercentRightString
                    'margin-top' = '10px'   
                    'border' = '0px' 
                } |
                New-WebPage -Title "Welcome to ${siteName} | Confirmation Mail Sent" 
                
                $html
                
                
            }
            
        }    
    
    }    
} 

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUai5DTr50bSivXD7+JCnZgn9N
# dpigggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFIjPmmVpk1j+JLgk
# mtCAjUxynrlYMA0GCSqGSIb3DQEBAQUABIIBAEuyUfl1uWNv0GJn0EccamuW304O
# RFHXvkzSlPYQUWpH0Ocwnzl+6ycKAclT6f7tstFXizmfh3KGG/Go9RO4UIr4ncQD
# Ev0xysVlP5XvyDxJ1qlIhgVALPG11YXxKn3ijdJUZCPzEXk/vtMnbGcHiSL83DDz
# SDLQmsU77yXpXv193rJvctLSg55ny5IBN9tBmcUjtDxhsS1Ert6U7SfC015mNHa6
# Cby2fhoA1I6Gpddqi/dduT7IXPhTNPZ20ePzx/pEf280459IU4GxgIDEXlbxkVP0
# kXcx3EOqIN02+z22We1WQ835FhYv8GW3spOLIiMq4WL4BuFcTkokkUWK0ho=
# SIG # End signature block
