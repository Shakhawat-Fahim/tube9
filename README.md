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

> **Novedades de la última entrega.**
>
> * **Descargas arregladas.** Terminaban pesando «0 KB». La causa: antes de
>   descargar, la app comprueba que el enlace sirve pidiendo **2 bytes**
>   (`Range: bytes=0-1`); esa respuesta parcial de 2 bytes se quedaba en la
>   caché compartida y la descarga, al pedir **la misma URL**, recibía esa
>   respuesta en lugar del vídeo. Ahora la comprobación no se cachea, la
>   descarga usa una sesión sin caché, pide el fichero entero desde el byte 0 y,
>   además, **comprueba que lo guardado pesa lo que debe** (con un reintento
>   automático si se queda corta).
> * **Temas.** Dos fondos (oscuro y claro) y siete colores de botones:
>   **catorce combinaciones** en Ajustes → *Tema y color*.
> * **Miniaturas.** Se veían unas sí y otras no porque YouTube devuelve **9 de
>   cada 20 en formato WebP** y iOS 9 no sabe decodificarlo. Ahora se piden en
>   JPEG y, si una falla, se prueban otros tamaños del mismo vídeo.
> * **Música.** Decía «no hay nada que mostrar». El contenido de un estante es
>   una **lista** y se estaba leyendo como si fuera un objeto, así que no se veía
>   ni una canción. Ya salen ~130 canciones repartidas en siete estantes.
> * **Descargas nuevas**, con elección de carpeta (incluidas rutas de jailbreak y
>   comprobación real de permisos).
> * **Reproductor**: continuar donde lo dejaste, ±10 s con dos toques, volumen
>   arrastrando el dedo, velocidad, bucle, descargar, compartir, pantalla de
>   bloqueo y «Parecidos».
> * **Documentación del proceso**: [`docs/PROCESO.md`](docs/PROCESO.md) explica
>   con qué se compila el `.ipa`, paso a paso, y qué hacer si falla.

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
11. [Cómo se compila el `.ipa` (proceso completo)](docs/PROCESO.md)

---

## 1. Qué hace

| Pantalla | Qué ofrece |
|---|---|
| **Inicio** | Portada con **estantes deslizables**: **Continuar viendo** (lo que dejaste a medias), Tendencias de hoy, Música, Noticias, Deportes, Comedia y Para aprender. |
| **Música** | **YouTube Music de verdad**: Selecciones rápidas, Vídeos musicales nuevos, Novedades y estantes de Reggaetón, Baladas, Rock y Pop en español. |
| **Tendencias** | Lo más visto, con **chips** para cambiar de categoría (música, videojuegos, noticias, deportes, cine…). |
| **Buscar** | Campo de búsqueda, sugerencias en chips y lista de resultados con miniatura, título, canal, duración, visitas y fecha. |
| **Reproductor** | A pantalla completa, con **lo que se espera de un reproductor de YouTube**: reanuda donde lo dejaste, ±10 s con dos toques, volumen arrastrando el dedo, velocidad 0,5×–2×, bucle, descargar, compartir, mandos en la pantalla de bloqueo y una lista de **Parecidos** debajo. |
| **Descargas** | Guarda el vídeo en MP4 360p en **la carpeta que elijas** (también fuera de la app: `/var/mobile/Documents`, `/var/mobile/Media`…). Luego se reproduce en la app o se abre con otra. |
| **Ajustes** | Modo directo/relay, dirección del relay, inicio de sesión en YouTube, **tema y color**, **descargas y carpeta**, borrar «Continuar viendo», diagnóstico de conexión y guía de certificados. |

### El reproductor, en detalle

| Gesto o botón | Qué hace |
|---|---|
| Dos toques en la mitad izquierda | Retrocede 10 segundos |
| Dos toques en la mitad derecha | Avanza 10 segundos |
| Arrastrar el dedo arriba/abajo sobre el vídeo | Volumen (con el porcentaje en pantalla) |
| **−10 s** / **+10 s** | Lo mismo que los dos toques, para quien prefiera botones |
| **Velocidad** | 0,5× → 1× → 1,25× → 1,5× → 2× (el audio no suena acelerado) |
| **Bucle** | Repite el vídeo sin parar |
| **Descargar** | Baja el MP4 a la carpeta elegida; vuelve a tocarlo para cancelar |
| **Compartir** | Manda el enlace con cualquier app instalada |

