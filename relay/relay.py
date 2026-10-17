# -*- coding: utf-8 -*-
"""
Tube9 Relay  --  puente entre la app de iOS 9.3.5 y YouTube.

Por que existe este programa:
  iOS 9.3.5 (agosto de 2016) NO confia en los certificados de Let's Encrypt
  (ISRG Root X1, incorporado a Apple a finales de 2016) ni en los de Google
  (GTS Root R1, "clientes anteriores a 2018 pueden ser incompatibles").
  Resultado: desde el iPhone/iPad viejo, cualquier HTTPS moderno da error de
  certificado.  La solucion limpia es NO usar HTTPS: esta app habla con este
  relay por HTTP plano dentro de tu red (o por tu IP publica) y es el relay,
  con TLS moderno y una IP residencial, quien habla con YouTube.

  Ademas, al ser TU conexion (IP de casa, no de datacenter) YouTube confia mas
  y no te pone "Inicia sesion para confirmar que no eres un bot".

Solo usa la biblioteca estandar de Python 3.8. No necesita pip ni instalar nada.

Uso:
    python relay.py
    python relay.py --puerto 8787 --token m1clave --cookies cookies.txt

Endpoints (todos bajo /api):
    GET /api/health              -> estado del servicio
    GET /api/diag                -> pruebas y diagnostico
    GET /api/search?q=TEXTO      -> resultados de busqueda (JSON)
    GET /api/stream?id=VIDEOID   -> datos + URL reproducible (JSON)
    GET /api/video?id=VIDEOID    -> el MP4 en si (soporta Range)
    GET /api/thumb?id=VIDEOID    -> miniatura JPEG
    GET /                        -> pagina HTML de estado (abrela en el navegador)

Con --token, todas las llamadas a /api deben llevar ?t=ELTOKEN
(o la cabecera X-Tube9-Token).
"""

import argparse
import gzip
import io
import json
import os
import re
import socket
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# --------------------------------------------------------------------------
#  Cliente de YouTube (InnerTube).  ANDROID_VR es hoy el cliente que todavia
#  entrega URLs directas de video sin obligar a descifrar la firma "nsig".
# --------------------------------------------------------------------------
API_KEY = "AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w"
YT_API = "https://www.youtube.com/youtubei/v1"

CLIENTES = [
    {
        "nombre": "ANDROID_VR",
        "key": API_KEY,
        "ua": "com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12; en_US) gzip",
        "ctx": {
            "clientName": "ANDROID_VR",
            "clientVersion": "1.60.19",
            "androidSdkVersion": 32,
            "hl": "es",
            "gl": "ES",
        },
    },
    {
        "nombre": "ANDROID_VR_ALT",
        "key": API_KEY,
        "ua": "com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12; en_US) gzip",
        "ctx": {
            "clientName": "ANDROID_VR",
            "clientVersion": "1.61.20",
            "androidSdkVersion": 32,
            "hl": "es",
            "gl": "ES",
        },
    },
]

# --------------------------------------------------------------------------
#  Estado global (configuracion + caches en memoria)
# --------------------------------------------------------------------------
CONFIG = {
    "puerto": 8787,
    "token": "",
    "cookies": "",          # cabecera Cookie cruda, p.ej. "SID=...; HSID=..."
    "verbose": False,
}

_cache_player = {}   # videoId -> (timestamp, dict)
_cache_busqueda = {} # consulta  -> (timestamp, list)
_cache_thumbs = {}   # videoId  -> (timestamp, bytes, content_type)
_cache_lock = threading.Lock()

TTL_PLAYER = 30 * 60      # las URLs de YouTube caducan ~6 h; 30 min es holgado
TTL_BUSQUEDA = 10 * 60
TTL_THUMB = 24 * 3600
MAX_THUMBS = 400


def log(*a):
    if CONFIG["verbose"]:
        print("  [depuracion]", *a)


