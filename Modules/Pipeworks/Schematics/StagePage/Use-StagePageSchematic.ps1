function Use-StagePageSchematic
{
    <#
    .Synopsis
        Builds a web application according to a schematic
    .Description
        Use-Schematic builds a web application according to a schematic.
        
        Web applications should not be incredibly unique: they should be built according to simple schematics.        
    .Notes
    
        When ConvertTo-ModuleService is run with -UseSchematic, if a directory is found beneath either Pipeworks 
        or the published module's Schematics directory with the name Use-Schematic.ps1 and containing a function 
        Use-Schematic, then that function will be called in order to generate any pages found in the schematic.
        
        The schematic function should accept a hashtable of parameters, which will come from the appropriately named 
        section of the pipeworks manifest
        (for instance, if -UseSchematic Blog was passed, the Blog section of the Pipeworks manifest would be used for the parameters).
        
        It should return a hashtable containing the content of the pages.  Content can either be static HTML or .PSPAGE                
    #>
    [OutputType([Hashtable])]
    param(
    # Any parameters for the schematic
    [Parameter(Mandatory=$true)][Hashtable]$Parameter,
    
    # The pipeworks manifest, which is used to validate common parameters
    [Parameter(Mandatory=$true)][Hashtable]$Manifest,
    
    # The directory the schemtic is being deployed to
    [Parameter(Mandatory=$true)][string]$DeploymentDirectory,
    
    # The directory the schematic is being deployed from
    [Parameter(Mandatory=$true)][string]$InputDirectory     
    )
    
    process {
    
        if (-not $Parameter.Stages) {
            Write-Error "No scenes found"
            return
        }
        
        if (-not $Parameter.CurtainColor) {
            Write-Error "Stage must have a curtain color"
            return
        }
        
        if (-not $Parameter.BackgroundColor) {
            Write-Error "Stage must have a background color"
            return
        }
        
        if (-not $parameter.StageColor) {
            Write-Error "Stage must have a stage color"
            return
        }
        
                               
        
        $stagesInTables = 
            $parameter.Stages.GetEnumerator() | 
                Where-Object { 
                    $_.Name -eq 'Scenes' -and $_.Value.GetEnumerator() |
                        Where-Object { $_.Id } 
                } 
        
        if ($stagesInTables) {
            if (-not $Manifest.Table.Name) {
                Write-Error "No table found in manifest"
                return
            }
            
            if (-not $Manifest.Table.StorageAccountSetting) {
                Write-Error "No storage account name setting found in manifest"
                return
            }
            
            if (-not $manifest.Table.StorageKeySetting) {
                Write-Error "No storage account key setting found in manifest"
                return
            }
        }
        
        
        $outputPages = @{}
        
        $orgName = $parameter.Organization.Name
        
        
        $orginfo = if ($parameter.Organization) {
            $parameter.Organization
        } else {
            @{}
        }
        
        
        foreach ($stage in @($parameter.Stages)) 
        {
            $stagePage = New-Object PSOBject -Property $stage
            $pageName = $stagePage.Name
            $pageHeaderImage = $stagePage.pageHeaderImage
                
            $pageIsDynamic = $stagesInTables -as [bool]
            
            $pageScript = "
`$pageTitle = '$pageName';
`$sceneOrder = '$(($stagePage.SceneOrder | foreach-object { $_.Replace("'","''") }) -join "','")'
`$pageHeaderImage = '$pageHeaderImage';
`$curtainColor = '$($parameter.curtainColor)';`
`$stageColor ='$($parameter.StageColor)';
`$bgColor = '$($parameter.BackgroundColor)';
`$fontName = '$(if ($parameter.FontName) {  $parameter.FontName }else { 'Gisha' } )'
`$scenes = $(Write-PowerShellHashtable -InputObject $parameter.Scenes)
`$orginfo= $(Write-PowerShellHashtable -InputObject $orginfo )
" + {
                           
$headerContent = 
    if ($pageHeaderImage) {
        "<img src='Assets/$pageHeaderImage' style='width:100%' />        
        "    
    } else {
        "<h1 style='text-align:center;font-size:xx-large;backgroundcolor:$curtainColor'>        
            $pageTitle
        </h1>
        "
    }
        
        
$showCommandOutputIfLoggedIn = {
    param($cmdName, [Hashtable]$CmdParameter = @{}) 
    if ($session['User']) {
        $loginName = if ($session['User'].Name) {
            $session['User'].Name
        } else {
            $session['User'].UserEmail
        }
        $commandInfo = Get-Command $cmdName        
        & $commandInfo @CmdParameter | Out-HTML
    } elseif ($request.Cookies["$($module.Name)_ConfirmationCookie"]) {
        Write-Link -Caption "Login as $($request.Cookies["$($module.Name)_ConfirmationCookie"]["Email"])?" -Url "Module.ashx?Login=true" |
        New-Region -LayerId "ShouldILogin_For_$cmdName" -Style @{
            'margin-left' = $MarginPercentLeftString
            'margin-right' = $MarginPercentRightString
        }
    } else { @"
<div id='loginHolder_For_$cmdName'>    
    
</div>
<script>
    query = 'Module.ashx?join=true'        
    `$(function() {
        `$.ajax({
            url: query,
            cache: false,
            success: function(data){     
                `$('#loginHolder_For_$cmdName').html(data);
            } 
        })
    })
</script>
"@
    }
}

$showCommandInputIfLoggedIn = { param($cmdName) 
    if ($session['User']) {
        $loginName = if ($session['User'].Name) {
            $session['User'].Name
        } else {
            $session['User'].UserEmail
        }
        Request-CommandInput -CommandMetaData (Get-Command $cmdName) -Action "$cmdName/?" 
    } elseif ($request.Cookies["$($module.Name)_ConfirmationCookie"]) {
        $out = ""
        $out += Write-Link -Caption "Login as $($request.Cookies["$($module.Name)_ConfirmationCookie"]["Email"])?" -Url "Module.ashx?Login=true" |
            New-Region -LayerId "ShouldILogin_For_$cmdName" -Style @{
                'margin-left' = $MarginPercentLeftString
                'margin-right' = $MarginPercentRightString
            }
        $out
    } else { @"
<div id='loginHolder_For_$cmdName'>    
    
</div>
<script>
    query = 'Module.ashx?join=true'        
    `$(function() {
        `$.ajax({
            url: query,
            cache: false,
            success: function(data){     
                `$('#loginHolder_For_$cmdName').html(data);
            } 
        })
    })
</script>
"@
    }
}


$editProfileIfLoggedIn = { 
    if ($session['User']) {
        @"
<div id='editProfileHolder'>    
    
</div>
<script>
    query = 'Module.ashx?editProfile=true'        
    `$(function() {
        `$.ajax({
            url: query,
            cache: false,
            success: function(data){     
                `$('#editProfileHolder').html(data);
            } 
        })
    })
</script>
"@
    } elseif ($request.Cookies["$($module.Name)_ConfirmationCookie"]) {
        $out = ""
        $out += Write-Link -Caption "Login as $($request.Cookies["$($module.Name)_ConfirmationCookie"]["Email"])?" -Url "Module.ashx?Login=true" |
            New-Region -LayerId "ShouldILogin_For_$cmdName" -Style @{
                'margin-left' = $MarginPercentLeftString
                'margin-right' = $MarginPercentRightString
            }
        $out
    } else { @"
<div id='loginToEditProfile'>    
    
</div>
<script>
    query = 'Module.ashx?join=true'        
    `$(function() {
        `$.ajax({
            url: query,
            success: function(data){     
                `$('#loginToEditProfile').html(data);
            } 
        })
    })
</script>
"@
    }
}
    
$header = 
    $headerContent |
        New-Region -LayerID InnerHeader -Style @{
            "margin-left" = "auto"
            "margin-right" = "auto"
            "background-color" = $curtainColor
            "color" = $bgColor
            "width" = '100%'
        } | 
        New-Region -LayerID OuterHeader -Style @{                
            "margin-left" = "5%"
            "margin-right" = "5%"
        } 


$layers = @{}
foreach ($scene in $scenes.GetEnumerator()) {
    $layers[$scene.Key] = 
        if ($scene.Value.Id) {
            $storageAccount = Get-WebConfigurationSetting -Setting $pipeworksManifest.Table.StorageAccountSetting
            $storageKey = Get-WebConfigurationSetting -Setting $pipeworksManifest.Table.StorageKeySetting
            $part, $row = $scene.Value.Id -split ":"
            Show-WebObject -Table $pipeworksManifest.Table.Name -Part $part -Row $row
        } elseif ($scene.Value.Content) {        
            $scene.Value.Content
        } elseif ($scene.Value.Command) {
            $cmdObj = Get-Command $scene.Value.Command
            if ($scene.Value.CollectInput) {
                if ($pipeworksManifest.WebCommand.($cmdObj.Name).RequireLogin -or 
                    $scene.Value.RequireLogin) {
                    
                    & $showCommandInputIfLoggedIn ($cmdObj.Name) 
                } else {
                    Request-CommandInput -CommandMetaData $cmdObj.Name -Action "$($cmdObj.Name)/" -DenyParameter $pipeworksManifest.WebCommand.($cmdObj.Name)       
                }
            } else {
                $getParameters = @{}
                if ($scene.Value.QueryParameter) {   
                    
                    foreach ($qp in $scene.Value.QueryParameter.GetEnumerator()) {
                        
                        if ($request[$qp.Key]) {
                            $getParameters += @{$qp.Value.Trim()=$request[$qp.Key].Trim()}
                        }
                        
                    }        
                    
                }
                
                if ($scene.Value.DefaultParameter) {
                    
                    foreach ($qp in $scene.Value.DefaultParameter.GetEnumerator()) {
                        $getParameters += @{$qp.Key=$qp.Value}                        
                    }
                }
                
                if ($getParameters.Count) {
                    if ($pipeworksManifest.WebCommand.($cmdObj.Name).RequiresLogin -or 
                        $kv.Value.RequireLogin) {
                        & $showCommandOutputIfLoggedIn ($cmdObj.Name) $getParameters | Out-HTML
                    } else {            
                        & $cmdObj @getParameters | Out-HTML
                    }
                } else {
                    ''
                }                
            }
           
            
               
        } elseif ($scene.Value.EditProfile -and $session['User']) {
            $displayName = $scene.Value.EditProfile
            $layers.Layer[$displayName] = & $editProfileIfLoggedIn        
        }
}



$style = @{
    border = "1px $curtainColor solid"
    'background-color' = "$stageColor"
    "margin-left" = "5%"
    "margin-right" = "5%"
    
}

$browserSpecificStyle =
    if ($Request.UserAgent -clike "*IE*") {
        @{'height'='60%';"margin-top"="-5px"}
    } else {
        @{'min-height'='60%'}
    }  
    
$style += $browserSpecificStyle

$LayerOrder = if ($sceneOrder) {
    $sceneOrder
} else {
    $layers.Keys | Sort-Object
}

$content = 
    New-Region -LayerID MainContent -AsPopIn -Order $layerOrder -Layer $layers -MenuBackgroundColor $curtainColor -Style $style

$footer = if ($orgInfo.Count) {
    "<p text-align='center' style='background-color:$curtainColor'>
<span itemprop='Address'>$($orgInfo.Address)</span> | <span itemprop='telephone'>$($orgInfo.telephone)</span><br><span style='font-size:xx-small'><span itemprop='name'>$($orgInfo.Name)</span> | Copyright $((Get-Date).Year)
</span></p>"
} else {
    " "
}

$footer = $footer| 
    New-Region -LayerID Footer -ItemType http://schema.org/Organization -Style @{
        "margin-left" = "5%"
        "margin-right" = "5%"  
        
        "background-color" = $curtaincolor
        "Color" = $stageColor
        "padding" = "10px"          
        "text-align" = "center"
    }
    
    
    
$header, $content, $footer | 
    New-WebPage -Css @{
        Body = @{
            "background-color" = $bgColor
            "font" = $fontName
        }
    } -Title "$pageTitle"
            
            } 
            
            if (-not $ouputPages.Count) {
                $outputPages["default.pspage"] = "<| $pageScript  |>"
            }
            $outputPages["$pageName.pspage"] = "<| $pageScript  |>"
                        
        }       
        
        $outputPages                         
        
        
                                           
    }        
} 
 


# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUZt4YjR1U/HkykQ31N9OD/Oe2
# huSgggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFJlPcvW0PAcGBMcW
# 5fOIzHi1CXPOMA0GCSqGSIb3DQEBAQUABIIBAHDJgC/bwxLZBvoxcVQ4Y1oLvHVz
# ofh2enJsX629sFU5bIHcFRMZ/z9azKTLlhiAuomRlVwHUBEisRJQ5qKugiP093ik
# fKKfD0metfNLS9whFX3xGGBk8IvgoNtZ7iu288nrxA+esHEOmcPySAtnAgtvVrN0
# gNxwfWIBTxD5GbnKUdKq6L/xJnGhgKc1LRQyXmq1SX82XWHO6ovkH3pl2havEJSZ
# y6BIHiRVTNuMoMfw7Fk+N+hWqadYnuF/qmIBBi4RSsIkU+LVd70iGRC4pl7Cd75x
# CbK0mQJ7u7QEshKVX+kxrEAQ+HR2zaxsC3DRCkuDKxksPKI1wcGxSV8DNFE=
# SIG # End signature block
