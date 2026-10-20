# ============================================================
# AE-2026 · atajos de operación del módulo
# Todo se ejecuta desde la RAÍZ del módulo. El nivel se elige con
# LEVEL=N (default 5).
#
#   make build                 # construye la imagen dbt
#   make up                    # levanta Metabase + Postgres
#   make dbt-build LEVEL=3     # dbt build del nivel 3
#   make dbt-parse LEVEL=4
#   make metabase-setup        # crea admin + conexión Snowflake
# ============================================================
SHELL := /bin/bash
COMPOSE := docker compose
DBT_RUN := $(COMPOSE) --profile tools run --rm

LEVEL ?= 5
PROJECT_DIR := nivel-$(LEVEL)/dbt_project
# El bootstrap crea warehouse/rol/base/schemas: requiere un rol con
# privilegios de cuenta (el owner del trial). El resto de los labs
# corre con AE_ROLE (mínimo privilegio).
BOOTSTRAP_ROLE ?= ACCOUNTADMIN

.PHONY: help env profiles build up down ps logs \
        dbt-parse dbt-build dbt-test dbt-snapshot dbt-docs dbt-docs-serve \
        mf-validate \
        level0-bootstrap level0-upload level0-sql semantic-view \
        metabase-setup contract monitoring clean

help:
	@echo "AE-2026 — targets disponibles:"
	@echo "  make build                      Construir imagen dbt (Dockerfile.dbt)"
	@echo "  make up / down / ps / logs      Metabase + Postgres de metadata"
	@echo "  make dbt-parse  LEVEL=5         dbt parse (parser v2 por flags)"
	@echo "  make dbt-build  LEVEL=5         dbt build contra Snowflake (dev)"
	@echo "  make dbt-test   LEVEL=3         dbt test"
	@echo "  make dbt-snapshot LEVEL=5       dbt snapshot (SCD2)"
	@echo "  make dbt-docs   LEVEL=5         dbt docs generate"
	@echo "  make dbt-docs-serve LEVEL=5     dbt docs serve en :8088"
	@echo "  make mf-validate LEVEL=5        Valida el semantic layer (MetricFlow)"
	@echo "  make level0-bootstrap           Crea DB/schemas/warehouse/rol"
	@echo "  make level0-upload              Descarga y carga NYC Taxi a RAW"
	@echo "  make level0-sql SQL=...         Ejecuta un .sql con run_sql.py"
	@echo "  make semantic-view              Crea el Semantic View en Snowflake"
	@echo "  make metabase-setup             Configura admin + conexión Snowflake"
	@echo "  make contract / monitoring      Scripts del nivel 5"
	@echo "  make clean                      Borra target/, logs/, dbt_packages/"

env:
	@test -f .env || (cp .env.example .env && chmod 600 .env && \
	  echo "Creado .env desde .env.example — completá las credenciales Snowflake.")

profiles: env
	@for lvl in 1 2 3 4 5; do \
	  if [ ! -f nivel-$$lvl/dbt_project/profiles.yml ]; then \
	    cp nivel-$$lvl/dbt_project/profiles.yml.example nivel-$$lvl/dbt_project/profiles.yml; \
	    echo "profiles.yml creado para nivel-$$lvl"; \
	  fi; \
	done

build: env
	$(COMPOSE) build dbt

up: env
	$(COMPOSE) up -d metabase-db metabase

down:
	$(COMPOSE) down

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f metabase

dbt-parse: profiles
	$(DBT_RUN) dbt dbt parse --project-dir $(PROJECT_DIR) --profiles-dir $(PROJECT_DIR)

dbt-build: profiles
	$(DBT_RUN) dbt dbt build --project-dir $(PROJECT_DIR) --profiles-dir $(PROJECT_DIR) --target dev

dbt-test: profiles
	$(DBT_RUN) dbt dbt test --project-dir $(PROJECT_DIR) --profiles-dir $(PROJECT_DIR) --target dev

dbt-snapshot: profiles
	$(DBT_RUN) dbt dbt snapshot --project-dir $(PROJECT_DIR) --profiles-dir $(PROJECT_DIR) --target dev

dbt-docs: profiles
	$(DBT_RUN) dbt dbt docs generate --project-dir $(PROJECT_DIR) --profiles-dir $(PROJECT_DIR) --target dev

dbt-docs-serve: dbt-docs
	$(DBT_RUN) -p 8088:8088 dbt dbt docs serve --project-dir $(PROJECT_DIR) --profiles-dir $(PROJECT_DIR) --port 8088 --no-browser

# MetricFlow resuelve el proyecto desde el cwd y el perfil desde
# DBT_PROFILES_DIR (no acepta --project-dir como dbt).
mf-validate: profiles
	$(DBT_RUN) -w /usr/app/$(PROJECT_DIR) \
	  -e DBT_PROFILES_DIR=/usr/app/$(PROJECT_DIR) \
	  dbt mf validate-configs

level0-bootstrap: env
	$(DBT_RUN) dbt python nivel-0/scripts/run_sql.py nivel-0/sql/00_bootstrap.sql --role $(BOOTSTRAP_ROLE)

level0-upload: env
	$(DBT_RUN) dbt python nivel-0/scripts/01_upload_taxi.py

level0-sql: env
	@test -n "$(SQL)" || (echo "Uso: make level0-sql SQL=nivel-0/sql/01_grano.sql"; exit 1)
	$(DBT_RUN) dbt python nivel-0/scripts/run_sql.py $(SQL)

semantic-view: env
	$(DBT_RUN) dbt python nivel-0/scripts/run_sql.py nivel-4/sql/00_semantic_view.sql

metabase-setup: up profiles
	$(DBT_RUN) -e METABASE_URL=http://metabase:3000 dbt python nivel-4/scripts/02_metabase_setup.py

contract: env
	$(DBT_RUN) dbt python nivel-5/scripts/03_validate_contract.py nivel-5/contracts/fct_taxi_trips.yml

monitoring: env
	$(DBT_RUN) dbt python nivel-5/scripts/04_monitoring.py

clean:
	rm -rf nivel-*/dbt_project/target nivel-*/dbt_project/logs nivel-*/dbt_project/dbt_packages
