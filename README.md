# Tube9 — cliente de YouTube para iOS 9.3.5 (armv7)

Cliente de YouTube ligero, **gratis y con interfaz plana moderna**, para
dispositivos de 32 bits que se quedaron en **iOS 9.3.5**:
iPhone 4S, iPhone 5, iPhone 5C, iPad 2, iPad 3, iPad 4, iPad mini 1 y iPod touch 5G.

Todo el proceso (compilar, empaquetar el `.ipa`) ocurre en **GitHub Actions,
gratis**, así que **no hace falta un Mac ni instalar un compilador en tu PC**.
El resultado es un `.ipa` que se descarga y se instala en el dispositivo.

> **Nota legal.** Tube9 no es una app oficial de YouTube ni está afiliada a
> Google. Accede al contenido a través de los mismos servicios web que usa la
> propia web de YouTube, por lo que siguen aplicándose las
> [Condiciones de Servicio de YouTube](https://www.youtube.com/t/terms).
> Es un proyecto educativo y de uso personal.

---

## Índice

1. [Qué hace](#1-qué-hace)
2. [Cómo funciona por dentro](#2-cómo-funciona-por-dentro)
3. [Parte A — Conseguir el `.ipa`](#parte-a--conseguir-el-ipa)
4. [Parte B — Preparar el dispositivo](#parte-b--preparar-el-dispositivo)
5. [Parte C — Instalar la app](#parte-c--instalar-la-app)
6. [Ajustes de la app](#ajustes-de-la-app)
7. [Modo relay (opcional)](#modo-relay-opcional)
8. [Problemas frecuentes](#problemas-frecuentes)
9. [Estructura del repositorio](#estructura-del-repositorio)
10. [Compilar en tu propio ordenador (opcional)](#compilar-en-tu-propio-ordenador-opcional)

---

## 1. Qué hace

| Pantalla | Qué ofrece |
|---|---|
| **Buscar** | Campo de búsqueda y lista de resultados con miniatura, título, canal, duración, visitas y fecha. |
| **Reproductor** | Reproduce el vídeo a pantalla completa con los controles nativos, con audio aunque el interruptor de silencio esté activado. |
| **Ajustes** | Modo directo/relay, dirección del relay, inicio de sesión en YouTube, diagnóstico de conexión y guía de certificados. |

Calidad de vídeo: **MP4/H.264 a 360p (itag 18, con audio incluido)**.
Es la máxima calidad reproducible en estos dispositivos: los chips de 32 bits
(A5/A6) **no pueden decodificar VP9 ni AV1** en hardware, así que no hay 720p.

Diseño: tema oscuro, tarjetas con esquinas redondeadas, tipografía del sistema,
rojo de marca `#FF0033` como único acento, cero degradados y cero efectos de
desenfoque (que además van mal en un A5).

---

## 2. Cómo funciona por dentro

```
                 ┌──────────────────────────────┐
   iPhone 4S     │  Tube9 (Objective-C, armv7)  │
   iPad 2   ───► │  AVPlayer ◄── itag 18 MP4    │
   iPod 5G       └───────────┬──────────────────┘
                             │
              MODO DIRECTO   │   MODO RELAY
      (recomendado, HTTPS)   │   (HTTP plano)
                             ▼
              ┌──────────────────────────────┐        ┌────────────────────┐
              │  youtubei/v1/player          │        │  relay.py en tu PC │
              │  cliente ANDROID_VR          │  ◄──►  │  (o un servidor)   │
              └──────────────────────────────┘        └────────────────────┘
```

* **InnerTube `ANDROID_VR`.** De los clientes públicos que expone YouTube, es el
  único que hoy devuelve **URLs directas de MP4 muxado** sin obligar a descifrar
  la firma `nsig` (que es lo que hacen NewPipe con Rhino o `yt-dlp` con Node).
* **`AVPlayer`** reproduce la URL directamente. Se comprobó que el servidor de
  vídeo responde `206 Partial Content` con `accept-ranges: bytes`, así que el
  *seeking* funciona sin descargar el archivo entero.
* **Cookies de sesión.** `NSURLSession` usa el almacén de cookies compartido, y
  el inicio de sesión se hace con `UIWebView` (no `WKWebView`) precisamente
  porque en iOS 9 sí comparte esas cookies. Después de entrar, todas las
  peticiones van autenticadas y desaparece el aviso
  *«Inicia sesión para confirmar que no eres un bot»*.
* **Modo relay.** Para cuando no se quieren tocar certificados: la app habla por
  **HTTP plano** con un pequeño servidor propio (`relay/relay.py`, sólo
  biblioteca estándar de Python) que es quien hace de puente con YouTube.

---

## Parte A — Conseguir el `.ipa`

El repositorio ya trae un *workflow* que compila el IPA automáticamente.

### Opción 1: desde el navegador

1. Entra en **https://github.com/lofturb/tube9/actions**.
2. Pulsa **«Construir IPA (iOS 9.3.5 / armv7)»** → **Run workflow**.
3. Espera 3-6 minutos (la primera vez tarda más porque descarga el *toolchain*).
4. Descarga el resultado de dos formas:
   * **Actions → ejecución terminada → Artifacts → `Tube9-ipa-armv7`**
     (requiere tener sesión iniciada en GitHub), o
   * **Releases** → la última entrada `build-AAAAMMDD-…` → descarga el `.ipa`
     adjunto **sin necesidad de iniciar sesión**.

### Opción 2: desde tu PC con `gh`

```powershell
# Lanzar la compilación
gh workflow run "Construir IPA (iOS 9.3.5 / armv7)" --repo lofturb/tube9

# Ver el estado
gh run list --repo lofturb/tube9

# Descargar el IPA de la última ejecución (se descomprime solo)
gh run download --repo lofturb/tube9 --name Tube9-ipa-armv7
```

---

## Parte B — Preparar el dispositivo

Son **dos cosas de una sola vez**: el *jailbreak* y los certificados.

### B.1 Jailbreak

El dispositivo necesita **jailbreak** (es la vía para instalar apps que no están
firmadas por Apple).

* Para iOS 9.3.5 en dispositivos de 32 bits, la ruta habitual está en
  **https://ios.cfw.guide/** (busca tu modelo y versión). Herramientas conocidas
  para esta versión: **Phoenix** y **JailbreakMe 4.0**.
* Si tu dispositivo ya tiene Cydia instalado, este paso ya está hecho.

### B.2 Certificados actualizados ← **este es el paso clave**

iOS 9.3.5 es de 2016 y **no incluye las autoridades de certificación modernas**.
Por eso Safari, Cydia y cualquier app fallan hoy con errores de certificado
(`NSURLErrorServerCertificateUntrusted`, `-1202`).

No es un fallo de Tube9: es que iOS 9 no conoce a Let's Encrypt ni a las raíces
nuevas de Google. La solución que usa la comunidad de dispositivos antiguos es
**instalar las raíces modernas**:

1. Descarga estos certificados **en el propio dispositivo** (o pásalos por
   correo/AirDrop como archivos `.cer` / `.pem`):
   * **ISRG Root X1** → https://letsencrypt.org/certificates/
   * **GTS Root R1** y **GTS Root R4** → https://pki.goog/repository/
2. Abre cada archivo en el dispositivo → **Ajustes → General → Perfil** →
   *Instalar*.
3. En iOS 9, una raíz instalada manualmente pasa a ser **de confianza para SSL
   automáticamente**. Si tu dispositivo muestra además
   *Ajustes → General → Información → Ajustes de confianza de certificados*,
   activa ahí el interruptor de cada certificado.

Con esto, la app puede hablar con YouTube directamente por HTTPS desde tu
conexión de casa (una IP residencial, que YouTube trata mucho mejor que las IP
de centro de datos).

> ¿No quieres tocar certificados? Usa el **modo relay** (ver más abajo): la app
> habla por HTTP plano con tu servidor y el problema de TLS desaparece.

---

## Parte C — Instalar la app

El `.ipa` que genera Theos está **pseudo-firmado** (`ldid`), así que el
dispositivo lo aceptará sólo si tiene **AppSync Unified**.

1. En Cydia, añade el repositorio de AppSync Unified:
   * `https://cydia.akemi.ai/` (repositorio de Karen/akemi), o
   * `https://lukezed.github.io/repo/`
   e instala **AppSync Unified**.
2. Instala el `.ipa` de cualquiera de estas formas:
   * **Filza** (o iFile): copia el `.ipa` al dispositivo, tócalo y elige
     *Instalar*.
   * **Por SSH**: `ipainstaller Tube9_1.0.0.ipa`
     (el paquete `ipainstaller` está en Cydia).
3. Abre **Tube9** desde la pantalla de inicio.

---

## Ajustes de la app

### Modo directo vs modo relay

* **Directo** (por defecto): la app habla con YouTube por HTTPS. Necesita el
  paso **B.2**.
* **Relay**: activa *Usar relay propio* e introduce la dirección, por ejemplo
  `http://192.168.1.50:8787`. Si el relay tiene token, escríbelo también.

### Iniciar sesión (recomendado)

**Ajustes → Iniciar sesion en YouTube.** Se abre la pantalla de Google dentro de
la app; al entrar con tu cuenta, las cookies quedan guardadas y las peticiones
pasan a ir autenticadas. Esto evita el

> «Inicia sesión para confirmar que no eres un bot»

que YouTube muestra **de forma aleatoria y por vídeo** cuando detecta muchas
peticiones anónimas (por ejemplo, desde una IP de centro de datos).

Alternativa: **Ajustes → Pegar cookies manualmente**, donde puedes pegar la
cabecera `Cookie` de `youtube.com` copiada desde un navegador de tu PC
(`SID=…; HSID=…; …`).

### Diagnóstico

**Ajustes → Probar conexion** prueba la ruta configurada y devuelve un informe
en castellano: modo, cliente usado, si hay sesión iniciada, y el resultado real
de la conexión. Si falla un certificado, te lo dice explícitamente.

---

## Modo relay (opcional)

Sólo hace falta si **no** quieres (o no puedes) instalar las raíces en el
dispositivo, o si prefieres que todo el tráfico de vídeo pase por un servidor.

`relay/relay.py` es un servidor de **sólo biblioteca estándar de Python 3** (sin
`pip install`), pensado para arrancarse en Windows o Linux.

```powershell
# Arrancarlo en tu PC (Windows 7 con Python 3.8 funciona)
python relay\relay.py --puerto 8787

# Con token obligatorio y registro detallado
python relay\relay.py --puerto 8787 --token MiClaveSecreta --verbose
```

Endpoints que expone:

| Ruta | Para qué |
|---|---|
| `/` | Página de estado en HTML. |
| `/api/health` | Comprobación rápida (`{"ok": true, …}`). |
| `/api/diag` | Diagnóstico del lado del servidor. |
| `/api/search?q=…` | Búsqueda de vídeos. |
| `/api/stream?id=…` | Resuelve el vídeo y devuelve `url_directa` / `url_proxy`. |
| `/api/video?id=…` | Sirve el vídeo (soporta `Range`, imprescindible para AVPlayer). |
| `/api/thumb?u=…` | Miniaturas por HTTP plano. |

En el dispositivo, pon en Ajustes la IP **de tu PC en la red local**
(`ipconfig` en Windows) y el mismo puerto. Si arrancas el relay con `--token`,
escríbelo también en Ajustes.

> **Ojo:** el relay sólo funciona mientras tu PC esté encendido, y ambos
> dispositivos tienen que estar en la misma red. Si quieres que esté disponible
> 24/7 tendrías que alojarlo en un servidor (por ejemplo una máquina virtual
> gratuita). Por eso **el modo directo es el recomendado** y el relay es el
> plan B.

---

## Problemas frecuentes

| Síntoma | Causa y solución |
|---|---|
| «Certificado TLS no valido: iOS 9 no confia en la CA moderna» | Falta el paso **B.2**. Instala ISRG Root X1 y GTS Root R1/R4. |
| «YouTube pide iniciar sesion» | Aleatorio y por vídeo. Entra en **Ajustes → Iniciar sesion en YouTube**. |
| «YouTube ha rechazado la descarga (403)» | La URL del vídeo caducó o falta sesión. Pulsa **Reintentar**; si sigue, inicia sesión. |
| No aparece 720p ni 1080p | El chip es de 32 bits y no decodifica VP9/AV1. 360p es el techo real. |
| La app no se instala / «no está firmada» | Falta **AppSync Unified** (ver Parte C). |
| La app se ve con barras negras arriba y abajo | Faltan imágenes de arranque; se generan con `tools/generar_recursos.py` (el CI ya lo hace). |
| El modo relay da «No se puede conectar» | PC apagado, IP distinta, o el firewall de Windows bloquea Python. |
| La búsqueda no devuelve nada | Prueba **Ajustes → Probar conexion** para ver el error real. |

---

## Estructura del repositorio

```
.
├── .github/workflows/build-ipa.yml   Compilación y empaquetado en la nube
├── app/                              Proyecto Theos (Objective-C, armv7)
│   ├── Makefile                      TARGET iphone:clang:9.3:9.0, ARCHS armv7
│   ├── control                       Metadatos del paquete (nombre del .ipa)
│   ├── main.m                        Punto de entrada
│   ├── AppDelegate.{h,m}             Monta la interfaz (sin storyboards)
│   ├── YTTheme.{h,m}                 Paleta y estilos planos
│   ├── YTVideo.{h,m}                 Modelo de un resultado
│   ├── YTClient.{h,m}                InnerTube + relay + cookies + caché
│   ├── YTSearchViewController.{h,m}  Búsqueda y lista
│   ├── YTVideoCell.{h,m}             Tarjeta de resultado
│   ├── YTPlayerViewController.{h,m}  Reproductor AVPlayer
│   ├── YTSettingsViewController.{h,m} Ajustes y diagnóstico
│   ├── YTLoginViewController.{h,m}   Inicio de sesión (UIWebView)
│   └── Resources/                    Info.plist, iconos, imágenes de arranque
├── relay/relay.py                    Relay opcional (Python 3, sin dependencias)
└── tools/generar_recursos.py         Genera iconos y arranques (PNG a mano)
```

---

## Compilar en tu propio ordenador (opcional)

No es necesario: GitHub Actions ya lo hace. Pero si quieres reproducirlo en
Linux (o en Windows con WSL, que **no** existe en Windows 7), Theos necesita:

* Ubuntu 22.04 con `build-essential fakeroot rsync curl perl zip git libtinfo5`
* El *toolchain* `L1ghtmann/llvm-project` → `test-210562a` → `iOSToolchain-x86_64.tar.xz`,
  descomprimido en `$THEOS/toolchain/` (queda `$THEOS/toolchain/linux/iphone/bin/clang`)
* El SDK `iPhoneOS9.3.sdk` del repositorio `theos/sdks`

```bash
export THEOS=/opt/theos
cd app
make package FINALPACKAGE=1 PACKAGE_FORMAT=ipa
# → app/packages/com.lofturb.tube9_1.0.0_iphoneos-arm.ipa
```

---

## Créditos y licencia

* Hecho con [Theos](https://github.com/theos/theos) y el
  [toolchain de L1ghtmann](https://github.com/L1ghtmann/llvm-project).
* El enfoque de extracción está inspirado en
  [NewPipe](https://github.com/TeamNewPipe/NewPipeExtractor) (que descifra la
  firma con Rhino) y en [yt-dlp](https://github.com/yt-dlp/yt-dlp) (que lo hace
  con Node).
* Uso educativo y personal. Respeta las condiciones de servicio de YouTube y los
  derechos de autor del contenido que veas.
