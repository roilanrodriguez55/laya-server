# test-laya

Entorno para correr y probar el servidor real de [laya](https://huggingface.co/convaiinnovations/laya)
(`laya-serve`, el CLI que trae el propio paquete `laya`). No es un mock: carga
checkpoints reales desde HuggingFace y corre inferencia real. No persiste
nada en base de datos.

## Estructura del repo

```
.
├── server/               # Servidor real de laya (laya-serve) + Dockerfile
├── bruno/laya-api/        # Coleccion de Bruno para probar la API
├── docker-compose.yml    # Orquestacion del contenedor laya
├── Makefile              # Atajos para correr local y con Docker
└── .env                  # Variables para docker-compose (HOST_PORT, etc)
```

## Requisitos

- Python 3.9+ (para correr local) o Docker + Docker Compose (para correr en contenedor)
- ~2.5 GB de disco para los checkpoints de HuggingFace (se cachean tras la primera descarga)
- ~4 GB de RAM libres si se cargan los 3 checkpoints (`english`, `multilingual`, `typed-decisions`) a la vez

## Uso rapido con Make

```bash
make help          # lista todos los targets disponibles
```

### Local (sin Docker)

```bash
make run            # instala deps en server/.venv y levanta laya-serve en 127.0.0.1:8000, sin auth
make run-auth       # igual, pero con LAYA_API_KEY=secret123
make health         # curl a http://127.0.0.1:8000/health
```

### Docker

```bash
make docker-build   # docker compose build
make docker-up       # levanta el contenedor en background (puerto host: HOST_PORT en .env, default 8000)
make docker-up-fg    # igual, en primer plano con logs en vivo
make docker-health   # curl a http://127.0.0.1:8000/health
make docker-logs     # sigue los logs
make docker-down     # baja el contenedor (conserva el volumen de checkpoints)
make docker-down-clean # baja el contenedor y borra el volumen de checkpoints
```

El puerto expuesto en host se controla con `HOST_PORT` en `.env` (raiz del
repo); actualmente esta seteado a `51823`.

Documentacion completa del servidor (endpoints, variables de entorno,
autenticacion, despliegue con Docker, notas de memoria/GPU) en
[`server/README.md`](server/README.md).

## API

Unico endpoint de inferencia: `POST /v1/systemone`. Enruta automaticamente
al checkpoint (`english`, `multilingual` o `typed-decisions`) segun el
idioma detectado en el `state` recibido.

```json
{
  "state": "texto, email o JSON con el caso",
  "questions": {
    "nombre_pregunta": {
      "type": "choice | score | noul",
      "instructions": "pregunta en lenguaje natural",
      "criteria": {"opcion": "descripcion"}
    }
  }
}
```

`GET /health` no requiere autenticacion. Si `LAYA_API_KEY` esta seteada,
`POST /v1/systemone` exige `Authorization: Bearer <key>`.

## Probar la API con Bruno

La coleccion [`bruno/laya-api`](bruno/laya-api) trae ejemplos de los tres
tipos de pregunta (`choice`, `score`, `noul`), casos multi-pregunta,
multilingues y los errores esperados (400, 401, 422).

Environments disponibles:

- `local` → `http://127.0.0.1:8000` (server corrido con `make run`)
- `docker-local` → `http://127.0.0.1:51823` (server corrido con `make docker-up`, puerto de `.env`)

Abre la carpeta `bruno/laya-api` en [Bruno](https://www.usebruno.com/),
elige el environment correspondiente y corre las requests.

## Variables de entorno

| Variable | Donde | Efecto |
|---|---|---|
| `HOST_PORT` | `.env` (compose) | Puerto en el host mapeado al 8000 del contenedor |
| `LAYA_HOST` | server | Direccion de bind (default `0.0.0.0`) |
| `LAYA_PORT` | server | Puerto de bind (default `8000`) |
| `LAYA_DEVICE` | server | `cuda`, `cpu` o `mps` (auto-detecta por default) |
| `LAYA_PRELOAD` | server | Precargar los 3 checkpoints al arrancar en vez de on-demand |
| `LAYA_MODELS` | server | Restringe que checkpoints cargar (ej. `english`) |
| `LAYA_API_KEY` | server | Si se define, exige Bearer token en `POST /v1/systemone` |
