#requires -version 2.0
function Add-CropFilter {    
    <#
    .Synopsis
    Creates a filter for cropping images.

    .Description
    The Add-CropFilter function adds a Crop image filter to a filter collection.
    It creates a new filter collection if none exists. An image filter is Windows Image Acquisition (WIA) concept.
    Each filter represents a change to an image.

    Add-CropFilter does not crop images; it just creates a crop filter.
    To crop an image, use the Crop method of the Get-Image function, which uses a crop filter that Add-CropFilter creates, 
    or the Set-ImageFilter function, which applies the filters.

    All of the parameters of this function are optional. 
    Without parameters, Add-CropFilter creates an image filter collection.
    Then it creates a crop filter that is not specific to an image and will not crop image content (values for the Left, Top, Right, and Bottom parameters are 0).

    .Parameter Filter
        Enter a filter collection (Wia.ImageProcess COM object).
        Each filter in the collection represents a unit of modification to a WiA ImageFile object.
        This parameter is optional. If you do not submit a filter collection, Add-CropFilter creates one for you.

    .Parameter Image
        Creates a crop filter for the specified image.
        Enter an image object, such as one returned by the Get-Image function.
        This parameter is optional.
        If you do not specify an image, Add-CropFilter creates a crop filter that is not image-specific.

        If you do not specify an image, you cannot specify percentage values (values less than 1) for the
        Left, Top, Right, or Bottom parameters.

    .Parameter Left
        Specifies the how much to crop from the left side of the image.
        The default value is zero (0). To specify pixels, enter a value greater than one (1).
        To specify a percentage, enter a value less than one (1), such as ".25".
        Percentages are valid only when the command includes the Image parameter.

    .Parameter Top
        Specifies the how much to crop from the top of the image.
        The default value is zero (0). To specify pixels, enter a value greater than one (1).
        To specify a percentage, enter a value less than one (1), such as ".25".
        Percentages are valid only when the command includes the Image parameter.

    .Parameter Right
        Specifies the how much to crop from the right side of the image.
        The default value is zero (0).
        To specify pixels, enter a value greater than one (1).
        To specify a percentage, enter a value less than one (1), such as ".25".
        Percentages are valid only when the command includes the Image parameter.
    .Parameter Bottom
        Specifies the how much to crop from the bottom of the image.
        The default value is zero (0).
        To specify pixels, enter a value greater than one (1).
        To specify a percentage, enter a value less than one (1), such as ".25".
        Percentages are valid only when the command includes the Image parameter.

    .Parameter Passthru
        Returns an object that represents the crop filter.
        By default, this function does not generate output.

    .Notes
        Add-CropFilter uses the Wia.ImageProcess object.

    .Example
        Add-CropFilter –right 45 –bottom 22 –passthru

    .Example
        $i = get-image .\Photo01.jpg
        Add-CropFilter –image $i –top .3 -passthru

    .Example
        C:\PS> $cf = Add-CropFilter –passthru
        C:\PS> ($cf.filters | select properties).properties | format-table Name, Value –auto

        Name       Value
        ----       -----
        Left           0 
        Top            0
        Right         45
        Bottom        22
        FrameIndex     0


    .Example
        $image = Get-Image .\Photo01.jpg            
        $image = $image | Set-ImageFilter -filter (Add-CropFilter -Image $image -Left .1 -Right .1 -Top .1 -Bottom .1 -passThru) -passThru                    
        $image.SaveFile(".\Photo02.jpg")
    .Link
        Get-Image
    .Link
        Set-ImageFilter
    .Link
        Image Manipulation in PowerShell:
        http://blogs.msdn.com/powershell/archive/2009/03/31/image-manipulation-in-powershell.aspx
    .Link
        "ImageProcess object" in MSDN
        http://msdn.microsoft.com/en-us/library/ms630507(VS.85).aspx
    .Link
        "Filter Object" in MSDN 
        http://msdn.microsoft.com/en-us/library/ms630501(VS.85).aspx
    .Link
        "How to Use Filters" in MSDN
        http://msdn.microsoft.com/en-us/library/ms630819(VS.85).aspx
    #>
    param(
    [Parameter(ValueFromPipeline=$true)]
    [__ComObject]
    $filter,
    
    [__ComObject]
    $image,
        
    [Double]$left,
    [Double]$top,
    [Double]$right,
    [Double]$bottom,
    
    [switch]$passThru                      
    )
    
    process {
        if (-not $filter) {
            $filter = New-Object -ComObject Wia.ImageProcess
        } 
        $index = $filter.Filters.Count + 1
        if (-not $filter.Apply) { return }
        $crop = $filter.FilterInfos.Item("Crop").FilterId                    
        $isPercent = $true
        if ($left -gt 1) { $isPercent = $false }
        if ($top -gt 1) { $isPercent = $false } 
        if ($right -gt 1) { $isPercent = $false } 
        if ($bottom -gt 1) { $isPercent = $false }
        $filter.Filters.Add($crop)
        if ($isPercent -and $image) {
            $filter.Filters.Item($index).Properties.Item("Left") = $image.Width * $left
            $filter.Filters.Item($index).Properties.Item("Top") = $image.Height * $top
            $filter.Filters.Item($index).Properties.Item("Right") = $image.Width * $right
            $filter.Filters.Item($index).Properties.Item("Bottom") = $image.Height * $bottom
        } else {
            $filter.Filters.Item($index).Properties.Item("Left") = $left
            $filter.Filters.Item($index).Properties.Item("Top") = $top
            $filter.Filters.Item($index).Properties.Item("Right") = $right
            $filter.Filters.Item($index).Properties.Item("Bottom") = $bottom                    
        }
        if ($passthru) { return $filter }         
    }
}

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUlGGvzkNmffiM1xSY4AKBEzwB
# sEigggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFEtLYmWuG1LzbF5E
# OPqFyEFi34ZvMA0GCSqGSIb3DQEBAQUABIIBAHdR6QLFZRUimXYPhlBvXeZ2v53T
# W0j1PIRu8+yu/21trMS1x+3ePBrjQR74qKUH8xOEsijBlezm66LPbDM8wJfCuOqx
# iipZLt6vkrqr0CBDSReBG5mkXHLncbXskud4lw7LJzpEfGg7JMLq8wg3kzjpJWcu
# hIcJp/c/lgHfsnvoY+P0UfAqGNm8vCAHyMj6JdCSurlSgQOBsGPV/93SryxUtxZx
# VFa1RpWBB80btiitJM8eIyXQO7w+Ucf8v5mTAOvxuflZ+KQmASj8IgO4n+fTxXzP
# JIGAqEw2SeokYde7liijrP3RjB9sxXsAMROQeFFaC8rivR6UNi1fmB/kfjY=
# SIG # End signature block
