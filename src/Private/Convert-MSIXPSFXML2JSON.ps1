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
        $xslt.Transform($xml, $output);
    }

    Catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Error "Error: $ErrorMessage : $FailedItem : $($_.Exception) ";
        return $false
    }
}

