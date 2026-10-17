Cliente de YouTube ligero y moderno para **iOS 9.3.5 de 32 bits (armv7)**:
iPhone 4S, iPhone 5 y 5C, iPad 2, 3 y 4, iPad mini 1 y iPod touch 5G.

## Qué trae esta versión

* **Reproductor propio**, con los mandos encima del vídeo: botón grande de
  reproducir y pausar, ±10 segundos, barra de progreso y cinco iconos
  (velocidad, bucle, descargar, compartir y pantalla completa). Debajo, la
  información que enseña la aplicación oficial: canal, visitas, duración y
  descripción, con un botón **Ver canal**.
* **Canales**: portada, avatar, nombre, suscriptores, *Suscribirse*,
  *Compartir* y las pestañas *Vídeos*, *Listas* e *Información*.
* **Listas de reproducción**, cada una con su pantalla y el botón
  *Reproducir todo*.
* **Buscador con tres filtros**: Vídeos, Canales y Listas.
* **Temas**: dos fondos (oscuro y claro) por siete colores de botones,
  catorce combinaciones.
* **Descargas** en MP4 360p a la carpeta que elijas, sin el fallo de «0 KB».
* **Iconos de la barra de pestañas arreglados**: antes salían invisibles.

## Cómo instalarlo

1. El dispositivo necesita **jailbreak** y **AppSync Unified** (se instala
   desde Cydia).
2. Copia el `.ipa` adjunto al dispositivo y tócalo desde **Filza** (o usa
   `ipainstaller Tube9.ipa` por SSH).
3. Instala el perfil **`certificados/CertificadosModernos.mobileconfig`** del
   repositorio, abriéndolo desde Safari con la dirección del PC en la red
   local: iOS 9.3.5 no conoce las autoridades de certificación modernas y, sin
   ese paso, no hay conexión con YouTube.

El paso a paso completo, la guía de certificados y los problemas frecuentes
están en el [README](https://github.com/lofturb/tube9#readme).

## Comprobar la descarga (opcional)

```powershell
python tools\verificar_ipa.py entrega\Tube9.ipa
```

Debe contestar `armv7`, `minimo 9.0` y `pseudo-firmado`.

---

> Tube9 no es una aplicación oficial de YouTube ni está afiliada a Google.
> Accede al contenido por los mismos servicios web que usa la web de YouTube,
> así que siguen aplicándose las
> [Condiciones de Servicio de YouTube](https://www.youtube.com/t/terms).
> Proyecto educativo y de uso personal.
