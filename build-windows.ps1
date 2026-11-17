# Compila o Radar de Outliers no Windows sem Gradle: aapt2 + javac + d8 + apksigner.
# Uso (PowerShell):  $env:KS_PASS = "senha"; .\build-windows.ps1
# A chave fica FORA do repositorio (padrao: Documentos\chaves\radar.keystore).
$ErrorActionPreference = "Stop"
$VersionCode = 17
$VersionName = "2.6"

if (-not $env:KS_PASS) { throw "Informe a senha da chave em `$env:KS_PASS" }
$Repo = $PSScriptRoot
$KS   = if ($env:KS_FILE) { $env:KS_FILE } else { "$env:USERPROFILE\Documents\chaves\radar.keystore" }
$JDK  = if ($env:JDK) { $env:JDK } else { "C:\dev\jdk17" }
$SDK  = if ($env:SDK) { $env:SDK } else { "C:\dev\android-sdk" }
$BT   = "$SDK\build-tools\35.0.1"
$JAR  = "$SDK\platforms\android-35\android.jar"
$env:JAVA_HOME = $JDK; $env:Path = "$JDK\bin;$env:Path"
if (-not (Test-Path $KS)) { throw "Chave nao encontrada: $KS" }

# compila numa pasta so com letras simples (as ferramentas do Android nao gostam de acento no caminho)
$OUT = "C:\dev\radar-build"
if (Test-Path $OUT) { Remove-Item $OUT -Recurse -Force }
New-Item -ItemType Directory -Force "$OUT\gen","$OUT\classes","$OUT\assets","$OUT\src" | Out-Null
Copy-Item "$Repo\assets\*" "$OUT\assets" -Recurse
Copy-Item "$Repo\res" "$OUT\res" -Recurse
Copy-Item "$Repo\src\*" "$OUT\src" -Recurse
Copy-Item "$Repo\AndroidManifest.xml" "$OUT\"

$sha1 = ((& "$JDK\bin\keytool.exe" -list -v -keystore $KS -storepass $env:KS_PASS -alias radar 2>$null | Select-String "SHA1:") -split "SHA1:\s*")[1].Trim()
$html = [IO.File]::ReadAllText("$OUT\assets\index.html").Replace("__SHA1__", $sha1)
[IO.File]::WriteAllText("$OUT\assets\index.html", $html, (New-Object Text.UTF8Encoding $false))

function Run($exe, [string[]]$a) { & $exe @a; if ($LASTEXITCODE) { throw "falhou: $exe" } }
Run "$BT\aapt2.exe" @("compile", "--dir", "$OUT\res", "-o", "$OUT\res.zip")
Run "$BT\aapt2.exe" @("link", "-I", $JAR, "--manifest", "$OUT\AndroidManifest.xml", "-A", "$OUT\assets",
  "--min-sdk-version", "26", "--target-sdk-version", "35", "--version-code", "$VersionCode", "--version-name", $VersionName,
  "--java", "$OUT\gen", "-o", "$OUT\base.apk", "$OUT\res.zip")
$java = Get-ChildItem "$OUT\src","$OUT\gen" -Recurse -Filter *.java | ForEach-Object FullName
Run "$JDK\bin\javac.exe" (@("-nowarn", "--release", "11", "-encoding", "UTF-8", "-classpath", $JAR, "-d", "$OUT\classes") + $java)
$classes = Get-ChildItem "$OUT\classes" -Recurse -Filter *.class | ForEach-Object FullName
Run "$BT\d8.bat" (@("--release", "--min-api", "26", "--lib", $JAR, "--output", $OUT) + $classes)

# coloca o classes.dex dentro do apk
Copy-Item "$OUT\base.apk" "$OUT\unsigned.apk"
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$z = [IO.Compression.ZipFile]::Open("$OUT\unsigned.apk", "Update")
[void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($z, "$OUT\classes.dex", "classes.dex")
$z.Dispose()

Run "$BT\zipalign.exe" @("-f", "-p", "4", "$OUT\unsigned.apk", "$OUT\aligned.apk")
Run "$BT\apksigner.bat" @("sign", "--ks", $KS, "--ks-pass", "env:KS_PASS", "--key-pass", "env:KS_PASS",
  "--ks-key-alias", "radar", "--out", "$OUT\RadarDeOutliers.apk", "$OUT\aligned.apk")
Run "$BT\apksigner.bat" @("verify", "--print-certs", "$OUT\RadarDeOutliers.apk")
Copy-Item "$OUT\RadarDeOutliers.apk" "$Repo\RadarDeOutliers.apk" -Force
Write-Host "SHA-1: $sha1"
Get-Item "$Repo\RadarDeOutliers.apk" | Select-Object FullName, Length
