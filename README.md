# Ark

**Microframework global de herramientas de desarrollo para Elixir** - Nivel 3 de Proyecto Ypsilon

[![Version](https://img.shields.io/hexpm/v/ark.svg)](https://hex.pm/packages/ark) [![License](https://img.shields.io/hexpm/l/ark.svg)](https://github.com/usuario/ark/blob/main/LICENSE)

Ark es un microframework que proporciona una suite completa de herramientas para facilitar el desarrollo y la configuración del entorno de trabajo en Elixir.

## Arquitectura

Ark forma parte de **Proyecto Ypsilon**:

```
                    ┌─────────────────┐
                    │   NIVEL 3: ARK  │
                    │  Microframework │   ← ESTÁS AQUÍ
                    │     Global      │
                    └────────┬────────┘
                             │
                    ┌────────▼─────────┐
                    │  NIVEL 2: AEGIS  │
                    │  CLI/TUI         │
                    │  Framework       │
                    └────┬─────┬───────┘
                         │     │
           ┌─────────────┘     └─────────────┐
           │                                 │
    ┌──────▼────────┐              ┌─────────▼──────┐
    │ NIVEL 1A:     │              │ NIVEL 1B:      │
    │ AURORA        │              │ ARGOS          │
    │ Formatting &  │              │ Execution &    │
    │ Rendering     │              │ Orchestration  │
    └───────────────┘              └────────────────┘
         BASE                             BASE
      (sin deps)                      (sin deps)
```

## Características

- 🖥️ **Sistema**: MOTD, información del sistema
- 🔧 **Git**: Configuración, clonado, sincronización de repositorios
- 🐳 **Docker**: Gestión de contenedores
- 🔑 **SSH**: Generación y gestión de llaves
- 📦 **Paquetes**: Instalación automatizada
- ⚙️ **Terminal**: Configuración de shell y herramientas
- 🌤️ **Clima**: Información meteorológica
- 🔗 **API**: Cliente HTTP con autenticación
- 📁 **Paths**: Utilidades de archivos y rutas

## Instalación

Agrega a tu `mix.exs`:

```elixir
def deps do
  [
    {:ark, "~> 1.0.0"}
  ]
end
```

## Uso Rápido

### Información del sistema

```elixir
# Mostrar información del sistema (MOTD)
Ark.system_info()

# Información compacta sin clima
Ark.system_info(layout: :compact, weather: false)
```

### Configuración de Git

```elixir
# Configurar Git
Ark.setup_git()

# Obtener información del usuario Git
user_info = Ark.git_user_info()
# => %{name: "Juan Pérez", email: "juan@example.com", hostname: "mi-mac"}
```

### Gestión Docker

```elixir
# Iniciar contenedores
Ark.docker_start()

# Detener contenedores
Ark.docker_stop()

# Verificar estado
status = Ark.docker_status()
# => %{installed: true, running: true}
```

### SSH

```elixir
# Crear llaves SSH
Ark.setup_ssh()

# Listar llaves disponibles
keys = Ark.list_ssh_keys()
# => ["id_rsa", "id_ed25519", "github"]
```

### Instalación de paquetes

```elixir
# Instalar paquetes
Ark.install_packages(["git", "curl", "vim"])

# Instalar sin actualizar cache
Ark.install_packages(["docker"], false)
```

### Operaciones Git

```elixir
# Clonar repositorios
repos = [%{repo: %{url: "git@github.com:user/repo.git", path: "/workspace/repo"}}]
Ark.clone_repos(repos, "/workspace")

# Sincronizar repositorios
Ark.sync_repos(%{path: "/path/to/repo", main_branch: "main"})
```

## API Principal

### Sistema

- `Ark.system_info/1` - Muestra información completa del sistema (MOTD)
- `Ark.setup_git/0` - Configura Git con nombre de usuario y email
- `Ark.git_user_info/0` - Obtiene información del usuario Git actual

### Docker

- `Ark.docker_start/0` - Inicia todos los contenedores Docker configurados
- `Ark.docker_stop/0` - Detiene todos los contenedores Docker
- `Ark.docker_status/0` - Verifica el estado de Docker

### SSH

- `Ark.setup_ssh/0` - Crea llaves SSH si no existen
- `Ark.list_ssh_keys/0` - Lista las llaves SSH disponibles

### Paquetes

- `Ark.install_packages/2` - Instala una lista de paquetes usando el gestor del sistema

### Git

- `Ark.clone_repos/2` - Clona repositorios en un workspace
- `Ark.sync_repos/1` - Sincroniza repositorios Git (fetch + pull)

### Mensajes

- `Ark.success/1` - Muestra un mensaje de éxito usando Aegis
- `Ark.error/1` - Muestra un mensaje de error usando Aegis
- `Ark.warning/1` - Muestra un mensaje de advertencia usando Aegis
- `Ark.info/1` - Muestra un mensaje informativo usando Aegis

### Ejecución

- `Ark.exec_command/1` - Ejecuta un comando del sistema usando Argos
- `Ark.run_parallel/2` - Ejecuta múltiples tareas en paralelo usando Argos

### Clima

- `Ark.weather_today/1` - Obtiene información meteorológica del día actual

### HTTP

- `Ark.http_call/1` - Realiza una llamada HTTP con opciones básicas
- `Ark.http_call_with_auth/1` - Realiza una llamada HTTP con autenticación automática

## Módulos Especializados

Para funcionalidades avanzadas, usa directamente los módulos:

- `Ark.Motd` - MOTD y sistema
- `Ark.Git` - Operaciones Git
- `Ark.Docker ` - Gestión Docker
- `Ark.Ssh` - Llaves SSH
- `Ark.Packages` - Instalación paquetes
- `Ark.Weather` - Información clima
- `Ark.HTTP` - Cliente HTTP
- `Ark.Pathy` - Utilidades paths
- `Ark.Tools` - Herramientas varias

## Integración con otros niveles

Ark se integra perfectamente con los otros niveles de Proyecto Ypsilon:

- **Aurora (1A)**: Sistema de formateo y colores
- **Argos (1B)**: Sistema de ejecución y orquestación
- **Aegis (2)**: Framework CLI/TUI completo

## Uso como CLI

Ark también puede usarse como una herramienta de línea de comandos independiente:

```bash
# Mostrar información del sistema
ark system-info

# Configurar Git
ark git setup

# Información del usuario Git
ark git user-info

# Gestión de Docker
ark docker start
ark docker stop
ark docker status

# Gestión de SSH
ark ssh setup
ark ssh list-keys

# Instalar paquetes
ark packages install --packages "git,docker,curl"

# Ejecutar comandos del sistema
ark exec "ls -la"

# Mostrar mensajes
ark success "Operación completada"
ark error "Ha ocurrido un error"
ark warning "Advertencia importante"
ark info "Información"
```

## Licencia

Apache 2.0 - Consulta el archivo [LICENSE](LICENSE) para más detalles.
