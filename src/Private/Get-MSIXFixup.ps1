
# return a fixup xml fragment

function Get-MSIXFixup {
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)]
        [xml] $XmlDoc
    )

    #<fixup>
    #<dll>TraceFixup64.dll</dll>
    #<config>
    #<traceMethod>eventLog</traceMethod>
    #<traceLevels>
    #<default>always</default>
    #</traceLevels>
    #</config>
    #</fixup>

    $fragment = $xmlDoc.CreateDocumentFragment()
    # Noch ein fehler. Das muss so ausschauen
    #<traceLevel level="default">always</traceLevel>
    #$fragment.InnerXml = '<fixup><dll>TraceFixup64.dll</dll><config><traceMethod>eventLog</traceMethod><traceLevels><traceLevel level="default">allFailures</traceLevel></traceLevels></config></fixup>'
    $fragment.InnerXml = '<fixup><dll>TraceFixup64.dll</dll><config><traceMethod>outputDebugString</traceMethod><traceLevels><traceLevel level="default">allFailures</traceLevel><traceLevel level="filesystem">always</traceLevel></traceLevels></config></fixup>'
    #$fragment.InnerXml = '<fixup><dll>TraceFixup64.dll</dll><config><traceMethod>eventLog</traceMethod><traceLevels></traceLevels></config></fixup>'
    #$xmlDoc.AppendChild($fragment)
    return $fragment
   
}

