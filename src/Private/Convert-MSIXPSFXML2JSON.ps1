#From https://stackoverflow.com/questions/37024568/applying-xsl-to-xml-with-powershell-exception-calling-transform
function Convert-MSIXPSFXML2JSON {
    [CmdletBinding()]
    param ([Parameter(Mandatory = $true)] [String] $xml, 
        [Parameter(Mandatory = $true)] [String] $xsl, 
        [Parameter(Mandatory = $true)] [String] $output
    )

    Write-Verbose "Converting $xml to $output using $xsl"
    if (-not $xml -or -not $xsl -or -not $output) {
        Write-Host "& .\xslt.ps1 [-xml] xml-input [-xsl] xsl-input [-output] transform-output"
        return $false
    }

    Try {
        $xslt_settings = New-Object System.Xml.Xsl.XsltSettings;
        $XmlUrlResolver = New-Object System.Xml.XmlUrlResolver;
        $xslt_settings.EnableScript = 1;
        $xslt = New-Object System.Xml.Xsl.XslCompiledTransform;
        $xslt.Load($xsl, $xslt_settings, $XmlUrlResolver);

        # config.json.xml stores plain values; Format.xsl escapes them for JSON (text output).
        $jsonWriter = New-Object System.IO.StringWriter
        try {
            $xslt.Transform([string] $xml, [System.Xml.Xsl.XsltArgumentList] $null, [System.IO.TextWriter] $jsonWriter)
            $rawJson = $jsonWriter.ToString()
        }
        finally {
            $jsonWriter.Dispose()
        }

        # The round trip validates the JSON (ConvertFrom-Json throws on invalid output) and formats it.
        # ConvertTo-Json (PS 5.1) uses 4-space indentation with no -IndentSize option.
        # Reduce to 2-space indentation and collapse empty arrays/objects to one line.
        $formatted = $rawJson | ConvertFrom-Json | ConvertTo-Json -Depth 20

        # 4 spaces -> 2 spaces per indent level
        $lines = $formatted -split "`r?`n"
        $lines = $lines | ForEach-Object {
            if ($_ -match '^( +)') {
                (' ' * ([int]($Matches[1].Length / 4) * 2)) + $_.TrimStart()
            } else {
                $_
            }
        }

        # Collapse "[\n  \n]" and "{\n  \n}" patterns to "[]" / "{}"
        $formatted = $lines -join "`n"
        $formatted = [System.Text.RegularExpressions.Regex]::Replace($formatted, '\[\s*\]', '[]')
        $formatted = [System.Text.RegularExpressions.Regex]::Replace($formatted, '\{\s*\}', '{}')

        [System.IO.File]::WriteAllText($output, $formatted, [System.Text.Encoding]::UTF8)
    }

    Catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Error "Error: $ErrorMessage : $FailedItem : $($_.Exception) ";
        return $false
    }
}

