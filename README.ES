# Laravel + MariaDB con Docker Compose

    Esta implementación proporciona un entorno de desarrollo de Laravel 
    completo y portable utilizando Docker Compose, diseñado para ser 
    fácilmente integrado y compartido a través de Git/GitHub.

    El setup está configurado para que el proyecto Laravel se cree 
    automáticamente la primera vez que se inicie los contenedores
    previamente definiendo los parametros de configuracion en los
    archivos del build el nombre que le daras al contenedor y el proyecto, 
    por defecto si para ti el nombre da igual puedes dejarlo en default
    sin romper nada, el script complementario te ayuda a automatizar cosas como
    crear un proyecto nuevo y levantar hasta 2 servidores de desarrollo de 
    laravel en los puertos adicionales 8080 y 8008.

    Se ha mapeado el archivo 000-default.conf de Apache por si en alguna cirscuntancia
    se deseara usar el puerto 80 del contenedor, solo se debe editar la ruta del
    DocumentRoot y se podra ver el sitio.

# Autor

    Este entorno ha sido creado y mantenido por:
    >  Alejandro Fernandes (Vernizus Luna).

    Si tienes sugerencias, ideas o encuentras algún problema, estaré encantado de revisarlo.  
    Puedes contactar, abrir un Issue o enviar un Pull Request en el repositorio.

    - GitHub: https://github.com/vernizus
    - LinkedIn: https://www.linkedin.com/in/gabriel-fernandes-998b64320


# Requisitos

    Docker: (Incluye Docker Engine y Docker Compose).

# Configuración

    1. Asigna las variables de entorno para la definir el acceso a la 
    base de datos, lo podras encontrar dentro de la carpeta 
    build el archivo .env:

    2. Asignar el nombre por defecto del proyecto que quieras trabajar
    en el archivo entrypoint y en el script de ayuda go.sh.

    3. Directorio Secreto: Accede a la carpeta `secret/`.
    
    Edita el archivo `secret/.env` y establece las credenciales de la base 
    de datos para que laravel sepa como conectarse, se entiende son las
    mismas definida previamente en el archivo .env para docker compose
    añada esas variables de entorno.

    Nota: Este archivo `.env` es montado directamente en el contenedor de 
          Laravel para la conexión a la DB y NO debe ser incluido en Git.

## Primeros Pasos

    Sigue estos sencillos pasos para levantar la aplicación:

#    1. Clonar el Repositorio:

git clone https://github.com/vernizus/laravel-dev-environment.git

#    2. Accede a la carpeta build y para construir e Iniciar los Contenedores:

cd build
docker compose up -d --build

    (El script `entrypoint.sh` se ejecutará automáticamente para crear 
     el proyecto Laravel y la carpeta `vendor` si no existen y levantar el
     servidor de desarrollo de laravel en el puerto 8000.)

#    3. Ejecutar Setup Post-Creación (Migraciones):

    Una vez que los contenedores estén corriendo y el proyecto se haya creado,
    utiliza el script auxiliar `go.sh` para copiar el archivo .env y
    ejecutar las migraciones iniciales de la base de datos.

chmod +x go.sh
./go.sh -i

# Acceso a la Aplicación

    Una vez que el setup de las migraciones se ha completado, puedes 
    acceder a la aplicación en tu navegador web:

* URL: `http://localhost:8000`

# Estructura del Proyecto

    * `build/`: Directorio de construccion de los contenedores
    * `build/Dockerfile`: Define la imagen PHP/Composer.
    * `build/docker-compose.yml`: Define los servicios `laravel` y `DB` (MariaDB).
    * `build/000-default.conf`: Usado para Apache y definir el DocumentRoot 
    * `entrypoint.sh`: Inicializa el proyecto Laravel, dependencias y server web.
    * `build/.env`: Variables de entorno para docker composer
    * `go.sh`: Script auxiliar para tareas.
    * `secret/.env`: Archivo de configuración para las credenciales de la DB.
    * `volumes`: Directorio donde se almaceran de manera persistentes los volumenes de la base de datos y los proyectos de laravel

# Script go.sh

    El script go.sh es la herramienta principal para interactuar con tu entorno 
    Docker/Laravel, la mayoría de los comandos que afectan a la aplicación requieren
    que especifiques el proyecto de destino si estas trabajando o creado varios proyectos
    a la vez:

   # General:
   ./go.sh -p <nombre_proyecto> [comando]

   # Para usar el puerto 8080 y levantar un servidor de desarrollo:
   ./go.sh -p <nombre_proyecto> --port8080 -r

   # Funciones Principales

   Mostrar Ayuda:
   > -h Muestra el mensaje de ayuda con la lista de comandos y opciones.

   Creación de Proyectos: 
   > --new <nombre> para generar una nueva aplicación Laravel.

   Seleccionar Proyecto: 
   > -p <nombre> para especificar en qué proyecto ejecutar los comandos.

   Inicializar: 
   > -i ejecuta la configuración inicial (migrate:fresh --seed), se puede usar si se 
        modifica el archivo secreto/.env y ejecutar el fresh automaticamente. 

   Mantenimiento:
   > -c limpia toda la caché de Laravel.
   > -m Ejecuta migraciones y seeders estándar

   Acceso Directo:
   > -s te da acceso directo a la shell (bash) del contenedor.

   Iniciar Servidor: 
   > -r levanta el servidor de desarrollo en segundo plano para el proyecto actual.

   Puertos Disponibles: 
   > Si no se especifica un puerto, se usa el 8000 (por defecto) no recomendado 
     se recomienda usar --port8080 o --port8008 para trabajar con otras apps 
     o en tal caso de cambiar el puerto por defecto del proyecto principal.

   Detener Servidor: 
   > -k detiene el servidor de desarrollo en segundo plano, usando el mismo puerto 
        con el que fue iniciado, si se uso uno en concreto especificar no aplica puerto 80.
  
   Instalar Dependencias

   > --composer Ejecuta composer install dentro del contenedor para instalar 
                dependencias de PHP para el proyecto actual.
# Contribución

    Recuerda mantener actualizado el archivo `.gitignore` para 
    añadir o quitar directorios/archivos que no deban ser versionados.
