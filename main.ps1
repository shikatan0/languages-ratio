$jsonName = 'languages-ratio.json'
$languageByteMap = @{}
$sumByte = , 0
$headers = @{'Bearer' = '${{ secrets.GITHUB_TOKEN }}' }

Write-Host $headers.Bearer

(Invoke-RestMethod -Uri https://api.github.com/users/shikatan0/repos -Headers $headers)
| & {
  process {
    $resultObject = Invoke-RestMethod -Uri $_.languages_url -Headers $headers
    $propertyNames = $resultObject.psobject.properties.name
    if ($null -eq $propertyNames) {
      return
    }
    $propertyNames | & {
      process {
        $sumByte[0] += $resultObject.$_
        if ($languageByteMap.ContainsKey($_)) {
          $languageByteMap.$_ += $resultObject.$_
        }
        else {
          $languageByteMap.$_ = $resultObject.$_
        }
      }
    }
  }
}
$languageRatioMap = @{}
$languageByteMap.keys | & {
  process {
    $languageRatioMap.$_ = $languageByteMap.$_ / $sumByte[0] * 100
  }
}
$currentJson = $languageRatioMap | ConvertTo-JSON
if (Test-Path $jsonName) {
  $beforeJson = Get-Content -Path $jsonName -Raw
  if ($currentJson -ne $beforeJson) {
    $currentJson | Out-File $jsonName
  }
}
else {
  $currentJson | Out-File $jsonName
}
