try {
    . ./set-vars.ps1
    pushd ../src

    $multiPlatformComposeFiles = $composeFiles + @(
        '-f', 'docker-compose-multi-platform-tags.yml'
    )

    # produce the final image names from Compose
    $spec = docker compose $multiPlatformComposeFiles config --format json | ConvertFrom-Json

    $variants = @(
        "linux-amd64",
        "windows-ltsc2022-amd64"
    )

    foreach ($component in $components) {
        # retrieve the target image name from Compose config
        $target = ($spec.services.PSObject.properties | where { $_.Name -eq $component }).Value.image
        echo "Creating manifest list for: $target"
        
        # build a list of existing platform-specific image references
        # example: ghcr.io/<owner>/release/ch16-access-log:2e
        $variantList = @()
        foreach ($variant in $variants) {
            $ref = "$($target)-$variant"
            $variantList += $ref
        }

        # WARN:
        # note that the variant images are expected to already exist as:
        # ghcr.io/<owner>/release/ch16-access-log:2e-linux-amd64
        # ghcr.io/<owner>/release/ch16-access-log:2e-windows-ltsc2022-amd64

        docker manifest rm $target
        docker manifest create $target @variantList
        docker manifest push $target
    }
}
finally {
    popd
}
