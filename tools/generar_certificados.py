# -*- coding: utf-8 -*-
"""Genera un perfil .mobileconfig con las raices de certificacion modernas.

iOS 9.3.5 es de 2016 y no conoce las autoridades actuales, asi que cualquier
conexion HTTPS falla con "el certificado no es valido". Este script descarga
las raices publicas que hacen falta (las de YouTube/Google, Let's Encrypt y
DigiCert) y las empaqueta en UN SOLO perfil que se instala de una vez:

    python tools/generar_certificados.py

Resultado:
    certificados/CertificadosModernos.mobileconfig

El perfil usa el tipo de carga 'com.apple.security.root', que es el que hace
que iOS marque el certificado como raiz de confianza para SSL (no basta con
instalarlo como certificado normal).
"""

import os
import plistlib
import re
import sys
import urllib.request

RAICES = [
    ("isrgx1", "ISRG Root X1 (Let's Encrypt)",
     "https://letsencrypt.org/certs/isrgrootx1.pem"),
    ("isrgx2", "ISRG Root X2 (Let's Encrypt, ECDSA)",
     "https://letsencrypt.org/certs/isrg-root-x2.pem"),
    ("gtsr1", "GTS Root R1 (Google)",
     "https://pki.goog/repo/certs/gtsr1.pem"),
    ("gtsr4", "GTS Root R4 (Google, ECDSA)",
     "https://pki.goog/repo/certs/gtsr4.pem"),
    ("digicertg2", "DigiCert Global Root G2",
     "https://cacerts.digicert.com/DigiCertGlobalRootG2.crt.pem"),
]

# UUID fijos para que el perfil sea siempre identico (reproducible).
UUID_PERFIL = "7A1E4C10-0000-4B00-9E10-54B3901AB001"
UUID_CARGA = {
    "isrgx1": "7A1E4C10-0001-4B00-9E10-54B3901AB001",
    "isrgx2": "7A1E4C10-0002-4B00-9E10-54B3901AB002",
    "gtsr1": "7A1E4C10-0003-4B00-9E10-54B3901AB003",
    "gtsr4": "7A1E4C10-0004-4B00-9E10-54B3901AB004",
    "digicertg2": "7A1E4C10-0005-4B00-9E10-54B3901AB005",
}

DESTINO = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "certificados", "CertificadosModernos.mobileconfig")


def descargar(url):
    """Descarga un texto con un par de reintentos."""
    ultimo = None
    for intento in range(3):
        try:
            peticion = urllib.request.Request(
                url, headers={"User-Agent": "Mozilla/5.0 (generador Tube9)"})
            with urllib.request.urlopen(peticion, timeout=30) as respuesta:
                return respuesta.read().decode("utf-8", "replace")
        except Exception as error:            # noqa: BLE001
            ultimo = error
    raise RuntimeError("No se pudo descargar %s: %s" % (url, ultimo))


def der_desde_pem(texto, url):
    """Extrae el certificado DER (bytes) del cuerpo base64 de un PEM."""
    coincidencia = re.search(
        r"-----BEGIN CERTIFICATE-----(.+?)-----END CERTIFICATE-----",
        texto, re.S)
    if not coincidencia:
        raise RuntimeError("La respuesta de %s no es un PEM valido" % url)
    import base64
    return base64.b64decode(re.sub(r"\s+", "", coincidencia.group(1)))


def main():
    cargas = []
    for clave, nombre, url in RAICES:
        sys.stdout.write("Descargando %-28s ... " % nombre)
        sys.stdout.flush()
        pem = descargar(url)
        der = der_desde_pem(pem, url)
        print("%d bytes DER" % len(der))
        cargas.append({
            "PayloadCertificateFileName": "%s.cer" % clave,
            "PayloadContent": der,
            "PayloadDescription":
                "Raiz de confianza necesaria para que iOS 9 pueda validar HTTPS.",
            "PayloadDisplayName": nombre,
            "PayloadIdentifier": "com.lofturb.tube9.cert.%s" % clave,
            "PayloadType": "com.apple.security.root",
            "PayloadUUID": UUID_CARGA[clave],
            "PayloadVersion": 1,
        })

    perfil = {
        "PayloadContent": cargas,
        "PayloadDescription":
            "Instala las raices de certificacion modernas (Let's Encrypt, "
            "Google y DigiCert) que iOS 9.3.5 no incluye. Sin ellas, las "
            "conexiones HTTPS fallan aunque la red sea correcta.",
        "PayloadDisplayName": "Certificados modernos (Tube9)",
        "PayloadIdentifier": "com.lofturb.tube9.certificados",
        "PayloadOrganization": "Tube9",
        "PayloadRemovalDisallowed": False,
        "PayloadType": "Configuration",
        "PayloadUUID": UUID_PERFIL,
        "PayloadVersion": 1,
    }

    os.makedirs(os.path.dirname(DESTINO), exist_ok=True)
    with open(DESTINO, "wb") as fichero:
        plistlib.dump(perfil, fichero, fmt=plistlib.FMT_XML)

    # Comprobacion: volver a leerlo y contar las cargas
    with open(DESTINO, "rb") as fichero:
        releido = plistlib.load(fichero)
    print("\nEscrito: %s (%d bytes)" % (DESTINO, os.path.getsize(DESTINO)))
    print("Cargas de certificado: %d" % len(releido["PayloadContent"]))
    for carga in releido["PayloadContent"]:
        print("   - %-38s %d bytes DER  (%s)" % (
            carga["PayloadDisplayName"], len(carga["PayloadContent"]),
            carga["PayloadType"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
