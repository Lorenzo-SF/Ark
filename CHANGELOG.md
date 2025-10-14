# Changelog

Todos los cambios notables a este proyecto se documentarán en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-11

### 🎉 Versión Inicial

Primera versión estable de Ark como microframework global de herramientas de desarrollo para Elixir.

### 🏗️ Arquitectura Base

- **Nivel 3 en Proyecto Ypsilon**
- **Dependencias**: Aurora (1A) + Argos (1B) + Aegis (2)
- **Sin dependencias circulares**

### 🛠️ Herramientas Disponibles

#### Sistema

- `Ark.system_info/1` - Información completa del sistema (MOTD)
- Integración con Aurora para formateo
- Información meteorológica integrada

#### Git

- `Ark.setup_git/0` - Configuración de Git
- `Ark.git_user_info/0` - Información del usuario Git
- `Ark.clone_repos/2` - Clonado de repositorios
- `Ark.sync_repos/1` - Sincronización de repositorios

#### Docker

- `Ark.docker_start/0` - Inicio de contenedores
- `Ark.docker_stop/0` - Detención de contenedores
- `Ark.docker_status/0` - Estado de Docker

#### SSH

- `Ark.setup_ssh/0` - Creación de llaves SSH
- `Ark.list_ssh_keys/0` - Listado de llaves disponibles

#### Paquetes

- `Ark.install_packages/2` - Instalación automatizada de paquetes

#### Mensajería

- `Ark.success/1` - Mensajes de éxito (delega a Aegis)
- `Ark.error/1` - Mensajes de error (delega a Aegis)
- `Ark.warning/1` - Mensajes de advertencia (delega a Aegis)
- `Ark.info/1` - Mensajes informativos (delega a Aegis)

#### Ejecución

- `Ark.exec_command/1` - Ejecución de comandos (delega a Argos)
- `Ark.run_parallel/2` - Ejecución paralela de tareas (delega a Argos)

#### HTTP

- `Ark.http_call/1` - Llamadas HTTP básicas
- `Ark.http_call_with_auth/1` - Llamadas HTTP con autenticación

#### Clima

- `Ark.weather_today/1` - Información meteorológica del día

### 📦 Módulos Especializados

- `Ark.Motd` - Sistema MOTD
- `Ark.Git` - Operaciones Git avanzadas
- `Ark.Docker ` - Gestión de contenedores
- `Ark.Ssh` - Gestión de llaves SSH
- `Ark.Packages` - Instalación de paquetes
- `Ark.HTTP` - Cliente HTTP
- `Ark.Weather` - Información climática
- `Ark.Pathy` - Utilidades de rutas

### 🧪 Pruebas

- Suite completa de pruebas unitarias
- Cobertura de código > 75%
- Tests de integración para todas las herramientas principales

### 📚 Documentación

- README.md completo
- Documentación en línea para todas las funciones públicas
- Ejemplos prácticos para cada herramienta
- Integración con `mix docs`

## [0.1.0] - 2025-10-10

### 🚀 Versión Alpha Inicial

Primera versión alpha de Ark como parte del refactor de Proyecto Ypsilon.

### 🏗️ Estructura Inicial

- Migración de funcionalidad desde Gearbox
- Reorganización en módulos especializados
- Integración con nueva arquitectura de dependencias

### 🛠️ Funcionalidad Básica

- Herramientas del sistema básicas
- Integración con Argos para ejecución de comandos
- Integración con Aegis para interfaz de usuario
- Integración con Aurora para formateo de salida

## Versión 1.0.3 (2025-09-26)

### 🔧 Refactoring

- Refactor y fix de Tools. Actualizacion de documentación

## Versión 1.0.2 (2025-09-25)

### 🔧 Refactoring

- Refactor nombres de funciones de "HTTP"

## Versión 1.0.1 (2025-09-24)

### 

- Refactor de "Motd" porque en algunas ocasiones da problemas de compilacion

## Versión 1.0.0 (2025-09-24)

### 

- Publicacion libreria

[Unreleased]: https://github.com/usuario/ark/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/usuario/ark/releases/tag/v1.0.0