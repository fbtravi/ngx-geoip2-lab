package main

// mmdbtool is a tiny CLI to create or update test MMDB databases.
//
// Usage:
//
//	mmdbtool set <file.mmdb> <network> <country> [city]
//	mmdbtool get <file.mmdb> <ip>
//
// If the file does not exist, a new GeoLite2-City database is created.
// If the network already exists, its data is overwritten.
// All other record fields are fixed, except country and city.
import (
	"encoding/json"
	"fmt"
	"net/netip"
	"os"

	"github.com/maxmind/mmdbwriter/v2"
	"github.com/maxmind/mmdbwriter/v2/mmdbtype"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}

	var err error
	switch os.Args[1] {
	case "set":
		err = cmdSet(os.Args[2:])
	case "get":
		err = cmdGet(os.Args[2:])
	default:
		usage()
		os.Exit(2)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, `usage:
  mmdbtool set <file.mmdb> <network> <country> [city]
  mmdbtool get <file.mmdb> <ip>`)
}

func buildRecord(country, city string) mmdbtype.Map {
	countryData := mmdbtype.Map{
		"iso_code":   mmdbtype.String(country),
		"geoname_id": mmdbtype.Uint32(3469034),
		"names": mmdbtype.Map{
			"en": mmdbtype.String(country),
		},
	}
	return mmdbtype.Map{
		"country":            countryData,
		"registered_country": countryData,
		"city": mmdbtype.Map{
			"geoname_id": mmdbtype.Uint32(3448439),
			"names": mmdbtype.Map{
				"en": mmdbtype.String(city),
			},
		},
		"continent": mmdbtype.Map{
			"code":       mmdbtype.String("SA"),
			"geoname_id": mmdbtype.Uint32(6255150),
			"names": mmdbtype.Map{
				"en": mmdbtype.String("South America"),
			},
		},
		"location": mmdbtype.Map{
			"latitude":        mmdbtype.Float64(-23.5505),
			"longitude":       mmdbtype.Float64(-46.6333),
			"time_zone":       mmdbtype.String("America/Sao_Paulo"),
			"accuracy_radius": mmdbtype.Uint16(50),
		},
	}
}

func cmdSet(args []string) error {
	if len(args) < 3 {
		usage()
		os.Exit(2)
	}
	path, networkStr, country := args[0], args[1], args[2]
	city := "Cidade Teste"
	if len(args) > 3 {
		city = args[3]
	}

	prefix, err := netip.ParsePrefix(networkStr)
	if err != nil {
		// plain IP -> single-host prefix
		addr, addrErr := netip.ParseAddr(networkStr)
		if addrErr != nil {
			return fmt.Errorf("invalid network %q: %w", networkStr, err)
		}
		prefix = netip.PrefixFrom(addr, addr.BitLen())
	}

	var tree *mmdbwriter.Tree
	if _, statErr := os.Stat(path); statErr == nil {
		tree, err = mmdbwriter.Load(path, mmdbwriter.Options{
			IncludeReservedNetworks: true,
		})
		if err != nil {
			return fmt.Errorf("loading %s: %w", path, err)
		}
	} else {
		tree, err = mmdbwriter.New(mmdbwriter.Options{
			DatabaseType:            "GeoLite2-City",
			IPVersion:               6,
			RecordSize:              28,
			IncludeReservedNetworks: true,
		})
		if err != nil {
			return err
		}
	}

	if err := tree.Insert(prefix, buildRecord(country, city)); err != nil {
		return fmt.Errorf("inserting %s: %w", prefix, err)
	}

	fh, err := os.Create(path)
	if err != nil {
		return err
	}
	defer fh.Close()

	if _, err := tree.WriteTo(fh); err != nil {
		return err
	}

	fmt.Printf("OK: %s -> country=%s city=%q in %s\n", prefix, country, city, path)
	return nil
}

func cmdGet(args []string) error {
	if len(args) < 2 {
		usage()
		os.Exit(2)
	}
	path, ipStr := args[0], args[1]

	addr, err := netip.ParseAddr(ipStr)
	if err != nil {
		return fmt.Errorf("invalid ip %q: %w", ipStr, err)
	}

	tree, err := mmdbwriter.Load(path, mmdbwriter.Options{
		IncludeReservedNetworks: true,
	})
	if err != nil {
		return err
	}

	_, value := tree.Get(addr)
	if value == nil {
		fmt.Printf("%s -> not found\n", addr)
		return nil
	}

	out, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return err
	}
	fmt.Printf("%s -> %s\n", addr, out)
	return nil
}