Además: no se apaga la pantalla mientras se reproduce, el vídeo **sigue sonando
con la pantalla apagada** y en la pantalla de bloqueo aparecen el título, la
miniatura y los botones de ±10 s. Se puede **girar el móvil**: el reproductor
aprovecha todo el ancho.

Calidad de vídeo: **MP4/H.264 a 360p (itag 18, con audio incluido)**.
Es la máxima calidad reproducible en estos dispositivos: los chips de 32 bits
(A5/A6) **no pueden decodificar VP9 ni AV1** en hardware, así que no hay 720p.

Diseño: tema oscuro con los colores de YouTube, **miniaturas 16:9 a todo el
ancho** con la duración encima, estantes que se deslizan de lado, chips de
filtro, tipografía del sistema y **todos los iconos dibujados por código**
(vectoriales, sin ficheros de imagen). Cero degradados, cero desenfoques y cero
animaciones caras: todo eso funciona mal en un A5.

Para ver cómo queda **sin instalar nada**, abre `docs/vista-previa.html` en el
navegador del ordenador: es una maqueta a escala real (320 × 568 puntos) con los
mismos colores, tamaños, márgenes e iconos que lleva la app.

**Lo que YouTube no da sin cuenta.** La portada personalizada de YouTube
(`FEwhat_to_watch`) y el listado de tendencias (`FEtrending`) contestan vacío o
`400` a quien no tiene sesión. Como no se puede fingir lo que no hay:

* **Inicio** se arma con búsquedas temáticas ordenadas (por visitas o por fecha),
  que es lo que mejor se parece a la portada oficial.
* **Tendencias** pide la búsqueda **ordenada por número de visitas**, que es el
  equivalente medible de «lo más visto».
* **Música** sí es auténtico: son las pantallas de `music.youtube.com`
  (`FEmusic_home`, `FEmusic_explore`, `FEmusic_new_releases`) más búsquedas en su
  catálogo. `FEmusic_charts` **no se usa a propósito**: sus listas son de
  artistas y sus filas llevan a un canal, no a un vídeo (comprobado).
* Los **Parecidos** que salen bajo el reproductor son una búsqueda por el título
  del vídeo. YouTube tiene un listado oficial de relacionados (el endpoint
  `next`), pero su respuesta pesa **unos 7 MB por vídeo** (medido): es demasiado
  para la memoria de un iPhone de 32 bits, así que no se usa.

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
              │  youtubei/v1/{search,player} │        │  relay.py en tu PC │
              │  cliente ANDROID             │  ◄──►  │  (o un servidor)   │
              └──────────────────────────────┘        └────────────────────┘
