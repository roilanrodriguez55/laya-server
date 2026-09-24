# laya server (real)

Servidor real de [laya](https://huggingface.co/convaiinnovations/laya) —
`laya-serve`, el CLI que trae el propio paquete `laya`. No es un mock: carga
los checkpoints reales (`english`, `multilingual`, `typed-decisions`) desde
HuggingFace y corre inferencia real. No persiste nada en base de datos.

## Requisitos

- Python 3.9 o superior
- ~2.5 GB de espacio en disco para los checkpoints (se cachean en
  `~/.cache/huggingface/hub` la primera vez)
- Al menos ~4 GB de RAM libres para tener los 3 checkpoints en memoria a la
  vez sin hacer swap pesado

## Paso a paso para correr el servidor

1. Entra a la carpeta del servidor:

   ```bash
   cd server
   ```

2. Crea el entorno virtual (solo la primera vez):

   ```bash
   python3 -m venv .venv
   ```

3. Actívalo:

   ```bash
   source .venv/bin/activate
   ```

4. Instala `laya` con soporte de servidor:

   ```bash
   pip install -r requirements.txt
   ```

5. Levanta el servidor real. `laya-serve` no tiene flags de CLI (`--host`,
   `--port`, etc no existen) — toda la configuracion es por variables de
   entorno:

   ```bash
   LAYA_HOST=127.0.0.1 LAYA_PORT=8000 laya-serve
   ```

   La primera vez descarga los 3 checkpoints (~2.3 GB) desde HuggingFace, lo
   que puede tardar varios minutos segun tu conexion. Las siguientes veces
   arranca en segundos porque ya quedan cacheados en
   `~/.cache/huggingface/hub`.

6. Verifica que responde (en otra terminal):

   ```bash
   curl http://127.0.0.1:8000/health
   ```

   Deberia devolver `{"status":"ok","loaded":[...],"device":"auto"}`.

7. Apunta la coleccion de Bruno (`bruno/laya-api`, environment `local`) a
   `http://127.0.0.1:8000` — ya viene configurado por default.

8. Para detener el servidor: `Ctrl+C`, y `deactivate` para salir del venv.

## Variables de entorno soportadas por `laya-serve`

| Variable | Efecto |
|---|---|
| `LAYA_HOST` | Direccion de bind (default `0.0.0.0`) |
| `LAYA_PORT` | Puerto de bind (default `8000`) |
| `LAYA_DEVICE` | `cuda`, `cpu` o `mps` (por default auto-detecta) |
| `LAYA_PRELOAD` | Precargar los 3 checkpoints al arrancar en vez de on-demand |
| `LAYA_API_KEY` | Si se define, `POST /v1/systemone` exige `Authorization: Bearer <key>` (`GET /health` queda siempre sin auth) |

## Correrlo con autenticacion activada

Para probar los casos 401 de la coleccion de Bruno, usa el mismo valor en
`LAYA_API_KEY` y en la variable `apiKey` del environment de Bruno (ambos usan
`secret123` por default):

```bash
LAYA_HOST=127.0.0.1 LAYA_PORT=8000 LAYA_API_KEY=secret123 laya-serve
```

## Endpoints reales (confirmados via `/openapi.json` del propio servidor)

- `GET /health` — `{"status": "ok", "loaded": [...checkpoints...], "device": "..."}`
- `POST /v1/systemone` — unico endpoint de inferencia. Body:
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
  Enruta automaticamente al checkpoint `english`, `multilingual` o
  `typed-decisions` segun detecte el idioma del `state` (queda reflejado en
  `routing` de la respuesta).

### Errores reales observados

- `400` — body sin el campo `questions`
- `422` — tipo de pregunta desconocido, o `choice`/`score` sin `criteria`
- `401` — falta el bearer token o es invalido (solo si `LAYA_API_KEY` esta seteada)

## Nota

No hay endpoints `/predict`, `/predict/batch`, `/models`, `/qtypes` ni
`/presets` en el `laya-serve` real — esos existen unicamente en
`examples/server.py` del repo de laya (un script de ejemplo aparte), no en el
CLI que instala `pip install "laya[serve]"`.

## Despliegue con Docker

Hay un `Dockerfile` en esta carpeta y un `docker-compose.yml` en la raiz del
repo. La imagen usa `python:3.11-slim` + torch CPU-only (mucho mas liviana
que las ruedas CUDA que instala pip por default), corre como usuario no-root,
y persiste los checkpoints descargados en un volumen nombrado para no volver
a bajarlos en cada rebuild/restart.

### Paso a paso

1. Desde la raiz del repo, construye la imagen:

   ```bash
   docker compose build
   ```

2. Levanta el contenedor:

   ```bash
   docker compose up -d
   ```

   La primera vez que llega una request de inferencia real (no `/health`),
   `laya-serve` descarga el checkpoint que necesite (~2.3 GB si se usan los
   3) dentro del volumen `laya-hf-cache`. Reinicios y rebuilds posteriores
   reusan ese volumen, asi que no vuelve a descargar.

3. Verifica:

   ```bash
   curl http://127.0.0.1:8000/health
   ```

4. Corre la coleccion de Bruno contra `http://127.0.0.1:8000` (mismo puerto
   mapeado, no requiere cambios en el environment `local`).

5. Para bajarlo: `docker compose down` (usa `-v` solo si quieres borrar
   tambien el cache de checkpoints).

### Variables de entorno (compose)

Se configuran via un archivo `.env` en la raiz del repo (mismo directorio
que `docker-compose.yml`) o exportandolas antes de `docker compose up`:

```bash
# .env
LAYA_API_KEY=secret123
LAYA_DEVICE=cpu
LAYA_PRELOAD=0
LAYA_MODELS=english
```

### GPU

El `Dockerfile` instala torch CPU-only a proposito (imagen mas chica, no
requiere `nvidia-container-toolkit`). Para GPU: cambia la linea `pip install
torch --index-url https://download.pytorch.org/whl/cpu` por la variante CUDA
correspondiente, usa una imagen base con CUDA (o `nvidia/cuda` + Python), y
agrega `deploy.resources.reservations.devices` con `driver: nvidia` en el
`docker-compose.yml`.

### Nota sobre memoria

Cargar los 3 checkpoints en memoria simultaneamente puede rondar ~3-4 GB de
RAM. En una maquina/host con poca memoria disponible, limita
`LAYA_MODELS=english` (o el que necesites) para evitar swapping.
