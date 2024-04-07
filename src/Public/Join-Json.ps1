$json1 = Get-Content -Path 'C:\Users\Andreas\OneDrive - Nick Informationstechnik GmbH\Andreas Nick MSIXBuch\MSIX Schulung\90 - Skriptsammlung\json configs\MFRFixup.txt' | ConvertFrom-Json
$json2 = Get-Content -Path 'C:\Users\Andreas\OneDrive - Nick Informationstechnik GmbH\Andreas Nick MSIXBuch\MSIX Schulung\90 - Skriptsammlung\json configs\RegLegacyFixup.txt' | ConvertFrom-Json


function Merge-Objects {
    param (
        [PSCustomObject]$OriginalObject,
        [PSCustomObject]$NewObject
    )

    foreach ($property in $NewObject.PSObject.Properties) {
        if ($OriginalObject.PSObject.Properties.Name -contains $property.Name) {
            if ($property.Name -eq 'processes') {
                # Spezielle Behandlung für das "processes"-Array
                for ($i = 0; $i -lt $property.Value.Count; $i++) {
                    $newProcess = $property.Value[$i]
                    $originalProcess = $OriginalObject.processes | Where-Object { $_.executable -eq $newProcess.executable }
                    if ($null -ne $originalProcess) {
                        # Überprüfe, ob es sich um das spezielle "executable" mit Fixups handelt
                        if ($newProcess.executable -match '\.\*') {
                            Merge-Fixups -OriginalFixups $originalProcess.fixups -NewFixups $newProcess.fixups
                        }
                    } else {
                        $OriginalObject.processes += $newProcess
                    }
                }
            } elseif ($property.Value -is [PSCustomObject] -and $OriginalObject.$($property.Name) -is [PSCustomObject]) {
                Merge-Objects -OriginalObject $OriginalObject.$($property.Name) -NewObject $property.Value
            } else {
                $OriginalObject.$($property.Name) = $property.Value
            }
        } else {
            $OriginalObject | Add-Member -Type NoteProperty -Name $property.Name -Value $property.Value
        }
    }

    return $OriginalObject
}

function Merge-Fixups {
    param (
        [Array]$OriginalFixups,
        [Array]$NewFixups
    )

    foreach ($newFixup in $NewFixups) {
        $existingFixup = $OriginalFixups | Where-Object { $_.dll -eq $newFixup.dll }
        if ($null -eq $existingFixup) {
            $OriginalFixups += $newFixup
        } else {
            # Hier können Sie entscheiden, wie mit doppelten DLLs umgegangen werden soll
            # Im aktuellen Beispiel überschreiben wir die existierende Konfiguration nicht
        }
    }
}

# Lese die Inhalte der beiden JSON-Dateien und wende die Funktion an
# Achten Sie darauf, die Pfade zu den JSON-Dateien anzupassen

$zusammengeführtesObjekt = Merge-Objects -OriginalObject $json1 -NewObject $json2

# Konvertiere und speichere das Ergebnis wie vorher beschrieben
$zusammengeführtesJson = $zusammengeführtesObjekt | ConvertTo-Json -Depth 100
$zusammengeführtesJson | Out-File -FilePath 'PfadZurZusammengeführtenDatei.json'
Write-Output $zusammengeführtesJson
