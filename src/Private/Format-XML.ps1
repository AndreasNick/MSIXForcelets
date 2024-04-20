#Formatet output over a filestream
# From: https://stackoverflow.com/questions/39267485/formatting-xml-from-powershell/39271782
function Format-XML {
    [CmdletBinding()]
    Param ([Parameter(ValueFromPipeline = $true, Mandatory = $true)][xml] $xmldoc)
    #$xmldoc = New-Object -TypeName System.Xml.XmlDocument
    #$xmldoc.LoadXml($xmlcontent)
    $sw = New-Object System.IO.StringWriter
    $writer = New-Object System.Xml.XmlTextwriter($sw)
    $writer.Formatting = [System.XML.Formatting]::Indented
    $xmldoc.WriteContentTo($writer)
    $sw.ToString()
}

