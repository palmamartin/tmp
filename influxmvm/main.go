// Copyright 2020 Eurac Research. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// influxmvm renames InfluxDB measurements.
package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"strconv"
	"strings"

	_ "github.com/influxdata/influxdb1-client" // this is important because of the bug in go mod
	client "github.com/influxdata/influxdb1-client/v2"
)

func main() {
	var (
		influxAddr = flag.String("a", "http://localhost:8086", "Influx server.")
		influxUser = flag.String("u", "", "Influx username.")
		influxPass = flag.String("p", "", "Influx password.")
		influxDB   = flag.String("db", "", "Influx database.")
		delete     = flag.Bool("delete", false, "Delete old measurement.")
	)
	flag.Parse()

	c, err := client.NewHTTPClient(client.HTTPConfig{
		Addr:     *influxAddr,
		Username: *influxUser,
		Password: *influxPass,
	})

	in, err := ioutil.ReadAll(os.Stdin)
	if err != nil {
		log.Fatal(err)
	}

	for _, line := range strings.Split(string(in), "\n") {
		m := strings.Split(line, "\t")
		old := m[0]
		new := m[1]

		q := client.NewQuery(
			fmt.Sprintf("SELECT COUNT(*) FROM %q", old),
			*influxDB,
			"",
		)
		resp, err := query(c, q)
		if err != nil {
			log.Printf("ERROR: %v\n", err)
			continue
		}

		cPoints, err := count(resp)
		if err != nil {
			log.Printf("ERROR: %v\n", err)
			continue
		}

		q = client.NewQuery(
			fmt.Sprintf("SELECT * INTO %q FROM %q GROUP BY *", new, old),
			*influxDB,
			"",
		)
		resp, err = query(c, q)
		if err != nil {
			log.Printf("ERROR: %v\n", err)
			continue
		}

		nPoints, err := count(resp)
		if err != nil {
			log.Printf("ERROR: %v\n", err)
			continue
		}

		if cPoints != nPoints {
			log.Printf("ERROR: %q(%d) - %q(%d)\n", old, cPoints, new, nPoints)
			continue
		}

		if *delete {
			q = client.NewQuery(
				fmt.Sprintf("DROP MEASUREMENT %q", old),
				*influxDB,
				"",
			)
			_, err := query(c, q)
			if err != nil {
				log.Printf("ERROR: could not delete: %v\n", err)
			}
		}
	}
}

func query(c client.Client, q client.Query) (*client.Response, error) {
	resp, err := c.Query(q)
	if err != nil {
		log.Println(q.Command)
		return nil, err
	}
	if resp.Error() != nil {
		log.Println(q.Command)
		return nil, resp.Error()
	}

	return resp, nil
}

func count(r *client.Response) (int, error) {
	c := -1
	var err error

	for _, result := range r.Results {
		for _, serie := range result.Series {
			for _, value := range serie.Values {
				if len(value) != 2 {
					return -1, errors.New("nothing found")
				}
				c, err = strconv.Atoi(value[1].(json.Number).String())
				if err != nil {
					return -1, err
				}
			}

		}
	}

	return c, nil
}
