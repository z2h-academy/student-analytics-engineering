# AE-2026 · Analytics Engineering (Snowflake + dbt)

Repo base del módulo **Analytics Engineering 2026**. Contiene la
infraestructura necesaria para ejecutar los labs del roadmap: imagen de
dbt, Docker Compose, Makefile, dependencias pinneadas y configuración de
lint/CI.

Este repo **no** incluye los labs resueltos ni la documentación
pedagógica: los proyectos de cada nivel se construyen siguiendo las
sections del roadmap, que son la única fuente de verdad.

---

## Qué incluye

| Archivo / carpeta | Para qué |
|---|---|
| `Dockerfile.dbt` | Imagen `ae2026/dbt:1.12` con dbt Core, dbt-snowflake, MetricFlow y el connector de Snowflake. |
| `docker-compose.yml` | Servicio `dbt` (perfil `tools`), Postgres de metadata y Metabase. |
| `Makefile` | Atajos: build, up, `dbt-build LEVEL=N`, `mf-validate`, contract, monitoring. |
| `requirements.txt` | Runtime del módulo, con versiones fijadas. |
| `requirements-dev.txt` | Lint y CI (ruff, SQLFluff, yamllint, pre-commit). |
| `.env.example` | Plantilla de variables de entorno (credenciales Snowflake, Metabase). |
| `.devcontainer/` | Entorno de GitHub Codespaces con Docker y Python 3.12. |
| `.github/workflows/dbt-ci.yml` | CI que detecta los niveles existentes y valida solo esos. |
| `.sqlfluff`, `.yamllint`, `pyproject.toml` | Reglas de estilo compartidas. |

## Qué **no** incluye

- `nivel-*/` con los labs resueltos: se construyen durante el roadmap.
- La documentación de las sections: vive en la plataforma del curso.
- Credenciales, `profiles.yml`, `target/`, `logs/` y datos crudos.

---

## Requisitos

1. Cuenta de GitHub (para el fork y el Codespace).
2. Cuenta de Snowflake (trial) con un rol con privilegios de cuenta para
   el bootstrap inicial.
3. Docker con Compose v2 si se ejecuta en local, o un Codespace con el
   devcontainer de este repo.

---

## Puesta en marcha

### 1. Fork y Codespace

1. Crear un fork de este repo en la cuenta personal.
2. Abrir el fork en GitHub → **Code** → **Codespaces** → **Create
   codespace on main**.
3. Esperar el `postCreateCommand` (instala las herramientas de lint).

El devcontainer ya trae Docker-in-Docker, así que `docker compose`
funciona dentro del Codespace.

### 2. Credenciales

```bash
cp .env.example .env
chmod 600 .env
```

Completar en `.env`:

- `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD`
- `MB_ENCRYPTION_SECRET_KEY` (16+ caracteres, fijarla desde el día 1)
- `METABASE_ADMIN_EMAIL`, `METABASE_ADMIN_PASSWORD`

`.env` está en `.gitignore`: nunca se commitea.

### 3. Imagen y servicios

```bash
make build            # construye ae2026/dbt:1.12
make up               # Metabase + Postgres de metadata
make metabase-setup   # admin + conexión Snowflake (idempotente)
```

Metabase queda en <http://localhost:3001>.

### 4. Labs

Cada nivel se construye dentro de `nivel-N/` siguiendo su section. La
infraestructura es compartida: no hay un compose por nivel.

```bash
# nivel 0 — SQL puro sobre Snowflake
make level0-bootstrap
make level0-upload
make level0-sql SQL=nivel-0/sql/01_grano.sql

# niveles 1-5 — dbt
make dbt-parse LEVEL=3
make dbt-build LEVEL=3
make dbt-test  LEVEL=3

# nivel 4 — semantic layer + BI
make mf-validate LEVEL=4
make semantic-view

# nivel 5 — contrato y monitoreo
make contract
make monitoring
```

`make help` lista todos los targets. El nivel se elige con `LEVEL=N`
(default `5`).

---

## Estructura esperada al terminar cada nivel

```
nivel-0/   sql/ + scripts/          SQL analítico en Snowflake (sin dbt)
nivel-1/   dbt_project/ + scripts/  capas analíticas con dbt
nivel-2/   dbt_project/ + scripts/  métricas como código
nivel-3/   dbt_project/ + scripts/  confianza analítica (tests, CI)
nivel-4/   dbt_project/ + scripts/  semantic layer + BI (Metabase)
nivel-5/   dbt_project/ + scripts/  producción (contratos, monitoreo, SCD2)
```

Cada nivel arranca copiando el `dbt_project/` del nivel anterior y lo
cierra en verde con `make dbt-build LEVEL=N`.

## Puertos

| Puerto | Servicio |
|---|---|
| 3001 | Metabase |
| 8088 | `make dbt-docs-serve` |
| 5432 | Postgres interno de Metabase (no expuesto al host) |

## Reglas del repo

- **Nunca** commitear `.env`, `profiles.yml`, `target/`, `logs/`,
  `dbt_packages/`, `venv/` ni datos crudos (parquet).
- Las credenciales se leen del entorno; no se escriben en el código.
- El SQL sigue el dialecto Snowflake estándar.
- Los modelos se validan con `dbt parse` (parser v2) antes de cada build.

## Problemas comunes

| Síntoma | Causa / solución |
|---|---|
| `env file .env not found` | Falta `cp .env.example .env`. |
| `Cannot connect to the Docker daemon` | El devcontainer no terminó de arrancar; reiniciar el Codespace. |
| Metabase pide configuración otra vez | Se borró el volumen: `docker compose down -v` lo resetea a propósito. |
| `Object does not exist: AE_ANALYTICS` | Falta el bootstrap del nivel 0 con un rol de cuenta. |
| `profiles.yml not found` | `make profiles` copia los ejemplos de cada nivel existente. |

## Referencias

- Roadmap del módulo: secciones de Analytics Engineering en la plataforma.
- dbt Core 1.12: <https://docs.getdbt.com/docs/core/installation>
- Snowflake + dbt: <https://docs.getdbt.com/docs/core/connect-data-platform/snowflake-setup>
- MetricFlow: <https://docs.getdbt.com/docs/build/about-metricflow>
