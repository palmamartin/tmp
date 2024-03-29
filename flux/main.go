// Copyright 2021 Eurac Research. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"context"
	"flag"
	"fmt"
	"log"

	influxdb2 "github.com/influxdata/influxdb-client-go/v2"
	"github.com/influxdata/influxdb-client-go/v2/domain"
)

var DefaultTimeFormat domain.DialectDateTimeFormat = "2006-01-02 15:04:05"

func main() {
	var (
		url   = flag.String("u", "", "InfluxDB server url")
		token = flag.String("t", "", "Authentication token. For InfluxDB 1.8 use username:password")
	)
	flag.Parse()

	client := influxdb2.NewClient(*url, *token)
	defer client.Close()
	queryAPI := client.QueryAPI("")

	const flux = `
t1 = from(bucket:"lter_new")
	|>range(start: 2022-04-03T23:00:00Z, stop: 2022-04-04T02:00:00Z)
	|>filter(fn: (r) => 
		r._measurement == "air_t_avg" and
		r._field == "air_t_avg" and
		r.snipeit_location_ref == "34" 
	)
	|> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
	|> drop(columns: ["_start", "_stop", "_measurement", "aggr", "landuse", "snipeit_location_ref", "unit"])
	|> group(columns: ["_measurement"])
	|> sort(columns: ["_time"])

t2 = from(bucket:"lter_new")
	|>range(start: 2022-04-03T23:00:00Z, stop: 2022-04-04T02:00:00Z)
	|>filter(fn: (r) => 
		r._measurement == "air_t_avg" and
		r._field == "air_t_avg" and
		r.snipeit_location_ref == "4" 
	)
	|> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
	|> drop(columns: ["_start", "_stop", "_measurement", "aggr", "landuse", "snipeit_location_ref", "unit"])
	|> group(columns: ["_measurement"])
	|> sort(columns: ["_time"])

join(tables: {air_t_avg: t1, wind_dir: t2}, on: ["_time"])
	`

	d := influxdb2.DefaultDialect()
	//d.DateTimeFormat = &DefaultTimeFormat

	// dt := &domain.Dialect{
	// 	DateTimeFormat: &DefaultTimeFormat,
	// }

	result, err := queryAPI.QueryRaw(context.Background(), flux, d)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(result)

	// for result.Next() {
	// 	r := result.Record()
	// 	fmt.Printf("%s -- %s -- %s\n", r.Field(), r.Value(), r.Time())
	// }

	// if result.Err() != nil {
	// 	log.Fatal(err)
	// }

}