# --------------------------------------------------------------------------
#  Utilidades HTTP
# --------------------------------------------------------------------------
def peticion_json(url, cuerpo, cliente):
    """POST JSON a la API InnerTube de YouTube."""
    datos = json.dumps(cuerpo).encode("utf-8")
    cabeceras = {
        "Content-Type": "application/json",
        "User-Agent": cliente["ua"],
        "Accept-Language": "es-ES,es;q=0.9",
        "Origin": "https://www.youtube.com",
    }
    if CONFIG["cookies"]:
        cabeceras["Cookie"] = CONFIG["cookies"]
    req = urllib.request.Request(url, data=datos, headers=cabeceras, method="POST")
    with urllib.request.urlopen(req, timeout=25) as r:
        crudo = r.read()
    if crudo[:2] == b"\x1f\x8b":          # respuesta comprimida
        crudo = gzip.decompress(crudo)
    return json.loads(crudo.decode("utf-8", "replace"))


def extraer_texto(nodo):
    """YouTube usa a veces {'simpleText': x} y a veces {'runs': [{'text': x}]}."""
    if not isinstance(nodo, dict):
        return None
    if nodo.get("simpleText"):
        return nodo["simpleText"]
    runs = nodo.get("runs")
    if isinstance(runs, list) and runs:
        return "".join(r.get("text", "") for r in runs)
    return None


def pista_por_patron(diccionario, sufijo):
    """Busca recursivamente una clave que termine en 'sufijo' (videoRenderer,
    compactVideoRenderer, etc.) y devuelve el primer valor encontrado."""
    if isinstance(diccionario, dict):
        for clave, valor in diccionario.items():
            if clave.endswith(sufijo):
                return valor
            hallado = pista_por_patron(valor, sufijo)
            if hallado is not None:
                return hallado
    elif isinstance(diccionario, list):
        for elemento in diccionario:
            hallado = pista_por_patron(elemento, sufijo)
            if hallado is not None:
                return hallado
    return None


def recoger_renderers(diccionario, sufijo, salida):
    """Acumula TODOS los nodos cuya clave termina en 'sufijo'."""
    if isinstance(diccionario, dict):
        for clave, valor in diccionario.items():
            if clave.endswith(sufijo) and isinstance(valor, dict):
                salida.append(valor)
            recoger_renderers(valor, sufijo, salida)
    elif isinstance(diccionario, list):
        for elemento in diccionario:
            recoger_renderers(elemento, sufijo, salida)


# --------------------------------------------------------------------------
#  Busqueda
# --------------------------------------------------------------------------
def buscar(consulta):
    ahora = time.time()
    with _cache_lock:
        guardado = _cache_busqueda.get(consulta)
        if guardado and ahora - guardado[0] < TTL_BUSQUEDA:
            return guardado[1]

    ultimo_error = "sin respuesta"
    for cliente in CLIENTES:
        try:
            datos = peticion_json(
                "%s/search?key=%s&prettyPrint=false" % (YT_API, cliente["key"]),
                {"query": consulta, "context": {"client": cliente["ctx"]}},
                cliente,
            )
        except Exception as e:  # noqa: BLE001
            ultimo_error = "fallo de red: %s" % e
            continue

        renderers = []
        recoger_renderers(datos, "VideoRenderer", renderers)
        resultados = []
        for r in renderers:
            vid = r.get("videoId")
            if not vid:
                continue
            miniaturas = (r.get("thumbnail") or {}).get("thumbnails") or []
            etiquetas = []
            for ins in r.get("badges") or []:
                txt = extraer_texto((ins.get("metadataBadgeRenderer") or {}).get("label"))
                if txt:
                    etiquetas.append(txt)
            resultados.append({
                "id": vid,
                "titulo": extraer_texto(r.get("title")),
                "canal": extraer_texto(r.get("shortBylineText") or r.get("longBylineText")),
                "duracion": extraer_texto(r.get("lengthText")),
                "vistas": extraer_texto(r.get("shortViewCountText") or r.get("viewCountText")),
                "publicado": extraer_texto(r.get("publishedTimeText")),
                "miniatura_remota": miniaturas[-1]["url"] if miniaturas else None,
                "etiquetas": etiquetas,
            })
        if resultados:
            with _cache_lock:
                _cache_busqueda[consulta] = (ahora, resultados)
            return resultados
        ultimo_error = "el cliente %s no devolvio resultados" % cliente["nombre"]
    raise RuntimeError(ultimo_error)


