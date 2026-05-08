try {
    . ./set-vars.ps1
    $wd=$pwd
    pushd ../src

    foreach ($component in $components) {
        echo "*** Building: $component with unit tests"
        pushd $component
        docker build -t "$component-test" --target test .
        if ($LASTEXITCODE -ne 0) {
            echo "*** Build FAILED: $component"
            exit 1
        }
        popd
    }
}
finally {
    cd $wd
}