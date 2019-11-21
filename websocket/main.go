// Copyright 2019 Eurac Research. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"golang.org/x/net/websocket"
)

func main() {
	s := NewServer()

	log.Fatal(http.ListenAndServe("localhost:8080", s))
}

type Server struct {
	mux *http.ServeMux

	send chan []byte
}

func NewServer() *Server {
	s := new(Server)
	s.send = make(chan []byte)

	s.mux = http.NewServeMux()
	s.mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "index.html")
	})
	s.mux.HandleFunc("/hello", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "hello.html")
	})

	s.mux.Handle("/ws/register", websocket.Handler(s.socket))

	return s
}

type Message struct {
	Method string
	Body   string
}

func (s *Server) socket(ws *websocket.Conn) {
	cid := time.Now().Unix()
	log.Printf("Handling Websocket connection: %d\n", cid)

	in, out := make(chan *Message), make(chan *Message)
	errc := make(chan error, 1)

	// Decode messages from client and send to the in channel
	go func() {
		log.Printf("Go routing for incomming messages: %d\n", cid)
		dec := json.NewDecoder(ws)
		for {
			var m Message
			if err := dec.Decode(&m); err != nil {
				errc <- err
				return
			}

			in <- &m
		}
	}()

	// Recieve messages from the out channel and encode to the client
	go func() {
		log.Printf("Go routing for outgoing messages: %d\n", cid)
		enc := json.NewEncoder(ws)
		for m := range out {
			if err := enc.Encode(m); err != nil {
				errc <- err
				return
			}
		}
	}()
	defer close(out)

	for {
		select {
		case m := <-in:
			switch m.Method {
			case "helo":
				StartProcess(cid, out)
			case "action":
				log.Println("action method")
			default:
				log.Printf("incomming message for %d: %#q\n", cid, m)
			}

		case err := <-errc:
			log.Printf("error for %d: %v\n", cid, err)
			return
		}
	}
}

func StartProcess(id int64, out chan *Message) {
	log.Printf("Start Proccessing: %d\n", id)
	for {
		out <- &Message{
			Body: fmt.Sprintf("Hello From %d", id),
		}

		time.Sleep(time.Second * 1)
	}
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	s.mux.ServeHTTP(w, r)
}