```

* **InnerTube `ANDROID`.** De los clientes públicos que expone YouTube, es el
  único que hoy devuelve **URLs directas de MP4 muxado** sin obligar a descifrar
  la firma `nsig` (que es lo que hacen NewPipe con Rhino o `yt-dlp` con Node) y
  que además descarga los bytes siempre (medido: 12 de 12 vídeos). También es el
  que se usa para buscar y para la pantalla de **Música**, que va contra
  `music.youtube.com` con el cliente `WEB_REMIX` **sólo para navegar**.
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

### Comprobar el `.ipa` descargado (opcional)

```powershell
python tools\verificar_ipa.py entrega\Tube9.ipa
```

Te dice la arquitectura, la versión mínima de iOS y si va firmado. Debe poner
`armv7`, `minimo 9.0` y `pseudo-firmado`.

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
nuevas de Google. Se arregla instalando las raíces modernas, y **el repositorio
ya trae el perfil hecho**: `certificados/CertificadosModernos.mobileconfig`,
que instala de una sola vez

* **ISRG Root X1** y **ISRG Root X2** (Let's Encrypt)
* **GTS Root R1** y **GTS Root R4** (Google, las que usa YouTube)
* **DigiCert Global Root G2** (la que usa GitHub entre otros)

> **Aviso: el círculo vicioso.** El dispositivo **todavía no puede descargar
> nada por HTTPS**, da igual que sea desde GitHub o desde la web de Let's
> Encrypt. Así que el perfil hay que **pasarle el fichero desde el PC**, no
> intentar descargarlo con el propio dispositivo.

Dos formas de pasarlo, de más cómoda a más manual:

**1. Por la red local, sin cables ni correo (recomendada).** En el PC, dentro de
la carpeta del repositorio:

```powershell
cd certificados
python -m http.server 8000
```

Averigua la IP del PC con `ipconfig` (por ejemplo `192.168.1.50`) y abre en
**Safari del dispositivo**:

```
http://192.168.1.50:8000/CertificadosModernos.mobileconfig
```

Es HTTP plano dentro de tu propia red, así que funciona aunque el dispositivo no
confíe todavía en ningún certificado.

**2. Por correo.** Adjunta el `.mobileconfig` en un correo a ti mismo y ábrelo
desde la app Mail del dispositivo.

Después, en el dispositivo: **Ajustes → General → Perfil** (en iOS 9 aparece al
final de la lista) → *Instalar* → código de acceso si lo pide → *Instalar* otra
vez.

* En iOS 9 una raíz instalada así queda **de confianza para SSL
  automáticamente**: no hay que activar nada más.
* Si tu dispositivo fuera iOS 10.3 o superior, aparecería además
  *Ajustes → General → Información → Ajustes de confianza de certificados*;
  activa ahí el interruptor de cada certificado.

Con esto la app habla con YouTube directamente por HTTPS desde tu conexión de
casa (una IP residencial, que YouTube trata mucho mejor que las IP de centro de
datos).

*(El perfil se puede regenerar cuando quieras con
`python tools/generar_certificados.py`.)*

> ¿Prefieres no tocar certificados? Usa el **modo relay** (ver más abajo): la app
> habla por HTTP plano con un servidor tuyo y el problema de TLS desaparece.

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

### Tema y color

**Ajustes → Tema y color.** Hay **dos fondos** y **siete colores de botones**:
**catorce combinaciones** en total.

| Fondo | Cómo es |
|---|---|
| **Oscuro** | El de siempre (casi negro), para ver vídeos de noche. |
| **Claro** | Fondo blanco, para el sol de la calle. |

| Color de botones |
|---|
| Rojo (el de YouTube), Azul, Verde, Morado, Turquesa, Ámbar y Rosa |

El color de los botones se usa en los filtros de las listas, la pestaña elegida,
los interruptores y los botones de las ventanas. **No se aplica tal cual**: se le
ajusta el brillo para que se lea sobre el fondo elegido (el ámbar sobre blanco se
oscurece; el azul sobre negro se aclara) y el texto de dentro del botón se pone
blanco o negro según lo claro que quede. Al cambiarlo, la app se repinta sola.

### Descargas y carpeta de destino

**Ajustes → Descargas** (también hay un botón **Descargar** bajo el
reproductor). Los vídeos se guardan como **MP4 360p** con el título en el nombre
del fichero.

La carpeta se elige con un explorador propio. **En un iPhone con jailbreak la app
puede escribir fuera de su propia carpeta**, así que ahí están las direcciones
habituales con un acceso directo:

| Ruta | Cuándo tiene permiso |
|---|---|
| `Documentos de la app` | Siempre (es la que se usa por defecto). |
| `/var/mobile/Documents` | Casi siempre, con jailbreak. |
| `/var/mobile/Media` y `/var/mobile/Media/Downloads` | Habitual con jailbreak. |
| `/var/mobile` o `/` | Sólo si el jailbreak deja escribir ahí. |

En vez de dejar que la descarga falle más tarde y sin explicación, **cada carpeta
se prueba de verdad** (se escribe un fichero diminuto y se borra) y se marca con
un **visto** o con «sin permiso de escritura». Si la carpeta elegida deja de
valer, la app lo dice y usa la suya.

En la lista de descargas, cada vídeo se puede **reproducir en la app**, **abrir
con otra aplicación** (por ejemplo un reproductor que lo tenga todo) o **borrar**
(también deslizando). La descarga continúa mientras la app está abierta.

### Diagnóstico

**Ajustes → Probar conexión** recorre los tres pasos de los que depende la
reproducción, **con los tiempos de cada uno** para saber dónde está el atasco:

| Paso | Qué prueba | Si falla significa |
|---|---|---|
| **1** | Buscar en `youtube.com` | Red, DNS o certificados. |
| **2** | Pedir la URL del vídeo **probando los cuatro clientes** y comprobando que los dos primeros bytes se descarguen | Vídeo bloqueado o sesión: si sale `LOGIN_REQUIRED`, hay que iniciar sesión. Si sale «dio una URL que no se puede descargar (HTTP 403)», es el *po token*. |
| **3** | Descargar los primeros KB de `googlevideo.com` | **El proveedor de Internet** dando largas con el servidor de vídeo (es el paso que la app no puede esquivar sola), o el DNS. |

El informe dice también **con qué cliente** se resolvió el vídeo (`ANDROID_VR`,
`VISIONOS`…) y **cuánto tardó la comprobación**.

El paso 3 es el importante: la app puede fallar en la búsqueda y funcionar en el
vídeo, o al contrario. Si los pasos 1 y 2 van bien y el 3 falla o tarda
muchísimo, el problema no es la app sino la conexión a `googlevideo.com`, y ahí
el **modo relay** es la solución (el vídeo lo descarga el servidor y llega al
dispositivo por la red local).

Por eso también el reproductor ya no se queda mudo: mientras carga muestra los
segundos que lleva y el servidor implicado, y a los 30 segundos explica qué ha
pasado en vez de dejar un «Cargando…» infinito.

### El «inicia sesión para confirmar que no eres un robot»

YouTube no da los vídeos a cualquiera: si la petición no se parece a la de un
navegador o de una app de verdad, contesta `LOGIN_REQUIRED` («Inicia sesión para
confirmar que no eres un bot»). Es su control antibot, y aquí se ataca con las
mismas tres armas que usan los proyectos libres de referencia.

**Qué hacen los demás** (consultado en el código fuente, no de memoria):

| Proyecto | Qué hace |
|---|---|
| **NewPipe** (`YoutubeParsingHelper.java`) | Manda en cada petición las cabeceras `X-YouTube-Client-Name`, `X-YouTube-Client-Version`, `Origin` y `Referer`; pide un **`visitorData`** a `/youtubei/v1/visitor_id` y lo mete dentro de `context.client`; y elige entre varios clientes (ANDROID, IOS, WEB…). **No** implementa *po tokens*. |
| **yt-dlp** (`extractor/youtube/_base.py`) | Igual que NewPipe, y además manda el `visitorData` como cabecera `X-Goog-Visitor-Id`. Su tabla de clientes es la referencia mundial: cada cliente declara si necesita el reproductor JavaScript y si exige *po token*. |

**Los dos filtros que dejan a iOS 9 casi sin opciones.** En yt-dlp,
`REQUIRE_JS_PLAYER` vale **`True` por defecto**, y sólo cuatro clientes lo ponen
en `False`:

| Cliente | Reproductor JS | *Po token* según yt-dlp | **Medido en 12 vídeos reales** |
|---|---|---|---|
| `ANDROID` | no hace falta | obligatorio | **descarga los 12** ← es el que se usa |
| `ANDROID_VR` | no hace falta | obligatorio | 9 de 12 (`HTTP 403` en 3) |
| `IOS` | no hace falta | obligatorio | no devuelve ni un formato |
| `VISIONOS` | no hace falta | **no lo exige** | no devuelve ni un formato |
| `WEB`, `MWEB`, `TVHTML5`, `TVHTML5_SIMPLY`… | **sí hace falta** | — | descartados de entrada |

O sea: los clientes web y de televisión quedan fuera porque exigen ejecutar el
JavaScript del reproductor para descifrar la firma `nsig`, y en iOS 9 no hay
motor de JavaScript para eso.

Las dos últimas columnas enseñan algo importante: **la tabla de yt-dlp orienta,
pero la medición manda**. Sobre el papel el cliente sin *po token* era `VISIONOS`
y el que más problemas daba era `ANDROID`; en la práctica `ANDROID` descarga
todo y `VISIONOS` no devuelve nada. Por eso la app mide —pide los dos primeros
bytes de cada URL— en vez de fiarse del papel.

**Qué hace Tube9 con eso:**

1. **Pide un `visitorData`** una vez (`/youtubei/v1/visitor_id`), lo guarda entre
   arranques y lo manda en el contexto y en `X-Goog-Visitor-Id`.
2. **Manda las cabeceras de cliente** (`X-YouTube-Client-Name/Version`, `Origin`,
   `Referer`) y los datos de dispositivo (`deviceMake`, `deviceModel`, `osName`,
   `osVersion`) de cada cliente.
3. **Rota entre los cuatro clientes útiles**, empezando por `ANDROID` (el que
   descarga siempre) y siguiendo con `ANDROID_VR`, `IOS` y `VISIONOS`. Como cada
   uno tiene su propio umbral antibot, el que rechaza a uno suele dar el vídeo a
   otro.
4. **Comprueba la descarga antes de reproducir**: pide los dos primeros bytes de
   la URL. Esto es lo que hace útil la rotación, porque YouTube devuelve a veces
   una URL perfectamente válida que luego contesta `403` (es el caso del *po
   token*). Si el cliente elegido no sirve, la app pasa sola al siguiente, y el
   vídeo empieza **sólo cuando los bytes llegan de verdad**. El informe de
   diagnóstico dice **con qué cliente** se consiguió y **cómo fue la
   comprobación**.

Este detalle —comprobar los bytes— es el que resolvía el problema de raíz: antes
la app le entregaba al reproductor una URL que iba a dar `403`, y el reproductor
se quedaba en «Cargando…» para siempre sin decir por qué.

**Los *po tokens* y el modo relay.** YouTube exige a menudo un token extra
(`poToken`) para servir los bytes, y ese token **sólo** se puede fabricar
ejecutando el JavaScript de BotGuard de Google — con Node.js o con el motor de un
navegador completo. **iOS 9 no puede ejecutar ese JavaScript** y el dispositivo
no corre Node, así que la app no puede generarlos por sí misma. Hoy `ANDROID`
funciona sin ellos, y con la **sesión iniciada** YouTube además deja de hacer
preguntas de robot. Si algún día dejara de bastar, la salida es el **modo relay**
(abajo): el vídeo lo resuelve y lo descarga un servidor, donde sí se puede tener
Node y, por tanto, *po tokens*.

### Iniciar sesión

**Ajustes → Iniciar sesion en YouTube** abre un navegador integrado (`UIWebView`)
que comparte las *cookies* con las peticiones de la app: al terminar, la
búsqueda y los vídeos van autenticados y el control antibot desaparece.

Esa pantalla es **clara a propósito**, aunque el resto de la app sea oscura: la
página de Google no admite que le impongamos colores, y si su hoja de estilos no
llega a cargar (pasa cuando la conexión recorta `accounts.google.com`), el
navegador dibuja texto negro por defecto. Sobre el fondo oscuro de la app eso era
«todo negro con letras negras». Ahora el lienzo se pinta de blanco, así que se lee
cargue o no cargue el CSS.

Si Google insiste en que «el navegador no es seguro», usa **Ajustes → Pegar
cookies**: se copian las cookies de un navegador donde sí hayas entrado a
YouTube y la app las usa tal cual.

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
| «Certificado TLS no valido: iOS 9 no confia en la CA moderna» | Falta el paso **B.2**. Instala `certificados/CertificadosModernos.mobileconfig` una sola vez. |
| «YouTube pide iniciar sesion» | Aleatorio y por vídeo. Entra en **Ajustes → Iniciar sesion en YouTube**. |
| «YouTube ha rechazado la descarga (403)» | La URL del vídeo caducó o falta sesión. Pulsa **Reintentar**; si sigue, inicia sesión. |
| No aparece 720p ni 1080p | El chip es de 32 bits y no decodifica VP9/AV1. 360p es el techo real. |
| La app no se instala / «no está firmada» | Falta **AppSync Unified** (ver Parte C). |
| La app se ve con barras negras arriba y abajo | Faltan imágenes de arranque; se generan con `tools/generar_recursos.py` (el CI ya lo hace). |
| El modo relay da «No se puede conectar» | PC apagado, IP distinta, o el firewall de Windows bloquea Python. |
| La búsqueda no devuelve nada | Prueba **Ajustes → Probar conexion** para ver el error real. |
| Alguna miniatura se queda en gris | Ya no debería pasar (se piden en JPEG). Ese vídeo quizá no tenga miniatura: la app prueba `sddefault`, `hqdefault` y `mqdefault` antes de rendirse. |
| **Música** dice «no hay nada que mostrar» | Pulsa **recargar** (arriba a la derecha). Si sigue, YouTube Music ha cambiado el formato: la pestaña pasa sola a búsquedas de música como plan B. |
| «No se puede escribir en *carpeta*» al descargar | Esa carpeta no da permiso. En **Ajustes → Descargas → Carpeta** las que valen llevan un **visto**. |
| La descarga se corta al bloquear el móvil | Las descargas siguen **mientras la app está abierta**; deja la app en primer plano hasta que termine. |
| Una descarga acaba pesando **0 KB** | Ya no debería pasar (el fichero se verifica al guardarlo y se reintenta solo). Si vuelve a ocurrir, el mensaje ahora dice lo que pasó: cuánto llegó y cuánto se esperaba. |

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
│   ├── YTTheme.{h,m}                 Paleta, estilos planos e iconos vectoriales
│   ├── YTVideo.{h,m}                 Modelo de un resultado
│   ├── YTClient.{h,m}                InnerTube + relay + cookies + miniaturas
│   ├── YTProgreso.{h,m}              Por dónde ibas (estante «Continuar viendo»)
│   ├── YTDescargas.{h,m}             Descargas MP4, carpeta e historial
│   ├── YTFeedViewController.{h,m}    Estantes deslizables (Inicio y Música)
│   ├── YTCarruselCell.{h,m}          Fila de estante + tarjeta pequeña
│   ├── YTTendenciasViewController.{h,m}  Lo más visto, con chips
│   ├── YTSearchViewController.{h,m}  Búsqueda y lista
│   ├── YTVideoCell.{h,m}             Tarjeta de resultado
│   ├── YTPlayerViewController.{h,m}  Reproductor (gestos, velocidad, bloqueo)
│   ├── YTDescargasViewController.{h,m}  Lista de descargas
│   ├── YTCarpetaViewController.{h,m} Explorador para elegir la carpeta
│   ├── YTTemaViewController.{h,m}    Selector de tema (fondo y color)
│   ├── YTSettingsViewController.{h,m} Ajustes, descargas y diagnóstico
│   ├── YTLoginViewController.{h,m}   Inicio de sesión (UIWebView)
│   └── Resources/                    Info.plist, iconos, imágenes de arranque
├── certificados/
│   └── CertificadosModernos.mobileconfig   Perfil listo para las raíces nuevas
├── relay/relay.py                    Relay opcional (Python 3, sin dependencias)
├── docs/
│   ├── vista-previa.html             Maqueta de las pantallas (abrir en el navegador)
│   └── PROCESO.md                    Cómo se compila el .ipa, paso a paso
└── tools/
    ├── generar_recursos.py           Genera iconos y arranques (PNG a mano)
    ├── generar_certificados.py       Genera el perfil .mobileconfig
    └── verificar_ipa.py              Comprueba arquitectura y versión del .ipa
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

> El proceso completo (herramientas, los cuatro comandos de preparación, la
> trampa de `liblaunch.tbd`, los errores típicos y cómo montar otra app desde
> cero) está en **[`docs/PROCESO.md`](docs/PROCESO.md)**.

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
