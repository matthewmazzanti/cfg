package main

import (
	"log"
	"os"
	"strconv"
	"strings"
)

const SHORTEN_TO = 1

func readColumns() int {
	if len(os.Args) < 2 {
		log.Fatal("Missing required parameter: columns")
	}

	columns, err := strconv.Atoi(os.Args[1])
	if err != nil {
		log.Fatal(err)
	}

	if columns < 0 {
		log.Fatal("columns must be postive")
	}

	return columns
}

func clamp(min, max, x int) int {
	if min > x {
		return min
	}

	if max < x {
		return max
	}

	return x
}

func keepLong(columns int) int {
	return clamp(1, 4, columns / 50 + 1)
}

func main() {
	columns := readColumns()
	keep_long := keepLong(columns)

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

		if SHORTEN_TO < len(seg) {
			if strings.HasPrefix(seg, ".") && SHORTEN_TO < 2 {
				segments[i] = seg[0:2]
			} else {
				segments[i] = seg[0:SHORTEN_TO]
			}
		}

	}

	print(strings.Join(segments, "/"))
}