# --------------------------------------------------------------------------
#  Resolucion del video (obtener una URL reproducible)
# --------------------------------------------------------------------------
PREFERENCIA_ITAGS = [18, 22, 59, 78, 17]   # MP4 muxado (video+audio), H.264


def resolver_video(video_id):
    ahora = time.time()
    with _cache_lock:
        guardado = _cache_player.get(video_id)
        if guardado and ahora - guardado[0] < TTL_PLAYER:
            return guardado[1]

    ultimo_motivo = "sin respuesta"
    for cliente in CLIENTES:
        try:
            datos = peticion_json(
                "%s/player?key=%s&prettyPrint=false" % (YT_API, cliente["key"]),
                {
                    "videoId": video_id,
                    "contentCheckOk": True,
                    "racyCheckOk": True,
                    "context": {"client": cliente["ctx"]},
                },
                cliente,
            )
        except Exception as e:  # noqa: BLE001
            ultimo_motivo = "fallo de red: %s" % e
            continue

        estado = (datos.get("playabilityStatus") or {}).get("status")
        motivo = (datos.get("playabilityStatus") or {}).get("reason") or ""
        if estado != "OK":
            ultimo_motivo = "%s: %s" % (estado, motivo)
            log("cliente", cliente["nombre"], "->", ultimo_motivo)
            continue

        sd = datos.get("streamingData") or {}
        muxados = sd.get("formats") or []
        elegido = None
        for itag in PREFERENCIA_ITAGS:
            for f in muxados:
                if f.get("itag") == itag and f.get("url"):
                    elegido = f
                    break
            if elegido:
                break
        if elegido is None:
            for f in muxados:
                if f.get("url"):
                    elegido = f
                    break
        if elegido is None:
            ultimo_motivo = "sin formatos muxados con URL directa"
            continue

        vd = datos.get("videoDetails") or {}
        info = {
            "id": video_id,
            "titulo": vd.get("title"),
            "autor": vd.get("author"),
            "segundos": int(vd.get("lengthSeconds") or 0),
            "vistas": vd.get("viewCount"),
            "url_directa": elegido.get("url"),
            "itag": elegido.get("itag"),
            "mime": elegido.get("mimeType"),
            "calidad": elegido.get("qualityLabel") or elegido.get("quality"),
            "tamano": int(elegido.get("contentLength")) if elegido.get("contentLength") else None,
            "cliente": cliente["nombre"],
        }
        with _cache_lock:
            _cache_player[video_id] = (ahora, info)
        return info

    raise RuntimeError(ultimo_motivo)


# --------------------------------------------------------------------------
#  Miniatura
# --------------------------------------------------------------------------
def obtener_miniatura(video_id):
    ahora = time.time()
    with _cache_lock:
        guardado = _cache_thumbs.get(video_id)
        if guardado and ahora - guardado[0] < TTL_THUMB:
            return guardado[1], guardado[2]

    for nombre in ("hqdefault.jpg", "mqdefault.jpg", "default.jpg"):
        url = "https://i.ytimg.com/vi/%s/%s" % (video_id, nombre)
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=15) as r:
                cuerpo = r.read()
                tipo = r.headers.get("Content-Type", "image/jpeg")
            if cuerpo:
                with _cache_lock:
                    if len(_cache_thumbs) > MAX_THUMBS:
                        _cache_thumbs.clear()
                    _cache_thumbs[video_id] = (ahora, cuerpo, tipo)
                return cuerpo, tipo
        except Exception:  # noqa: BLE001
            continue
    return None, None


