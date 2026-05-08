param(
    [switch]$NoPush=$false
)

try {
    . ./set-vars.ps1
    pushd ../src

    echo "Building images with build number tag: $env:BUILD_NUMBER"
    docker compose $buildComposeFiles build --pull
    
    if (-not $NoPush) {
        echo "Pushing images with build number tag: $env:BUILD_NUMBER"
        # knows where to push based on the `docker-compose-build-tags.yml`
        docker compose $buildComposeFiles push
    }
}
finally {
    popd
}
