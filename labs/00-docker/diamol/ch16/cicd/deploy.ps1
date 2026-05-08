try {
    . ./set-vars.ps1
    pushd ../src

    $releaseSpec = docker compose $releaseComposeFiles config --format json | ConvertFrom-Json

    popd
    pushd ../helm/iotd

    helm install iotd `
        --set api.image=$releaseSpec.services.'image-of-the-day'.image `
        --set log.image=$releaseSpec.services.'access-log'.image `
        --set web.image=$releaseSpec.services.'image-gallery'.image `
        .
}
finally {
    popd
}