# --------------------------------------------------------------------------
#  Servidor HTTP
# --------------------------------------------------------------------------
class Manejador(BaseHTTPRequestHandler):
    server_version = "Tube9Relay/1.0"
    protocol_version = "HTTP/1.1"

    # ---- utilidades de respuesta ----
    def _json(self, objeto, codigo=200):
        cuerpo = json.dumps(objeto, ensure_ascii=False).encode("utf-8")
        self.send_response(codigo)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(cuerpo)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(cuerpo)

    def _bytes(self, cuerpo, tipo, codigo=200, extra=None):
        self.send_response(codigo)
        self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(len(cuerpo)))
        self.send_header("Accept-Ranges", "bytes")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        try:
            self.wfile.write(cuerpo)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _token_ok(self, parametros):
        if not CONFIG["token"]:
            return True
        recibido = (parametros.get("t", [""])[0]
                    or self.headers.get("X-Tube9-Token", ""))
        return recibido == CONFIG["token"]

    def _base_publica(self):
        host = self.headers.get("Host") or ("%s:%d" % (ip_local(), CONFIG["puerto"]))
        return "http://%s" % host

    def log_message(self, formato, *args):
        if CONFIG["verbose"]:
            sys.stderr.write("  %s - %s\n" % (self.address_string(), formato % args))

    # ---- GET ----
    def do_GET(self):
        partes = urllib.parse.urlparse(self.path)
        ruta = partes.path.rstrip("/") or "/"
        parametros = urllib.parse.parse_qs(partes.query)

        if ruta == "/":
            return self._pagina_estado()

        if not ruta.startswith("/api"):
            return self._json({"ok": False, "error": "ruta desconocida"}, 404)

        if not self._token_ok(parametros):
            return self._json({"ok": False, "error": "token incorrecto"}, 403)

        try:
            if ruta == "/api/health":
                return self._json({
                    "ok": True, "servicio": "tube9-relay", "version": "1.0.0",
                    "hora": int(time.time()), "cookies": bool(CONFIG["cookies"]),
                })

            if ruta == "/api/diag":
                return self._json(diagnostico())

            if ruta == "/api/search":
                consulta = (parametros.get("q", [""])[0] or "").strip()
                if not consulta:
                    return self._json({"ok": False, "error": "falta el parametro q"})
                resultados = buscar(consulta)
                base = self._base_publica()
                for r in resultados:
                    r["miniatura"] = "%s/api/thumb?id=%s" % (base, r["id"])
                return self._json({"ok": True, "consulta": consulta, "resultados": resultados})

            if ruta == "/api/stream":
                video_id = (parametros.get("id", [""])[0] or "").strip()
                if not video_id:
                    return self._json({"ok": False, "error": "falta el parametro id"})
                info = resolver_video(video_id)
                info = dict(info)
                info["url_proxy"] = "%s/api/video?id=%s" % (self._base_publica(), video_id)
                info["ok"] = True
                return self._json(info)

            if ruta == "/api/thumb":
                video_id = (parametros.get("id", [""])[0] or "").strip()
                if not video_id:
                    return self._json({"ok": False, "error": "falta el parametro id"})
                cuerpo, tipo = obtener_miniatura(video_id)
                if not cuerpo:
                    return self._json({"ok": False, "error": "sin miniatura"}, 404)
                return self._bytes(cuerpo, tipo, extra={"Cache-Control": "max-age=86400"})

            if ruta == "/api/video":
                video_id = (parametros.get("id", [""])[0] or "").strip()
                if not video_id:
                    return self._json({"ok": False, "error": "falta el parametro id"})
                return self._servir_video(video_id)

            return self._json({"ok": False, "error": "ruta desconocida"}, 404)

        except urllib.error.HTTPError as e:
            return self._json({"ok": False, "error": "HTTP %s de origen" % e.code})
        except Exception as e:  # noqa: BLE001
            return self._json({"ok": False, "error": str(e)})

    # ---- el MP4, con soporte de Range (AVPlayer lo pide) ----
    def _servir_video(self, video_id):
        try:
            info = resolver_video(video_id)
        except Exception as e:  # noqa: BLE001
            return self._json({"ok": False, "error": str(e)})

        url = info["url_directa"]
        cabeceras = {
            "User-Agent": "com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12) gzip",
            "Accept-Encoding": "identity",
        }
        peticion_rango = self.headers.get("Range")
        if peticion_rango:
            cabeceras["Range"] = peticion_rango

        try:
            req = urllib.request.Request(url, headers=cabeceras)
            with urllib.request.urlopen(req, timeout=30) as origen:
                codigo = origen.getcode()
                tipo = origen.headers.get("Content-Type", "video/mp4")
                self.send_response(codigo if codigo in (200, 206) else 200)
                self.send_header("Content-Type", tipo)
                for cabecera in ("Content-Length", "Content-Range", "Accept-Ranges"):
                    valor = origen.headers.get(cabecera)
                    if valor:
                        self.send_header(cabecera, valor)
                self.send_header("Accept-Ranges", "bytes")
                self.send_header("Cache-Control", "no-store")
                self.end_headers()
                while True:
                    trozo = origen.read(65536)
                    if not trozo:
                        break
                    self.wfile.write(trozo)
        except (BrokenPipeError, ConnectionResetError):
            pass

    # ---- pagina de estado, para comprobar el relay desde el navegador ----
    def _pagina_estado(self):
        ip = ip_local()
        html = """<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Tube9 Relay</title>
<style>
 body{font-family:-apple-system,'Segoe UI',sans-serif;background:#0f1115;color:#e8eaed;
      margin:0;padding:32px;line-height:1.5}
 .caja{max-width:640px;margin:0 auto;background:#171a21;border:1px solid #262b36;
      border-radius:16px;padding:28px}
 h1{margin:0 0 4px;font-size:22px;letter-spacing:-.02em}
 .ok{display:inline-block;background:#1e3a2a;color:#6ee7a8;border-radius:999px;
     padding:3px 12px;font-size:13px;font-weight:600}
 code{background:#0b0d12;padding:2px 7px;border-radius:6px;font-size:13px;color:#8ab4f8}
 .fila{display:flex;justify-content:space-between;padding:9px 0;border-bottom:1px solid #232833;font-size:14px}
 input{width:100%%;box-sizing:border-box;background:#0b0d12;border:1px solid #2a3140;color:#e8eaed;
       padding:11px 13px;border-radius:10px;font-size:15px;margin:10px 0}
 button{background:#2f6df6;color:#fff;border:0;border-radius:10px;padding:11px 20px;font-size:15px;font-weight:600}
 pre{background:#0b0d12;padding:12px;border-radius:10px;overflow:auto;font-size:12px;max-height:340px}
</style></head><body><div class="caja">
<h1>Tube9 Relay</h1><p><span class="ok">ACTIVO</span> &nbsp;escuchando en el puerto %(puerto)d</p>
<p style="color:#9aa0a6;font-size:14px">Pon <b>esta direccion</b> en Ajustes dentro de la app:</p>
<p><code>http://%(ip)s:%(puerto)d</code></p>
<p style="color:#9aa0a6;font-size:14px">Prueba la busqueda desde aqui:</p>
<input id="q" value="musica electronica" placeholder="Buscar en YouTube">
<button onclick="probar()">Probar</button>
<pre id="salida">esperando...</pre>
</div>
<script>
function probar(){
  var q=document.getElementById('q').value;
  document.getElementById('salida').textContent='consultando...';
  fetch('/api/search?q='+encodeURIComponent(q))
   .then(function(r){return r.json()})
   .then(function(d){
      if(!d.ok){document.getElementById('salida').textContent='ERROR: '+d.error;return;}
      document.getElementById('salida').textContent =
        d.resultados.slice(0,8).map(function(v){
          return (v.duracion||'')+'  '+v.titulo+'\n     '+v.canal;
        }).join('\n\n');
   })
   .catch(function(e){document.getElementById('salida').textContent='FALLO: '+e});
}
</script></body></html>""" % {"ip": ip, "puerto": CONFIG["puerto"]}
        cuerpo = html.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(cuerpo)))
        self.end_headers()
        self.wfile.write(cuerpo)


