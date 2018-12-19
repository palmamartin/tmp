// Copyright 2017 Eurac Research. All rights reserved.
// Use of this source code is governed by the Apache 2.0
// licence that can be found in the LICENSE file.
package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"

	git "gopkg.in/src-d/go-git.v4"
	"gopkg.in/src-d/go-git.v4/plumbing"
	httpgit "gopkg.in/src-d/go-git.v4/plumbing/transport/http"
)

func main() {
	var (
		listenAddr = flag.String("http", "localhost:8080", "HTTP listen address")
		repoURL    = flag.String("repoURL", "", "HTTP(s) URL to the Gitlab repository")
		branch     = flag.String("branch", "master", "Git branch to clone")
		token      = flag.String("token", "", "Gitlab private access token")
		secret     = flag.String("secret", "", "Gitlab webhook secret")
		workDir    = flag.String("dir", ".", "Work `directory`")
	)
	flag.Parse()

	if *repoURL == "" {
		flag.Usage()
		log.Fatal("repoURL cannot not be empty.")
	}

	if *token == "" {
		flag.Usage()
		log.Fatal("token cannot not be empty.")
	}

	auth := httpgit.NewBasicAuth("gitlab", *token)
	ref := plumbing.ReferenceName(fmt.Sprintf("refs/heads/%s", *branch))

	repo, err := git.PlainClone(*workDir, false, &git.CloneOptions{
		URL:           *repoURL,
		Auth:          auth,
		ReferenceName: ref,
		SingleBranch:  true,
	})
	if err != nil {
		// Try if we can open the repository in case in already exsits
		repo, err = git.PlainOpen(*path)
		if err != nil {
			log.Fatal(err)
		}
	}

	http.HandleFunc("/pull", handler(repo, auth, ref, *secret))

	log.Printf("Running on %s ...", *listenAddr)
	log.Fatal(http.ListenAndServe(*listenAddr, nil))
}

func handler(repo *git.Repository, auth *httpgit.BasicAuth, ref plumbing.ReferenceName, secret string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {

		if secret != r.Header.Get("X-Gitlab-Token") {
			log.Println("Err: Fail to check the gitlab webhook token")
			w.WriteHeader(http.StatusUnauthorized)
			return
		}

		log.Println("info: got request for updating repository data")

		// Get the working directory for the repository
		tree, err := repo.Worktree()
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		// Pull the latest changes from the origin remote and merge into the current branch
		err = tree.Pull(&git.PullOptions{
			RemoteName:    "origin",
			Auth:          auth,
			ReferenceName: ref,
			SingleBranch:  true,
		})
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusOK)
	}
}
