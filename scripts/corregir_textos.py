"""Corrige textos conocidos sin recalcular ni modificar geometrías."""

import csv
import hashlib
import json
import pathlib
import pickle
import re
import shutil
import sqlite3


REEMPLAZOS = {
    "cC3digo": "código",
    "lC-mite": "límite",
    "Sin direcciones seleccionadas con cC3digo postal":
        "Sin direcciones seleccionadas con código postal",
    "Fuera del lC-mite provincial": "Fuera del límite provincial",
}


def corregir(texto, escapes=False):
    for original, nuevo in REEMPLAZOS.items():
        texto = texto.replace(original, nuevo)
    if escapes:
        texto = re.sub(r"<U\+([0-9A-Fa-f]{4,8})>",
                       lambda m: chr(int(m[1], 16)), texto)
    return texto


def identificador(nombre):
    return '"' + nombre.replace('"', '""') + '"'


def firma(conexion, tabla, normalizar=False):
    digest = hashlib.sha256()
    for fila in conexion.execute("SELECT * FROM " + identificador(tabla) +
                                 " ORDER BY rowid"):
        if normalizar:
            fila = tuple(corregir(v) if isinstance(v, str) else v for v in fila)
        digest.update(pickle.dumps(fila, protocol=4))
    return digest.hexdigest()


def main():
    workspace = pathlib.Path.cwd().resolve()
    lote = pathlib.Path("data/cartociudad/reejecucion_actual.txt").read_text(
        encoding="utf-8-sig").strip()
    lote = pathlib.Path(lote).resolve()
    assert (lote / "PUBLICADO.txt").exists(), "El lote aún no está publicado"
    destino = lote / "correccion_textos"
    assert not (destino / "auditoria.json").exists(), "La corrección ya terminó"
    destino.mkdir(exist_ok=True)
    auditoria = []
    for copia in (destino / "respaldo").rglob("*"):
        if copia.is_file() and copia.suffix in (".csv", ".log"):
            ruta = workspace / copia.relative_to(destino / "respaldo")
            if ruta.read_bytes() != copia.read_bytes():
                auditoria.append({"archivo": str(ruta), "tipo": "texto"})

    def respaldar(ruta):
        relativo = ruta.resolve().relative_to(workspace)
        copia = destino / "respaldo" / relativo
        copia.parent.mkdir(parents=True, exist_ok=True)
        if not copia.exists():
            shutil.copy2(ruta, copia)

    textos = list(pathlib.Path("data/full_analisis").glob("*.csv"))
    textos += list((lote / "analisis").glob("*.csv"))
    textos += list((lote / "logs").glob("*.log"))
    for ruta in textos:
        original = ruta.read_bytes()
        nuevo = corregir(original.decode("utf-8-sig"), ruta.suffix == ".log")
        if nuevo == original.decode("utf-8-sig"):
            continue
        respaldar(ruta)
        ruta.write_bytes(nuevo.encode("utf-8"))
        auditoria.append({"archivo": str(ruta), "tipo": "texto"})

    geopackages = []
    for carpeta in [pathlib.Path("data/provs"), lote / "provs"]:
        geopackages += [p for p in carpeta.glob("CP_*.gpkg")
                        if re.fullmatch(r"CP_\d{2}\.gpkg", p.name)]
    geopackages += [pathlib.Path("data/codigos_postales.gpkg"),
                    lote / "consolidado/codigos_postales.gpkg"]
    for ruta in geopackages:
        with sqlite3.connect(ruta.resolve().as_uri() + "?mode=ro", uri=True) as con:
            tablas = [r[0] for r in con.execute(
                "SELECT table_name FROM gpkg_contents")]
            cambios = []
            for tabla in tablas:
                columnas = [r[1] for r in con.execute(
                    "PRAGMA table_info(" + identificador(tabla) + ")")
                    if "TEXT" in r[2].upper()]
                for columna in columnas:
                    for (valor,) in con.execute("SELECT DISTINCT " +
                            identificador(columna) + " FROM " + identificador(tabla)):
                        if isinstance(valor, str) and corregir(valor) != valor:
                            cambios.append((tabla, columna, valor, corregir(valor)))
            if not cambios:
                continue
            esperadas = {t: firma(con, t, True) for t in tablas}
        respaldar(ruta)
        with sqlite3.connect(ruta) as con:
            # Los triggers espaciales requieren GDAL incluso al editar texto.
            # Se restauran en la misma transacción y se verifica cada fila.
            triggers = con.execute(
                "SELECT name, sql FROM sqlite_master WHERE type='trigger'"
            ).fetchall()
            con.execute("BEGIN")
            for nombre, _ in triggers:
                con.execute("DROP TRIGGER " + identificador(nombre))
            for tabla, columna, original, nuevo in cambios:
                con.execute("UPDATE " + identificador(tabla) + " SET " +
                            identificador(columna) + "=? WHERE " +
                            identificador(columna) + "=?", (nuevo, original))
            for _, sql in triggers:
                con.execute(sql)
            assert {t: firma(con, t) for t in tablas} == esperadas, ruta
            assert con.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
        auditoria.append({"archivo": str(ruta), "tipo": "geopackage",
                          "geometrias_codigos_y_recuentos_intactos": True,
                          "cambios": cambios})

    estado_path = lote / "estado.csv"
    with estado_path.open(encoding="utf-8-sig", newline="") as f:
        lector = csv.DictReader(f)
        columnas = lector.fieldnames
        estados = list(lector)
    cambios_hash = []
    for fila in estados:
        ruta = lote / "provs" / ("CP_" + fila["cpro"] + ".gpkg")
        with ruta.open("rb") as f:
            nueva = hashlib.file_digest(f, "sha256").hexdigest()
        if nueva != fila["salida_sha256"]:
            cambios_hash.append({"cpro": fila["cpro"],
                                 "antes": fila["salida_sha256"], "despues": nueva})
            fila["salida_sha256"] = nueva
    for ruta in [estado_path, pathlib.Path("data/full_analisis/reejecucion_estado.csv")]:
        respaldar(ruta)
        with ruta.open("w", encoding="utf-8", newline="") as f:
            escritor = csv.DictWriter(f, fieldnames=columnas)
            escritor.writeheader()
            escritor.writerows(estados)
    (destino / "auditoria.json").write_text(json.dumps(
        {"archivos": auditoria, "huellas_actualizadas": cambios_hash},
        ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"archivos_corregidos": len(auditoria),
                      "geopackages": sum(x["tipo"] == "geopackage" for x in auditoria),
                      "huellas_actualizadas": len(cambios_hash)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
