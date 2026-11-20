// Small web server for the lab. It has no client library: the text
// exposition format is written by hand, so the code stays short.
//
// Good metrics:
//
//	http_requests_total{path,method,code}
//	http_request_duration_seconds{path}  (histogram)
//
// Bad metric (runtime flag user_id): the same histogram is written with
// the extra label user_id instead of the old series. A user_id series is shown only while it is active
// (USER_SERIES_TTL), like a short-lived pod or session label.
package main

import (
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

var buckets = []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1}

var paths = []string{"/api/items", "/api/orders", "/api/search", "/api/cart"}

type hist struct {
	counts [9]uint64 // per bucket, not cumulative; last one is +Inf
	sum    float64
	last   time.Time
}

func (h *hist) observe(v float64, now time.Time) {
	i := sort.SearchFloat64s(buckets, v)
	h.counts[i]++
	h.sum += v
	h.last = now
}

type reqKey struct {
	path, method string
	code         int
}

type userKey struct{ path, user string }

type server struct {
	mu       sync.Mutex
	requests map[reqKey]uint64
	good     map[string]*hist
	users    map[userKey]*hist
	userFlag atomic.Bool
	ttl      time.Duration
}

func (s *server) handle(w http.ResponseWriter, r *http.Request) {
	// Fake work: 1 ms to ~200 ms, long tail.
	d := time.Duration(rand.ExpFloat64()*20) * time.Millisecond
	if d > 900*time.Millisecond {
		d = 900 * time.Millisecond
	}
	time.Sleep(d)
	code := 200
	switch x := rand.Intn(100); {
	case x < 1:
		code = 500
	case x < 5:
		code = 404
	}
	now := time.Now()
	path := r.URL.Path
	sec := d.Seconds()

	s.mu.Lock()
	s.requests[reqKey{path, r.Method, code}]++
	if s.userFlag.Load() {
		// The new code path: the histogram has the label user_id and
		// the old series (path only) is not written any more.
		u := r.Header.Get("X-User-Id")
		if u == "" {
			u = "anonymous"
		}
		k := userKey{path, u}
		uh := s.users[k]
		if uh == nil {
			uh = &hist{}
			s.users[k] = uh
		}
		uh.observe(sec, now)
	} else {
		h := s.good[path]
		if h == nil {
			h = &hist{}
			s.good[path] = h
		}
		h.observe(sec, now)
	}
	s.mu.Unlock()
	w.WriteHeader(code)
	fmt.Fprintf(w, "ok\n")
}

func writeHist(b *strings.Builder, name, labels string, h *hist) {
	var cum uint64
	for i, le := range buckets {
		cum += h.counts[i]
		fmt.Fprintf(b, "%s_bucket{%sle=\"%s\"} %d\n", name, labels, strconv.FormatFloat(le, 'g', -1, 64), cum)
	}
	cum += h.counts[len(buckets)]
	fmt.Fprintf(b, "%s_bucket{%sle=\"+Inf\"} %d\n", name, labels, cum)
	fmt.Fprintf(b, "%s_sum{%s} %g\n", name, strings.TrimSuffix(labels, ","), h.sum)
	fmt.Fprintf(b, "%s_count{%s} %d\n", name, strings.TrimSuffix(labels, ","), cum)
}

func (s *server) metrics(w http.ResponseWriter, _ *http.Request) {
	const hn = "http_request_duration_seconds"
	var b strings.Builder
	now := time.Now()
	s.mu.Lock()
	b.WriteString("# TYPE http_requests_total counter\n")
	for k, v := range s.requests {
		fmt.Fprintf(&b, "http_requests_total{path=%q,method=%q,code=\"%d\"} %d\n", k.path, k.method, k.code, v)
	}
	b.WriteString("# TYPE " + hn + " histogram\n")
	if !s.userFlag.Load() {
		for p, h := range s.good {
			writeHist(&b, hn, fmt.Sprintf("path=%q,", p), h)
		}
	}
	if s.userFlag.Load() {
		for k, h := range s.users {
			if now.Sub(h.last) > s.ttl {
				delete(s.users, k)
				continue
			}
			writeHist(&b, hn, fmt.Sprintf("path=%q,user_id=%q,", k.path, k.user), h)
		}
	} else {
		// Flag is off: forget old series so memory stays small.
		clear(s.users)
	}
	s.mu.Unlock()
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")
	fmt.Fprint(w, b.String())
}

func (s *server) flags(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodPost {
		switch r.URL.Query().Get("user_id") {
		case "on":
			s.userFlag.Store(true)
		case "off":
			s.userFlag.Store(false)
		default:
			http.Error(w, "use POST /flags?user_id=on|off", http.StatusBadRequest)
			return
		}
	}
	fmt.Fprintf(w, "{\"user_id\":%t}\n", s.userFlag.Load())
}

func main() {
	ttl, _ := time.ParseDuration(os.Getenv("USER_SERIES_TTL"))
	if ttl == 0 {
		ttl = 3 * time.Second
	}
	s := &server{
		requests: map[reqKey]uint64{},
		good:     map[string]*hist{},
		users:    map[userKey]*hist{},
		ttl:      ttl,
	}
	s.userFlag.Store(os.Getenv("FLAG_USER_ID") == "on")
	mux := http.NewServeMux()
	for _, p := range paths {
		mux.HandleFunc(p, s.handle)
	}
	mux.HandleFunc("/metrics", s.metrics)
	mux.HandleFunc("/flags", s.flags)
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { fmt.Fprintln(w, "ok") })
	log.Fatal(http.ListenAndServe(":8080", mux))
}