# --------------------------------------------------------------------------
#  Diagnostico
# --------------------------------------------------------------------------
def diagnostico():
    pruebas = []
    for cliente in CLIENTES:
        try:
            t0 = time.time()
            datos = peticion_json(
                "%s/player?key=%s&prettyPrint=false" % (YT_API, cliente["key"]),
                {"videoId": "dQw4w9WgXcQ", "contentCheckOk": True, "racyCheckOk": True,
                 "context": {"client": cliente["ctx"]}},
                cliente,
            )
            sd = datos.get("streamingData") or {}
            muxados = [f for f in (sd.get("formats") or []) if f.get("url")]
            pruebas.append({
                "cliente": cliente["nombre"],
                "estado": (datos.get("playabilityStatus") or {}).get("status"),
                "motivo": (datos.get("playabilityStatus") or {}).get("reason"),
                "muxados_con_url": ["%s/%s" % (f["itag"], f.get("qualityLabel")) for f in muxados],
                "ms": int((time.time() - t0) * 1000),
            })
        except Exception as e:  # noqa: BLE001
            pruebas.append({"cliente": cliente["nombre"], "error": str(e)})
    return {
        "ok": True,
        "cookies_configuradas": bool(CONFIG["cookies"]),
        "python": sys.version.split()[0],
        "pruebas": pruebas,
        "consejo": ("Si todos los clientes dicen LOGIN_REQUIRED, exporta tus cookies "
                    "de YouTube a cookies.txt y arranca con --cookies cookies.txt"),
    }


