// Copyright 2021 Eurac Research. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"context"
	"fmt"
	"log"

	influxdb2 "github.com/influxdata/influxdb-client-go/v2"
)

const q = `
from(bucket:"lter_dqc")
	|>range(start: 0)
	|>filter(fn: (r) => 
		r._measurement == "yellow_std" and 
		r._field == "yellow_std" and
		r.snipeit_location_ref == "34"
	)
	|>last()
`

func main() {
	client := influxdb2.NewClient("http://localhost:8086", "")
	queryAPI := client.QueryAPI("")

	result, err := queryAPI.Query(context.Background(), q)
	if err != nil {
		log.Fatal(err)
	}

	for result.Next() {
		r := result.Record()
		fmt.Printf("%s -- %s -- %s\n", r.Field(), r.Value(), r.Time())
	}

	if result.Err() != nil {
		log.Fatal(err)
	}

	client.Close()
}
