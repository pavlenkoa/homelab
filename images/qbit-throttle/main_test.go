package main

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"
)

// fakeQbit mimics the handful of qBittorrent endpoints the controller uses.
type fakeQbit struct {
	mu        sync.Mutex
	alt       bool
	altDL     int
	altUP     int
	toggles   int
	prefPosts int
}

func (f *fakeQbit) handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/api/v2/transfer/speedLimitsMode", func(w http.ResponseWriter, _ *http.Request) {
		f.mu.Lock()
		defer f.mu.Unlock()
		if f.alt {
			w.Write([]byte("1"))
		} else {
			w.Write([]byte("0"))
		}
	})
	mux.HandleFunc("/api/v2/transfer/toggleSpeedLimitsMode", func(http.ResponseWriter, *http.Request) {
		f.mu.Lock()
		defer f.mu.Unlock()
		f.alt = !f.alt
		f.toggles++
	})
	mux.HandleFunc("/api/v2/app/preferences", func(w http.ResponseWriter, _ *http.Request) {
		f.mu.Lock()
		defer f.mu.Unlock()
		w.Write([]byte(`{"alt_dl_limit":` + strconv.Itoa(f.altDL) + `,"alt_up_limit":` + strconv.Itoa(f.altUP) + `,"scheduler_enabled":false}`))
	})
	mux.HandleFunc("/api/v2/app/setPreferences", func(w http.ResponseWriter, r *http.Request) {
		f.mu.Lock()
		defer f.mu.Unlock()
		r.ParseForm()
		body := r.Form.Get("json")
		if !strings.Contains(body, `"alt_dl_limit":2048`) || !strings.Contains(body, `"alt_up_limit":100`) {
			http.Error(w, "unexpected prefs "+body, http.StatusBadRequest)
			return
		}
		f.altDL, f.altUP = 2048, 100
		f.prefPosts++
	})
	return mux
}

func newTestController(t *testing.T, players *int, embyErr *error) (*controller, *fakeQbit) {
	t.Helper()
	fq := &fakeQbit{}
	srv := httptest.NewServer(fq.handler())
	t.Cleanup(srv.Close)
	cfg := config{downKiB: 2048, upKiB: 100, releaseDelay: 45 * time.Second, embyFailSafe: 2 * time.Minute, pollInterval: time.Second}
	c := &controller{
		cfg:  cfg,
		emby: func(context.Context) (int, error) { return *players, *embyErr },
		qb:   qbit{hc: srv.Client(), base: srv.URL},
	}
	return c, fq
}

func TestThrottleLifecycle(t *testing.T) {
	players := 0
	var embyErr error
	c, fq := newTestController(t, &players, &embyErr)
	ctx := context.Background()
	now := time.Now()

	c.tick(ctx, now)
	if fq.alt || fq.altDL != 2048 || fq.altUP != 100 {
		t.Fatalf("idle: alt=%v limits=%d/%d, want off with 2048/100 set", fq.alt, fq.altDL, fq.altUP)
	}

	players = 1
	c.tick(ctx, now.Add(2*time.Second))
	if !fq.alt {
		t.Fatal("playback started but limits not enabled")
	}

	players = 0
	c.tick(ctx, now.Add(10*time.Second)) // within release delay
	if !fq.alt {
		t.Fatal("limits released before the release delay elapsed")
	}
	c.tick(ctx, now.Add(60*time.Second)) // 58s after last playback
	if fq.alt {
		t.Fatal("limits still on after the release delay")
	}
	if fq.toggles != 2 || fq.prefPosts != 1 {
		t.Fatalf("toggles=%d prefPosts=%d, want 2 and 1 (no flapping, prefs written once)", fq.toggles, fq.prefPosts)
	}
}

func TestEmbyOutageFailsOpen(t *testing.T) {
	players := 1
	var embyErr error
	c, fq := newTestController(t, &players, &embyErr)
	ctx := context.Background()
	now := time.Now()

	c.tick(ctx, now)
	if !fq.alt {
		t.Fatal("expected throttled")
	}
	embyErr = errors.New("connection refused")
	c.tick(ctx, now.Add(30*time.Second))
	if !fq.alt {
		t.Fatal("short Emby blip must keep the current state")
	}
	c.tick(ctx, now.Add(3*time.Minute))
	if fq.alt {
		t.Fatal("limits must be released once Emby has been unreachable past the fail-safe")
	}
}

func TestRecoversFromQbitRestart(t *testing.T) {
	players := 1
	var embyErr error
	c, fq := newTestController(t, &players, &embyErr)
	ctx := context.Background()
	now := time.Now()

	c.tick(ctx, now)
	// Simulate qbit restarting: it forgets both the mode and the alt limits.
	fq.mu.Lock()
	fq.alt, fq.altDL, fq.altUP = false, 0, 0
	fq.mu.Unlock()
	c.prefsOK = false // what tick does after a failed read; also covered by the mode check below
	c.tick(ctx, now.Add(2*time.Second))
	if !fq.alt || fq.altDL != 2048 || fq.altUP != 100 {
		t.Fatalf("after qbit restart: alt=%v limits=%d/%d, want reapplied", fq.alt, fq.altDL, fq.altUP)
	}
}

func TestActivePlayersIgnoresPausedAndIdle(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Emby-Token") != "k" {
			http.Error(w, "no", http.StatusUnauthorized)
			return
		}
		w.Write([]byte(`[
			{"NowPlayingItem":{"Name":"a"},"PlayState":{"IsPaused":false}},
			{"NowPlayingItem":{"Name":"b"},"PlayState":{"IsPaused":true}},
			{"PlayState":{"IsPaused":false}}
		]`))
	}))
	defer srv.Close()
	n, err := activePlayers(context.Background(), srv.Client(), config{embyURL: srv.URL, embyAPIKey: "k"})
	if err != nil || n != 1 {
		t.Fatalf("n=%d err=%v, want 1 nil", n, err)
	}
}
