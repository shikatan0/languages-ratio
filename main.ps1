param (
    $REPO_ACCESS_TOKEN,
    $GITHUB_ACTOR
)

sv fileName 'languages-ratio.json' -Option ReadOnly
sv headers @{'Authorization' = "token $REPO_ACCESS_TOKEN"} -Option ReadOnly
sv userReposUri 'https://api.github.com/user/repos?affiliation=owner&per_page=100' -Option ReadOnly

$allByte = , 0
$languagesUrlArray = @()
$languageByteMap = @{}
$languageRatioMap = [ordered]@{}

function Get-LanguagesUrls {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        $response
    )
    process {
        $response.Content
        | ConvertFrom-Json
        | % {
            $_.languages_url
        }
    }
}

function Set-Json {
    param (
        $json,
        $path
    )
    process {
        $json | Out-File $path
        git config --global user.name $GITHUB_ACTOR
        git config --global user.email "$GITHUB_ACTOR@users.noreply.github.com"
        git add $path
        git commit -m u
        git push origin main
    }
}

$firstResponse = iwr $userReposUri -Headers $headers

$languagesUrlArray += $firstResponse | Get-LanguagesUrls

if ($null -ne $firstResponse.Headers['Link']) {
    $firstResponse.Headers['Link']
    | % {
        if ($_ -match 'page=([1-9]\d*)>; rel="last",?$') {
            2..[int]$Matches.1
            | % {
                $languagesUrlArray += iwr "$userReposUri&page=$_" -Headers $headers | Get-LanguagesUrls
            }
        }
    }
}

$languagesUrlArray | % {
    $response = irm $_ -Headers $headers
    $propertyNames = $response.psobject.properties.name
    if ($null -ne $propertyNames) {
        $propertyNames | % {
            $allByte[0] += $response.$_
            if ($languageByteMap.ContainsKey($_)) {
                $languageByteMap.$_ += $response.$_
            }
            else {
                $languageByteMap.$_ = $response.$_
            }
        }
    }
}

$languageByteMap.GetEnumerator()
| Sort-Object -Property value -Descending
| % {
    $languageRatioMap[$_.Key] = $_.value / $allByte[0] * 100
}

$languageRatioJson = $languageRatioMap | ConvertTo-JSON

if (Test-Path $fileName) {
    if ($languageRatioJson -ne (Get-Content -Path $fileName -Raw)) {
        Set-Json $languageRatioJson $fileName
    }
}
else {
    Set-Json $languageRatioJson $fileName
}
