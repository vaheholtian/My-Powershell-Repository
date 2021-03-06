function Copy-Colored
{
    <#
    .Synopsis
        Copies the currently selected text in the current file with colorization
    .Description
        Copies the currently selected text in the current file with colorization.
        This allows for a user to paste colorized scripts into Word or Outlook
    .Example
        Copy-Colored  
    #>
    param()
    
    function Colorize
    {
        # colorize a script file or function

        param([string]$Text, [int]$Start = -1, [int]$End = -1, [int]$FontSize = 12)
        trap { break }
        $rtb = New-Object Windows.Forms.RichTextBox    
        $rtb.Font = New-Object Drawing.Font "Consolas", $FontSize 
        $rtb.Text = $Text

        # Now parse the text and report any errors...
        $parse_errs = $null
        $tokens = [system.management.automation.psparser]::Tokenize($rtb.Text,
            [ref] $parse_errs)

        if ($parse_errs) {
            $parse_errs
            return
        }
        $ColorPalette = New-ScriptPalette 

        # iterate over the tokens an set the colors appropriately...
        foreach ($t in $tokens) {
            $rtb.Select($t.start, $t.length)
            $color = $ColorPalette[$t.Type.ToString()]            
            if ($color) {
                $rtb.selectioncolor = [drawing.color]::FromArgb($color.A, 
                    $color.R, 
                    $color.G, 
                    $color.B)
            }
        }
        if ($start -eq -1 -and $end -eq -1) {
            $rtb.select(0,$rtb.Text.Length)
        } else {
            $rtb.select($start, $end)
        }
        $rtb.Copy()
    }
    
    $text = Get-CurrentOpenedFileText    
    $selectedText = Select-CurrentText -NotInOutput -NotInCommandPane
           
    if (-not $selectedText) {
        $TextToColor = ($Text -replace '\r\n', "`n")
    } else {        
        $TextToColor = ($selectedText -replace '\r\n', "`n")
    }
    Colorize $TextToColor  
}

function Write-ColorizedHTML {
    <#
    .Synopsis
        Writes Windows PowerShell as colorized HTML
    .Description
        Outputs a Windows PowerShell script as colorized HTML.
        The script is wrapped in <PRE> tags with <SPAN> tags defining color regions.
    .Example
        Write-ColoredHTML {Get-Process}
    #>
    param(
        # The Text to colorize
        [Parameter(Mandatory=$true)]
        [String]$Text,
        # The starting within the string to colorize
        [Int]$Start = -1,
        # the end within the string to colorize
        [Int]$End = -1)
    
    trap { break } 
    #
    # Now parse the text and report any errors...
    #
    $parse_errs = $null
    $tokens = [Management.Automation.PsParser]::Tokenize($text,
        [ref] $parse_errs)
 
    if ($parse_errs) {
        $parse_errs
        return
    }
    $stringBuilder = New-Object Text.StringBuilder
    $null = $stringBuilder.Append("<pre class='PowerShellColorizedScript'>")
    # iterate over the tokens an set the colors appropriately...
    $lastToken = $null
    foreach ($t in $tokens)
    {
        if ($lastToken) {
            $spaces = " " * ($t.Start - ($lastToken.Start + $lastToken.Length))
            $null = $stringBuilder.Append($spaces)
        }
        if ($t.Type -eq "NewLine") {
            $null = $stringBuilder.Append("            
")
        } else {
            $chunk = $text.SubString($t.start, $t.length)
            $color = $psise.Options.TokenColors[$t.Type]            
            $redChunk = "{0:x2}" -f $color.R
            $greenChunk = "{0:x2}" -f $color.G
            $blueChunk = "{0:x2}" -f $color.B
            $colorChunk = "#$redChunk$greenChunk$blueChunk"
            $null = $stringBuilder.Append("<span style='color:$colorChunk'>$chunk</span>")                    
        }                       
        $lastToken = $t
    }
    $null = $stringBuilder.Append("</pre>")
    $stringBuilder.ToString()
}    

function Copy-ColoredHTML 
{
    <#
    .Synopsis
        Copies the currently selected text in the current file as colorized HTML
    .Description
        Copies the currently selected text in the current file as colorized HTML
        This allows for a user to paste colorized scripts into web pages or blogging 
        software
    .Example
        Copy-ColoredHTML
    #>
    param()
    
	$currentText = Select-CurrentText -NotInCommandPane -NotInOutput
	if (-not $currentText) {
		# Try the current file
		$currentFile = Get-CurrentOpenedFileText		
		$text = $currentFile
	} else {
		$text = $currentText
	}
	if (-not $text) {  return }
	
	$sb = [ScriptBlock]::Create($text)
	$Error | Select-object -last 1 | ogv
	
	$colorizedHTML = Write-ColorizedHTML -Text "$sb"
	[Windows.Clipboard]::SetText($colorizedHTML )
	return        
}


function New-ScriptPalette
{
    param(
    $Attribute = "#FFADD8E6",
    $Command = "#FF0000FF",
    $CommandArgument = "#FF8A2BE2",   
    $CommandParameter = "#FF000080",
    $Comment = "#FF006400",
    $GroupEnd = "#FF000000",
    $GroupStart = "#FF000000",
    $Keyword = "#FF00008B",
    $LineContinuation = "#FF000000",
    $LoopLabel = "#FF00008B",
    $Member = "#FF000000",
    $NewLine = "#FF000000",
    $Number = "#FF800080",
    $Operator = "#FFA9A9A9",
    $Position = "#FF000000",
    $StatementSeparator = "#FF000000",
    $String = "#FF8B0000",
    $Type = "#FF008080",
    $Unknown = "#FF000000",
    $Variable = "#FFFF4500"        
    )
    
    process {
        $NewScriptPalette= @{}
        foreach ($parameterName in $myInvocation.MyCommand.Parameters.Keys) {
            $var = Get-Variable -Name $parameterName -ErrorAction SilentlyContinue
            if ($var -ne $null -and $var.Value) {
                if ($var.Value -is [Collections.Generic.KeyValuePair[System.Management.Automation.PSTokenType,System.Windows.Media.Color]]) {
                    $NewScriptPalette[$parameterName] = $var.Value.Value
                } elseif ($var.Value -as [Windows.Media.Color]) {
                    $NewScriptPalette[$parameterName] = $var.Value -as [Windows.Media.Color]
                }
            }
        }
        $NewScriptPalette    
    }
}
                                                 

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUtRK/MUq4u4zy/VgvQ0WM5S90
# VFegggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFMvgi/llcp4zPQ/K
# PnKLfQdXp3OYMA0GCSqGSIb3DQEBAQUABIIBADrCNPq3yy16/X6KE2+gqyvLydon
# R/F4m1KI0eLjad8utUCIx/kgWlCHJFSJRf3X1E1wqB1ErBVDRzl6uQrhd8sF4Jex
# wUAyKWajloFiwhKy8lDJHOBiDDoK3SS9CYli456H4WMzbxEjznu+GWYjkMi8ly8Q
# kIF/0jBsDWC/KXSkhDUvbiZwMdKwlYu5P8B10hzDiE1mdzOWbPu/49OZdO8vxh1q
# ZAZUvQCX7Ze0RG33zOw0/n2h/OEzMIoeVnqzqvurEtFQNHpAiAAW5qF8pQpdwoY7
# JcGCwm7BFH4/F2tJVtwDtMciqxS565PRuiLUeMvmhBVR7Tk3fPJP9TtDtV0=
# SIG # End signature block
