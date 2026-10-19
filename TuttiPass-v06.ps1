#requires -Version 7.0
# ===============================================================
# TuttiPass-v06.ps1 - Multiplataforma Windows/LMM
# Generador de contraseñas basado en Tutti Frutti
# Para alumnos ABC PC - Pomelo / Iglesia
#
# Cambios v06 (sobre v05):
#  - El alumno ELIGE 3 de las 20 categorías (ya no se sortean).
#  - Respuestas CORTAS (máx. 4 letras, sin espacios).
#  - Cada clave usa 2 de las 3 respuestas al azar, SIN recortar.
#  - Largo final de 15 caracteres justos (límite de WPS).
# ===============================================================

$ErrorActionPreference = 'Stop'

# -------------------- Configuración --------------------
$Categorias = @(
    'Mascota de tu infancia',
    'Juguete favorito de tu infancia',
    'Lugar donde jugabas de chico',
    'Golosina que te encantaba',
    'Canción que recuerdes de tu infancia',
    'Dibujito favorito',
    'Algo que tenías de chico',
    'Apodo familiar',
    'Juego favorito',
    'Nombre de tu escuela',
    'Flor que recuerdes',
    'Color que te gustaba',
    'Comida favorita de tu infancia',
    'Lugar de vacaciones que recuerdes',
    'Personaje favorito',
    'Animal que te guste',
    'Calle o barrio de tu infancia',
    'Nombre de un amigo de infancia',
    'Regalo que recuerdes especialmente',
    'Algo que te recuerde a tu casa de infancia'
)

$CaracteresExtra = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%&*+-=?'
$Separadores    = @('-', '_', '.', ':', '+', '#')

$LargoMaximo  = 15   # límite de contraseña de WPS
$MinAleatorio = 6    # mínimo de caracteres al azar al final
$MaxPalabra   = [int][math]::Floor(($LargoMaximo - 1 - $MinAleatorio) / 2)   # da 4

$Xlsx = Join-Path $PSScriptRoot 'Tutti.xlsx'

# -------------------- Detección de Entorno --------------------
$EsWindows = $PSVersionTable.Platform -eq 'Win32NT'
$EntornoActual = if ($EsWindows) { "Windows" } else { "Linux Mint MATE" }

# -------------------- Funciones criptográficas --------------------
function CryptoInt {
    param([int]$Max)
    $bytes = [byte[]]::new(4)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return [int]([BitConverter]::ToUInt32($bytes, 0) % [uint32]$Max)
}

function CryptoChar {
    param([string]$Chars)
    return $Chars[(CryptoInt $Chars.Length)]
}

function CryptoPart {
    param([int]$Length = 9)
    $s = ''
    1..$Length | ForEach-Object { $s += CryptoChar $CaracteresExtra }
    return $s
}

# -------------------- Verificar / crear Excel --------------------
function Ensure-Excel {
    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        Write-Host ""
        Write-Host "Falta el módulo ImportExcel. Intentando instalarlo automáticamente..." -ForegroundColor Yellow
        try {
            Install-Module ImportExcel -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            Write-Host "Módulo ImportExcel instalado correctamente." -ForegroundColor Green
        }
        catch {
            Write-Host "No se pudo instalar automáticamente." -ForegroundColor Red
            Write-Host "Ejecutá manualmente este comando:" -ForegroundColor Yellow
            Write-Host "  Install-Module ImportExcel -Scope CurrentUser" -ForegroundColor Cyan
            Write-Host ""
            exit 2
        }
    }
    Import-Module ImportExcel -ErrorAction Stop

    if (-not (Test-Path $Xlsx)) {
        Write-Host "Creando archivo Tutti.xlsx por primera vez en $EntornoActual..." -ForegroundColor Cyan
        $headers = [PSCustomObject]@{
            Lote              = ''
            'N°'              = ''
            Categorías        = ''
            Contraseña        = ''
            'Fecha generación'= ''
            Estado            = ''
            Notas             = ''
        }
        $headers | Export-Excel -Path $Xlsx -WorksheetName 'Generadas' -AutoSize -ClearSheet

        # Limpieza segura de la fila de encabezado vacía para EPPlus / ImportExcel
        try {
            $excel = Open-ExcelPackage -Path $Xlsx
            $ws = $excel.Workbook.Worksheets['Generadas']
            if ($ws.Dimension.End.Row -ge 2) {
                $ws.DeleteRow(2)
            }
            Close-ExcelPackage $excel
        } catch {
            # Si falla la remoción de la fila vacía por restricciones del motor, no frena la ejecución
        }
    }
}

# -------------------- Programa principal --------------------
Clear-Host
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "           TUTTIPASS v06 ($EntornoActual)"
Write-Host "     Generador de contraseñas Tutti Frutti"
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

Ensure-Excel

# Selección de 3 categorías (las elige el alumno)
Write-Host "Elegí 3 categorías de esta lista, las que quieras:" -ForegroundColor Yellow
Write-Host ""
for ($i = 0; $i -lt $Categorias.Count; $i++) {
    Write-Host ("  {0,2}. {1}" -f ($i + 1), $Categorias[$i])
}
Write-Host ""

