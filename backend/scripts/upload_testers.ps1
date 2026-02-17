# Configuración de cloudflare R2 (Reemplaza con tus valores reales)
$AccountId = "TU_ACCOUNT_ID"
$AccessKeyId = "TU_ACCESS_KEY_ID"
$SecretAccessKey = "TU_SECRET_ACCESS_KEY"
$BucketName = "celestya-bucket" # Verifica el nombre de tu bucket
$Region = "auto"
$EndpointUrl = "https://$AccountId.r2.cloudflarestorage.com"

# Directorio de fotos
$SourceDir = "C:\Users\migue\Downloads\FOTOS TEST"
$Prefix = "uploads/testers"

# Configurar AWS CLI para esta sesión (si no tienes perfil configurado)
$env:AWS_ACCESS_KEY_ID = $AccessKeyId
$env:AWS_SECRET_ACCESS_KEY = $SecretAccessKey
$env:AWS_DEFAULT_REGION = $Region

Write-Host "Iniciando subida a R2..." -ForegroundColor Cyan

# Obtener archivos de imagen
$files = Get-ChildItem -Path $SourceDir -Include *.png, *.jpg, *.jpeg -Recurse

foreach ($file in $files) {
    $Key = "$Prefix/$($file.Name)"
    Write-Host "Subiendo $($file.Name) a $Key..."
    
    # Subir archivo usando AWS CLI
    aws s3 cp $file.FullName "s3://$BucketName/$Key" --endpoint-url $EndpointUrl

    if ($LASTEXITCODE -eq 0) {
        Write-Host "OK" -ForegroundColor Green
    } else {
        Write-Host "ERROR al subir $($file.Name)" -ForegroundColor Red
    }
}

Write-Host "Proceso completado." -ForegroundColor Cyan
