package main

import (
	"fmt"
	"log"
)

func main() {
	m, err := Get[MyType]()
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println(m)
	m.ID = 100
	fmt.Println(m)
}

type Validator interface {
	Validate() error
}

type Scanner interface {
	Scan() error
}

type ValidatorScanner[T any] interface {
	Validator
	Scanner
	*T
}

type MyType struct {
	ID   int64
	Name string
}

func (my *MyType) Scan() error {
	my.Name = "Martin"
	my.ID = 1
	return nil
}

func (my MyType) Validate() error {
	return nil
}

func Get[T any, PT ValidatorScanner[T]]() (T, error) {
	var t T

	p := PT(&t)
	if err := p.Scan(); err != nil {
		return t, err
	}

	if err := p.Validate(); err != nil {
		return t, err
	}

	return t, nil
}

func GetWithParameter[T Scanner](t T) error {
	if err := t.Scan(); err != nil {
		return err
	}
	return nil
}
