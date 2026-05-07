# sets common variables used in other scripts

$components = (
    'access-log',
    'image-gallery',
    'image-of-the-day'
)

$composeFiles = @(
    '-f', 'docker-compose.yml'
)
$buildComposeFiles = $composeFiles + @(
    '-f', 'docker-compose-build.yml',
    '-f', 'docker-compose-build-tags.yml'
)
$stagingComposeFiles = $composeFiles + @(        
    '-f', 'docker-compose-staging-tags.yml'
)
$releaseComposeFiles = $composeFiles + @(        
    '-f', 'docker-compose-release-tags.yml'
)

$sleepSeconds = 10

$info = docker version -f json | ConvertFrom-Json
$env:DOCKER_BUILD_OS = $info.Server.Os.ToLower()
$env:DOCKER_BUILD_CPU = $info.Server.Arch.ToLower()
$env:OS_VERSION_TAG=''
if ($env:DOCKER_BUILD_OS -eq 'windows') {
    $env:OS_VERSION_TAG="-ltsc2022"
    $sleepSeconds = 20
}