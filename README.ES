# Laravel + MariaDB con Docker Compose

Esta implementación proporciona un entorno de desarrollo de Laravel completo y portable utilizando Docker Compose, diseñado para ser fácilmente integrado y compartido a través de Git/GitHub.

El setup está completamente automatizado: desde la creación del proyecto Laravel hasta la configuración de la base de datos, migraciones y servidor de desarrollo. El sistema es multi-proyecto, permitiendo trabajar con varias aplicaciones simultáneamente en diferentes puertos.

Se ha mapeado el archivo 000-default.conf de Apache por si en alguna circunstancia se deseara usar el puerto 80 del contenedor, solo se debe editar la ruta del DocumentRoot y se podrá ver el sitio.

# Autor

Este entorno ha sido creado y mantenido por:
> Alejandro Fernandes (Vernizus Luna).

Si tienes sugerencias, ideas o encuentras algún problema, estaré encantado de revisarlo. Puedes contactar, abrir un Issue o enviar un Pull Request en el repositorio.

- GitHub: https://github.com/vernizus
- LinkedIn: https://www.linkedin.com/in/gabriel-fernandes-998b64320

# Requisitos

- Docker: (Incluye Docker Engine y Docker Compose)

# Configuración Inicial Automatizada

## Primeros Pasos después del Clone

# 1. Clonar el Repositorio:
git clone https://github.com/vernizus/laravel-dev-environment.git
cd laravel-dev-environment

# 2. Dar permisos de ejecución al script principal:
chmod +x go.sh

# 3. EJECUCIÓN OBLIGATORIA: Configuración inicial completa
. go.sh -i


# Nota importante: El comando . go.sh -i 
# (con el punto al principio) es obligatorio ya que:

    1. **Configura nombres**: Te pregunta el nombre del proyecto y contenedor
    2. **Prepara CLI**: 
       - Añade el script `go.sh` a tu PATH de la sesión actual
       - Crea el alias `go` para usar el script desde cualquier subdirectorio
    3. **Construye infraestructura**:
       - Construye e inicia todos los servicios Docker (Laravel + MariaDB)
       - Espera servicios: Verifica que todo esté listo y funcionando
    4. **Configura aplicación**:
       - Configura base de datos: Copia el .env y ejecuta migraciones
       - Ejecuta migraciones y seeders iniciales
    5. **Prepara todo el entorno para desarrollo**

# Acceso a la Aplicación

Una vez completado el setup inicial, puedes acceder a la aplicación:

    # URL Principal: http://localhost:8000

    # Puertos Alternativos: http://localhost:8080 o http://localhost:8008

# Estructura del Proyecto

* `build/`: Directorio de construcción de los contenedores
* `build/Dockerfile`: Define la imagen PHP/Composer
* `build/docker-compose.yml`: Define los servicios laravel y DB (MariaDB)
* `build/000-default.conf`: Configuración de Apache para DocumentRoot
* `build/entrypoint.sh`: Inicializa proyecto Laravel y dependencias
* `build/.env`: Variables de entorno para Docker Compose
* `go.sh`: Script principal para todas las operaciones
* `secret/.env`: Credenciales de base de datos (NO subir a Git)
* `volumes/`: Datos persistentes de DB y proyectos Laravel

# Script go.sh 

El script go.sh es tu herramienta principal para todo. Una vez ejecutado go --init, puedes usar simplemente go desde cualquier carpeta del proyecto.

# Sintaxis general
go [OPCIONES] [ARGUMENTOS]

# Siempre especifica el proyecto si esta trabajando con varios proyectos (a menos que uses 'default')
go -p <nombre_proyecto> [comando]

# Gestión de Proyectos y Contexto
go -p mi_proyecto              # Cambiar a proyecto 'mi_proyecto'
go --new mi_app                # Crear nueva aplicación Laravel
go --clone usuario/repo        # Clonar y configurar desde GitHub automáticamente

# Servidores de Desarrollo Multi-puerto
go -p mi_proyecto -r             # Servidor en puerto 8000
go -p mi_proyecto --port8080 -r  # Servidor en puerto 8080  
go -p mi_proyecto --port8008 -r  # Servidor en puerto 8008
go -p mi_proyecto -k             # Detener servidor del proyecto

# Desarrollo Rápido y Mantenimiento
go -p mi_proyecto -M User Post Category  # Crear Múltiples Modelos+Migraciones+Controllers
go -p mi_proyecto -m                     # Ejecutar migraciones y seeders
go -p mi_proyecto -c                     # Limpiar toda la caché de Laravel
go -p mi_proyecto --composer             # Instalar dependencias Composer

# Acceso y Utilidades
go -p mi_proyecto -s           # Shell interactivo en el contenedor
go -h                          # Ayuda completa con ejemplos

# Clonar proyecto existente desde GitHub:
go --clone usuario/repositorio  # Clona, configura permisos y dependencias asegurate de estar dentro de la carpeta donde se creo el proyecto cero del contenedor luego esto reescribira con tu proyecto esa carpeta y lo tendras preparado

# Trabajar con múltiples proyectos:
go -p api --port8080 -r      # API en puerto 8080
go -p frontend --port8008 -r # Frontend en puerto 8008  
go -p api -s                 # Shell en proyecto API

# Flujo de Trabajo Típico

1. `. go.sh -i`                    # Configuración inicial
2. `go --new mi_proyecto`          # Crear nuevo proyecto
3. `go -p mi_proyecto -r`          # Levantar servidor
4. `go -p mi_proyecto -M Product`  # Generar modelo
5. `go -p mi_proyecto -m`          # Ejecutar migraciones

# Error de Usuario Duplicado en Seeders
Si encuentras errores de `Duplicate entry 'test@example.com'` al ejecutar migraciones:

# Solución automática:
go --fix-seeder
go -m

# Características Avanzadas

> Validación Inteligente

El script verifica automáticamente:

   * Que los contenedores estén ejecutándose

   * Que el proyecto exista

   * Que sea una aplicación Laravel válida

   * Sugiere soluciones si algo falla

> Multi-proyecto Nativo

Trabaja con tantos proyectos Laravel como necesites, cada uno en su propio directorio dentro de volumes/laravel/.
Recuperación de Errores

Si encuentras problemas, el script te guía con soluciones específicas y muestra proyectos disponibles.

# Contribución
Recuerda mantener actualizado el archivo .gitignore para añadir o quitar directorios/archivos que no deban ser versionados. El archivo secret/.env NUNCA debe ser commitado a Git.

# ¡Importante!: Después del git clone, recuerda siempre ejecutar 
# . go.sh -i (El punto y espacio antes de go.sh -i son esenciales para 
# que el alias go esté disponible en tu sesión actual y configurar 
# todo el entorno automáticamente.
