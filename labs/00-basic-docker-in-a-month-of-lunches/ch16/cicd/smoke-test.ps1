param(
    [switch]$Local=$false
)

$exitCode = 0

try {
    . ./set-vars.ps1
    pushd ../src

    if ($Local) {
        $compose = $buildComposeFiles
    }
    else {
        $compose = $stagingComposeFiles
    }

    docker compose $compose up -d
    sleep $sleepSeconds

    # checks 01: container running
    $project = docker compose ls --format json | ConvertFrom-Json
    if ($project.Status -eq 'running(3)') {
        echo 'Compose project running!'
    }
    else {
        echo 'FAILED'
        echo $response
        $exitCode = 1
    }
    
    # checks 02: API
    $response = Invoke-WebRequest http://localhost:8011/image
    if ($response.StatusCode -eq '200') {
        echo 'API OK!'
    }
    else {
        echo 'FAILED API'
        echo $response
        $exitCode = 2
    }

    # check 03: Web app
    $response = Invoke-WebRequest http://localhost:8010
    if ($response.StatusCode -eq '200' -and $response.Images.Count -eq 1) {
        echo 'Web tests OK!'
    }
    else {
        echo 'FAILED web'
        echo $response
        $exitCode = 2
    }
}
catch {
    echo "ERROR: $($_.Exception.Message)"
    docker compose $compose logs
    $exitCode = 3
}
finally {
    docker compose $compose down
    popd
}

exit $exitCode
