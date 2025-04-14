# Actualizar servidores mediante WSUS
Script basado en powershell, para actualizar servidores a través de WSUS. Todos los servidores están en el mismo bosque de Active Directory, pero en diferentes dominios hijos.
Tienes credenciales con permisos administrativos en los servidores de todos los dominios hijos.
La comunicación remota por PowerShell (WinRM) está habilitada en todos los servidores.
- Credenciales en texto plano
- Verificación de conectividad (ping), si el servidor esta en línea.
- Instalación de actualizaciones aprobadas por WSUS
- Reinicio si es necesario, espera hasta que el servidor vuelva. Este bloque espera hasta 10 minutos después del reinicio. Puedes ajustar ese valor.,
- Verificación de que ya no quedan actualizaciones pendientes. Si el servidor no vuelve o aún tiene pendientes, se registra como fallo.
- Muestra errores y eventos importantes en la consola y los guarda en archivo.
- Logs individuales por servidor
