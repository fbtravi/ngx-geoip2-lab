#!/usr/bin/env python3
"""set_ip.py - cadastra ou substitui um IP/rede em uma base MMDB de teste.

Wrapper Python para o binario mmdbtool (bin/mmdbtool), que usa a lib
oficial da MaxMind (mmdbwriter, Go) para escrever a base.

Uso:
    python3 set_ip.py <arquivo.mmdb> <ip_ou_rede> <country_iso> [--city NOME]

Exemplos:
    # cria a base (se nao existir) e cadastra o IP 8.8.8.8 como BR
    python3 set_ip.py db/GeoLite2-City.mmdb 8.8.8.8 BR

    # substitui: mesma rede cadastrada de novo sobrescreve os dados
    python3 set_ip.py db/GeoLite2-City.mmdb 8.8.8.8 US --city "Cidade Nova"

    # cadastra uma rede inteira
    python3 set_ip.py db/GeoLite2-City.mmdb 10.0.0.0/24 BR

    # consulta o que esta cadastrado para um IP
    python3 set_ip.py db/GeoLite2-City.mmdb --get 8.8.8.8

Os demais campos (cidade default, localizacao etc.) sao fixos, salvo --city.
"""

import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MMDBTOOL = os.path.join(HERE, "bin", "mmdbtool")


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("mmdb", help="caminho do arquivo .mmdb")
    parser.add_argument("network", nargs="?",
                        help="IP ou rede (ex.: 8.8.8.8 ou 10.0.0.0/24)")
    parser.add_argument("country", nargs="?",
                        help="codigo ISO do pais (ex.: BR, US)")
    parser.add_argument("--city", default=None,
                        help="nome da cidade (default: 'Cidade Teste')")
    parser.add_argument("--get", metavar="IP",
                        help="apenas consulta o IP na base, sem gravar")
    args = parser.parse_args()

    if not os.path.exists(MMDBTOOL):
        print(f"mmdbtool nao encontrado em {MMDBTOOL}", file=sys.stderr)
        print("compile com: cd mmdbtool && go build -o ../bin/mmdbtool .",
              file=sys.stderr)
        return 1

    if args.get:
        cmd = [MMDBTOOL, "get", args.mmdb, args.get]
    else:
        if not args.network or not args.country:
            parser.error("network e country sao obrigatorios (ou use --get)")
        country = args.country.upper()
        if len(country) != 2:
            parser.error("country deve ser um codigo ISO de 2 letras (ex.: BR)")
        cmd = [MMDBTOOL, "set", args.mmdb, args.network, country]
        if args.city:
            cmd.append(args.city)

    result = subprocess.run(cmd, check=False)
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
