# Credenciales en texto plano (¡usar solo en entornos seguros!)
$usuario = "admin@midominio.com"
$clavePlano = "TuContraseñaSegura"
$claveSegura = ConvertTo-SecureString $clavePlano -AsPlainText -Force
$credencial = New-Object System.Management.Automation.PSCredential ($usuario, $claveSegura)

# Lista de servidores a actualizar
$servidores = @(
    "srv1.hijo1.midominio.com",
    "srv2.hijo1.midominio.com",
    "srv1.hijo2.midominio.com",
    "srv2.hijo2.midominio.com"
)

# Carpeta de logs
$carpetaLogs = "C:\LogsActualizacion"
if (-not (Test-Path $carpetaLogs)) {
    New-Item -Path $carpetaLogs -ItemType Directory
}

foreach ($servidor in $servidores) {
    $logPath = Join-Path $carpetaLogs "$servidor.log"

    Write-Host "`n========================="
    Write-Host "Procesando $servidor..."
    Write-Host "========================="

    if (Test-Connection -ComputerName $servidor -Count 2 -Quiet) {
        try {
            Invoke-Command -ComputerName $servidor -Credential $credencial -ScriptBlock {
                $ErrorActionPreference = 'Stop'
                $fecha = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Write-Output "[$fecha] Iniciando actualizaciones WSUS en $env:COMPUTERNAME"

                wuauclt.exe /resetauthorization /detectnow
                usoclient StartScan
                Start-Sleep -Seconds 30

                $session = New-Object -ComObject Microsoft.Update.Session
                $searcher = $session.CreateUpdateSearcher()
                $searchResult = $searcher.Search("IsInstalled=0 and Type='Software'")

                if ($searchResult.Updates.Count -eq 0) {
                    Write-Output "[$fecha] No hay actualizaciones pendientes."
                }
                else {
                    $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
                    foreach ($update in $searchResult.Updates) {
                        if (-not $update.EulaAccepted) {
                            $update.AcceptEula()
                        }
                        $updatesToInstall.Add($update) | Out-Null
                    }

                    $installer = $session.CreateUpdateInstaller()
                    $installer.Updates = $updatesToInstall
                    $result = $installer.Install()

                    Write-Output "[$fecha] Resultado instalación: $($result.ResultCode)"
                    Write-Output "[$fecha] ¿Requiere reinicio?: $($result.RebootRequired)"

                    if ($result.RebootRequired) {
                        Write-Output "[$fecha] Reiniciando servidor..."
                        Restart-Computer -Force
                    }
                }
            } -ErrorAction Stop | Out-File -FilePath $logPath -Append

            # Esperar que el servidor vuelva del reinicio
            Write-Host "Esperando que $servidor vuelva del reinicio..."
            Start-Sleep -Seconds 30
            $timeout = 600
            $volvio = $false
            for ($i = 0; $i -lt $timeout; $i += 10) {
                if (Test-Connection -ComputerName $servidor -Count 2 -Quiet) {
                    $volvio = $true
                    break
                }
                Start-Sleep -Seconds 10
            }

            if (-not $volvio) {
                $msg = "[$(Get-Date)] El servidor $servidor no volvió en el tiempo esperado."
                Write-Warning $msg
                Add-Content -Path $logPath -Value $msg
                continue
            }

            # Verificar si aún quedan actualizaciones
            $pendientes = Invoke-Command -ComputerName $servidor -Credential $credencial -ScriptBlock {
                $fecha = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $session = New-Object -ComObject Microsoft.Update.Session
                $searcher = $session.CreateUpdateSearcher()
                $pending = $searcher.Search("IsInstalled=0 and Type='Software'")
                Write-Output "[$fecha] Verificación tras reinicio: $($pending.Updates.Count) actualizaciones pendientes."
                return $pending.Updates.Count
            } -ErrorAction Stop | Tee-Object -FilePath $logPath -Append

            if ($pendientes -eq 0) {
                Write-Host "$servidor actualizado correctamente."
            }
            else {
                Write-Warning "$servidor aún tiene $pendientes actualizaciones pendientes."
            }

        } catch {
            $errorMsg = "[$(Get-Date)] ERROR en $servidor: $_"
            Write-Warning $errorMsg
            Add-Content -Path $logPath -Value $errorMsg
        }
    }
    else {
        $offlineMsg = "[$(Get-Date)] El servidor $servidor no respondió al ping. Se omite."
        Write-Warning $offlineMsg
        Add-Content -Path $logPath -Value $offlineMsg
    }
}