def ip_local():
    """IP de esta maquina dentro de la red local (la que debe usar el iPhone)."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception:  # noqa: BLE001
        return "127.0.0.1"
    finally:
        s.close()


def cargar_cookies(ruta):
    """Lee un cookies.txt (formato Netscape, el que exporta cualquier extension)
    y lo convierte en una cabecera Cookie."""
    pares = []
    with io.open(ruta, "r", encoding="utf-8", errors="replace") as f:
        for linea in f:
            linea = linea.strip()
            if not linea or linea.startswith("#"):
                continue
            campos = linea.split("\t")
            if len(campos) >= 7:
                pares.append("%s=%s" % (campos[5], campos[6]))
    return "; ".join(pares)


# --------------------------------------------------------------------------
def main():
    analizador = argparse.ArgumentParser(description="Tube9 Relay")
    analizador.add_argument("--puerto", type=int, default=8787)
    analizador.add_argument("--token", default="", help="clave opcional que debe enviar la app")
    analizador.add_argument("--cookies", default="", help="ruta a cookies.txt de YouTube")
    analizador.add_argument("--verbose", action="store_true")
    args = analizador.parse_args()

    CONFIG["puerto"] = args.puerto
    CONFIG["token"] = args.token
    CONFIG["verbose"] = args.verbose
    if args.cookies:
        if os.path.isfile(args.cookies):
            CONFIG["cookies"] = cargar_cookies(args.cookies)
            print("Cookies cargadas: %d caracteres" % len(CONFIG["cookies"]))
        else:
            print("AVISO: no existe el fichero de cookies %r" % args.cookies)

    ip = ip_local()
    print("")
    print("  Tube9 Relay 1.0.0   Python %s" % sys.version.split()[0])
    print("  " + "-" * 52)
    print("  Escuchando en   0.0.0.0:%d" % CONFIG["puerto"])
    print("  En este PC      http://127.0.0.1:%d" % CONFIG["puerto"])
    print("  En el iPhone    http://%s:%d" % (ip, CONFIG["puerto"]))
    if CONFIG["token"]:
        print("  Token           %s" % CONFIG["token"])
    print("  " + "-" * 52)
    print("  Deja esta ventana abierta mientras usas la app.")
    print("  Para parar: Ctrl+C")
    print("")

    servidor = ThreadingHTTPServer(("0.0.0.0", CONFIG["puerto"]), Manejador)
    servidor.daemon_threads = True
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        print("\n  Relay detenido.")
        servidor.shutdown()


if __name__ == "__main__":
    main()
