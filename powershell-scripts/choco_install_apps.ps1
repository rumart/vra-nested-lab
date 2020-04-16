$appsToInstall = <string here>
foreach ($item in $appsToInstall) {
    choco install $item -y
}