package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
)

var keep_long_ptr = flag.Int("k", 2, "Number of flags to show in full")
var shorten_to_ptr = flag.Int("s", 1, "Length of shortened path segments")

func main() {
	flag.Parse()
	keep_long := *keep_long_ptr
	shorten_to := *shorten_to_ptr

	if keep_long < 1 || shorten_to < 0 {
		log.Fatal("Argument values must be positive")
	}

	home, err := os.UserHomeDir()
	if err != nil {
		log.Fatal(err)
	}

	dir, err := os.Getwd()
	if err != nil {
		log.Fatal(err)
	}

	if strings.HasPrefix(dir, home) {
		dir = "~" + dir[len(home):]
	}

	segments := strings.Split(dir, "/")
	for i := 0; i < len(segments) - keep_long; i++ {
		seg := segments[i]

		if shorten_to < len(seg) {
			if strings.HasPrefix(seg, ".") && shorten_to < 2 {
				segments[i] = seg[0:2]
			} else {
				segments[i] = seg[0:shorten_to]
			}
		}

	}

	fmt.Print(strings.Join(segments, "/"))
}
