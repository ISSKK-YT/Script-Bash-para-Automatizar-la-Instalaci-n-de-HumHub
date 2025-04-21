#!/bin/bash

# Script de instalación automatizada de HumHub
# Versión: 1.0
# Autor: ISSKK
# Requisitos: Ubuntu/Debian o CentOS/RHEL

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para verificar si el script se está ejecutando como root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Este script debe ejecutarse como root${NC}" >&2
        exit 1
    fi
}

# Función para detectar el sistema operativo
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
        OS_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | cut -d. -f1)
    else
        echo -e "${RED}No se pudo detectar el sistema operativo${NC}"
        exit 1
    fi
}

# Función para instalar dependencias en Ubuntu/Debian
install_deps_debian() {
    echo -e "${YELLOW}Instalando dependencias en Debian/Ubuntu...${NC}"
    apt-get update
    apt-get install -y apache2 mariadb-server php php-mysql php-gd php-curl php-zip php-mbstring php-xml php-intl php-ldap php-apcu php-imagick libapache2-mod-php curl unzip
    systemctl enable apache2
    systemctl start apache2
    systemctl enable mariadb
    systemctl start mariadb
}

# Función para instalar dependencias en CentOS/RHEL
install_deps_centos() {
    echo -e "${YELLOW}Instalando dependencias en CentOS/RHEL...${NC}"
    yum install -y epel-release
    yum install -y httpd mariadb-server php php-mysqlnd php-gd php-curl php-zip php-mbstring php-xml php-intl php-ldap php-pecl-apcu php-pecl-imagick curl unzip
    systemctl enable httpd
    systemctl start httpd
    systemctl enable mariadb
    systemctl start mariadb
}

# Función para configurar MySQL/MariaDB
setup_database() {
    echo -e "${YELLOW}Configurando la base de datos...${NC}"
    # Comando seguro para configurar MySQL/MariaDB
    mysql_secure_installation <<EOF

y
${DB_ROOT_PASS}
${DB_ROOT_PASS}
y
y
y
y
EOF

    # Crear base de datos y usuario para HumHub
    mysql -u root -p"${DB_ROOT_PASS}" <<MYSQL_SCRIPT
CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
}

# Función para descargar e instalar HumHub
install_humhub() {
    echo -e "${YELLOW}Descargando e instalando HumHub...${NC}"
    HUMHUB_DIR="/var/www/humhub"
    
    # Descargar la última versión de HumHub
    curl -L -o /tmp/humhub.tar.gz https://download.humhub.com/download/archive/humhub-${HUMHUB_VERSION}.tar.gz
    
    # Extraer y mover a directorio de instalación
    mkdir -p ${HUMHUB_DIR}
    tar -xzf /tmp/humhub.tar.gz -C ${HUMHUB_DIR} --strip-components=1
    rm /tmp/humhub.tar.gz
    
    # Configurar permisos
    chown -R www-data:www-data ${HUMHUB_DIR}
    chmod -R 755 ${HUMHUB_DIR}
    chmod -R 775 ${HUMHUB_DIR}/protected/runtime
    chmod -R 775 ${HUMHUB_DIR}/uploads
    chmod -R 775 ${HUMHUB_DIR}/assets
}

# Función para configurar Apache
setup_apache() {
    echo -e "${YELLOW}Configurando Apache...${NC}"
    APACHE_CONF="/etc/apache2/sites-available/humhub.conf"
    
    if [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
        APACHE_CONF="/etc/httpd/conf.d/humhub.conf"
    fi
    
    cat > ${APACHE_CONF} <<EOF
<VirtualHost *:80>
    ServerName ${SERVER_NAME}
    ServerAdmin webmaster@localhost
    DocumentRoot ${HUMHUB_DIR}
    
    <Directory ${HUMHUB_DIR}>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        a2enmod rewrite
        a2dissite 000-default
        a2ensite humhub
        systemctl restart apache2
    else
        systemctl restart httpd
    fi
}

# Función para configurar cron jobs
setup_cron() {
    echo -e "${YELLOW}Configurando tareas cron...${NC}"
    CRON_JOB="* * * * * php ${HUMHUB_DIR}/protected/yii cron/hourly >/dev/null 2>&1"
    CRON_JOB+="\n0 18 * * * php ${HUMHUB_DIR}/protected/yii cron/daily >/dev/null 2>&1"
    
    (crontab -u www-data -l 2>/dev/null; echo -e "$CRON_JOB") | crontab -u www-data -
}

# Función para mostrar información de instalación
show_installation_info() {
    echo -e "${GREEN}¡Instalación de HumHub completada con éxito!${NC}"
    echo -e "\n${YELLOW}Información de acceso:${NC}"
    echo -e "URL: http://${SERVER_NAME}"
    echo -e "Directorio de instalación: ${HUMHUB_DIR}"
    echo -e "\n${YELLOW}Credenciales de la base de datos:${NC}"
    echo -e "Base de datos: ${DB_NAME}"
    echo -e "Usuario: ${DB_USER}"
    echo -e "Contraseña: ${DB_PASS}"
    echo -e "\n${YELLOW}Para completar la instalación, visita la URL en tu navegador y sigue los pasos del asistente de instalación.${NC}"
}

# Configuración principal
main() {
    clear
    echo -e "${GREEN}Script de instalación automatizada de HumHub${NC}"
    echo -e "============================================\n"
    
    # Verificar root
    check_root
    
    # Detectar SO
    detect_os
    
    # Solicitar información de configuración
    read -p "Ingrese el nombre del servidor (ejemplo.com): " SERVER_NAME
    read -p "Versión de HumHub a instalar (ej. 1.15.2): " HUMHUB_VERSION
    read -p "Nombre de la base de datos (humhub): " DB_NAME
    DB_NAME=${DB_NAME:-humhub}
    read -p "Usuario de la base de datos (humhub): " DB_USER
    DB_USER=${DB_USER:-humhub}
    read -s -p "Contraseña para el usuario de la base de datos: " DB_PASS
    echo
    read -s -p "Contraseña root de MySQL/MariaDB (dejar vacío para configurar): " DB_ROOT_PASS
    echo
    
    # Instalar dependencias según el SO
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        install_deps_debian
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
        install_deps_centos
    else
        echo -e "${RED}Sistema operativo no soportado${NC}"
        exit 1
    fi
    
    # Configurar base de datos
    setup_database
    
    # Instalar HumHub
    install_humhub
    
    # Configurar Apache
    setup_apache
    
    # Configurar cron
    setup_cron
    
    # Mostrar información de instalación
    show_installation_info
}

# Ejecutar script principal
main