do {
    $entrada = Read-Host "Escribí los 3 números separados por espacio (ej: 2 7 15)"
    $nums = @($entrada -split '[\s,;]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } | Select-Object -Unique)
    $ok = ($nums.Count -eq 3) -and (@($nums | Where-Object { $_ -lt 1 -or $_ -gt $Categorias.Count }).Count -eq 0)
    if (-not $ok) { Write-Host "Tienen que ser 3 números distintos entre 1 y $($Categorias.Count)." -ForegroundColor Red }
} until ($ok)

$Elegidas = $nums | ForEach-Object { $Categorias[$_ - 1] }

Write-Host ""
Write-Host "Categorías de esta ejecución:" -ForegroundColor Yellow
for ($i = 0; $i -lt 3; $i++) {
    Write-Host ("  {0}. {1}" -f ($i + 1), $Elegidas[$i])
}

# Pedir respuestas
Write-Host ""
Write-Host "IMPORTANTE: respuestas CORTAS, máximo $MaxPalabra letras y sin espacios." -ForegroundColor Yellow
Write-Host "Cuanto más corta la palabra, más largo y seguro queda el resto al azar." -ForegroundColor Yellow
Write-Host "Podés usar una abreviatura o un apodo (ej: 'Lola', 'Rex', 'Peli')." -ForegroundColor Yellow
Write-Host ""

$Respuestas = @()
for ($i = 0; $i -lt 3; $i++) {
    do {
        $r = (Read-Host "Respuesta para '$($Elegidas[$i])'") -replace '\s', ''
        if ($r.Length -gt $MaxPalabra) {
            Write-Host "  Muy larga ($($r.Length) letras). Máximo $MaxPalabra, probá con otra más corta." -ForegroundColor Red
        }
    } while ([string]::IsNullOrWhiteSpace($r) -or $r.Length -gt $MaxPalabra)
    $Respuestas += $r
}

Write-Host ""
Write-Host "Generando 20 alternativas de $LargoMaximo caracteres..." -ForegroundColor Cyan
Write-Host ""

# Generar las 20 contraseñas
$Generadas = @()
for ($n = 1; $n -le 20; $n++) {
    # 2 de las 3 respuestas, en orden al azar
    $orden = 0..2 | Sort-Object { CryptoInt 1000000 }
    $w = @($Respuestas[$orden[0]], $Respuestas[$orden[1]])

    # Mayúsculas aleatorias en las palabras
    for ($j = 0; $j -lt 2; $j++) {
        if ((CryptoInt 2) -eq 1) { $w[$j] = $w[$j].ToUpper() }
    }

    $sep   = $Separadores[(CryptoInt $Separadores.Count)]
    $base  = "$($w[0])$sep$($w[1])"
    $extra = CryptoPart ($LargoMaximo - $base.Length)

    $pw = "$base$extra"
    $Generadas += $pw
    Write-Host ("{0,2}. {1}" -f $n, $pw)
}

# Elegir una
Write-Host ""
Write-Host "Elegí el número de la contraseña que querés conservar como SELECCIONADA." -ForegroundColor Green
$eleccion = Read-Host "Número (1-20)"

if ($eleccion -notmatch '^\d+$' -or [int]$eleccion -lt 1 -or [int]$eleccion -gt 20) {
    Write-Host "Elección inválida. Se guardarán las 20 como Disponibles." -ForegroundColor Red
    $seleccionadaIndex = -1
} else {
    $seleccionadaIndex = [int]$eleccion - 1
}

# Preparar filas para el Excel
$Lote  = Get-Date -Format 'yyyyMMdd-HHmmss'
$Fecha = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$CategoriasTexto = $Elegidas -join ' | '

$rows = for ($i = 0; $i -lt 20; $i++) {
    $estado = if ($i -eq $seleccionadaIndex) { 'Seleccionada' } else { 'Disponible' }
    [PSCustomObject]@{
        Lote               = $Lote
        'N°'               = $i + 1
        Categorías         = $CategoriasTexto
        Contraseña         = $Generadas[$i]
        'Fecha generación' = $Fecha
        Estado             = $estado
        Notas              = ''
    }
}

# Guardar
$rows | Export-Excel -Path $Xlsx -WorksheetName 'Generadas' -Append -AutoSize

Write-Host ""
Write-Host "LISTO" -ForegroundColor Green
Write-Host "Se agregaron 20 contraseñas a: $Xlsx" -ForegroundColor Green

if ($seleccionadaIndex -ge 0) {
    Write-Host ""
    Write-Host "CONTRASEÑA SELECCIONADA:" -ForegroundColor Yellow
    Write-Host $Generadas[$seleccionadaIndex] -ForegroundColor White
    Write-Host ""
    Write-Host "Anotala en tu celular en un lugar seguro." -ForegroundColor Cyan
    Write-Host "Es la que marcaste como SELECCIONADA en el Excel." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Podés ejecutar el script de nuevo cuando necesites otra tanda de 20." -ForegroundColor Cyan
Write-Host "Las respuestas de las categorías NUNCA se guardan." -ForegroundColor Yellow
Write-Host ""
Read-Host "Presioná Enter para salir"
