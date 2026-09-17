#!/usr/bin/env python3
"""set_ip.py - add or replace an IP/network in a test MMDB database.

Python wrapper around the mmdbtool binary (bin/mmdbtool), which uses the
official MaxMind writer library (mmdbwriter, Go) to write the database.

Usage:
    python3 set_ip.py <file.mmdb> <ip_or_network> <country_iso> [--city NAME]

Examples:
    # create the db (if missing) and add 8.8.8.8 as BR
    python3 set_ip.py db/GeoLite2-City.mmdb 8.8.8.8 BR

    # replace: adding the same network again overwrites the data
    python3 set_ip.py db/GeoLite2-City.mmdb 8.8.8.8 US --city "New City"

    # add a whole network
    python3 set_ip.py db/GeoLite2-City.mmdb 10.0.0.0/24 BR

    # query what is stored for an IP
    python3 set_ip.py db/GeoLite2-City.mmdb --get 8.8.8.8

All other fields (default city, location, etc.) are fixed, except --city.
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
    parser.add_argument("mmdb", help="path to the .mmdb file")
    parser.add_argument("network", nargs="?",
                        help="IP or network (e.g. 8.8.8.8 or 10.0.0.0/24)")
    parser.add_argument("country", nargs="?",
                        help="country ISO code (e.g. BR, US)")
    parser.add_argument("--city", default=None,
                        help="city name (default: 'Test City')")
    parser.add_argument("--get", metavar="IP",
                        help="only query the IP in the db, without writing")
    args = parser.parse_args()

    if not os.path.exists(MMDBTOOL):
        print(f"mmdbtool not found at {MMDBTOOL}", file=sys.stderr)
        print("build it with: make build-tool", file=sys.stderr)
        return 1

    if args.get:
        cmd = [MMDBTOOL, "get", args.mmdb, args.get]
    else:
        if not args.network or not args.country:
            parser.error("network and country are required (or use --get)")
        country = args.country.upper()
        if len(country) != 2:
            parser.error("country must be a 2-letter ISO code (e.g. BR)")
        cmd = [MMDBTOOL, "set", args.mmdb, args.network, country]
        if args.city:
            cmd.append(args.city)

    result = subprocess.run(cmd, check=False)
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
