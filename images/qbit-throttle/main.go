// qbit-throttle caps qBittorrent's speed while someone is playing media on Emby.
//
// Every POLL_INTERVAL it asks Emby for active sessions and flips qBittorrent's
// "alternative speed limits" mode accordingly. The alt limits are written once into
// qBittorrent's preferences, so the regular global limits are never touched.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync/atomic"
	"syscall"
	"time"
)

type config struct {
	embyURL      string
	embyAPIKey   string
	qbitURL      string
	downKiB      int
	upKiB        int
	pollInterval time.Duration
	releaseDelay time.Duration // keep throttling this long after playback stops
	embyFailSafe time.Duration // release the limits if Emby is unreachable this long
	listen       string
}

func loadConfig() (config, error) {
	c := config{
		embyURL:      strings.TrimRight(env("EMBY_URL", "http://emby.external-services.svc.cluster.local:8096"), "/"),
		embyAPIKey:   os.Getenv("EMBY_API_KEY"),
		qbitURL:      strings.TrimRight(env("QBIT_URL", "http://qbittorrent.qbittorrent.svc.cluster.local:9091"), "/"),
		downKiB:      envInt("DOWN_LIMIT_KIB", 2048),
		upKiB:        envInt("UP_LIMIT_KIB", 100),
		pollInterval: envDuration("POLL_INTERVAL", 2*time.Second),
		releaseDelay: envDuration("RELEASE_DELAY", 45*time.Second),
		embyFailSafe: envDuration("EMBY_FAIL_SAFE", 2*time.Minute),
		listen:       env("LISTEN", ":8080"),
	}
	if c.embyAPIKey == "" {
		return c, errors.New("EMBY_API_KEY is required")
	}
	return c, nil
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func envInt(key string, def int) int {
	if v, err := strconv.Atoi(os.Getenv(key)); err == nil {
		return v
	}
	return def
}

func envDuration(key string, def time.Duration) time.Duration {
	if v, err := time.ParseDuration(os.Getenv(key)); err == nil {
		return v
	}
	return def
}

// --- Emby ---

type embySession struct {
	NowPlayingItem *json.RawMessage `json:"NowPlayingItem"`
	PlayState      struct {
		IsPaused bool `json:"IsPaused"`
	} `json:"PlayState"`
}

// activePlayers returns how many sessions are currently playing (not paused).
func activePlayers(ctx context.Context, hc *http.Client, c config) (int, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.embyURL+"/Sessions", nil)
	if err != nil {
		return 0, err
	}
	req.Header.Set("X-Emby-Token", c.embyAPIKey)
	req.Header.Set("Accept", "application/json")
	resp, err := hc.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("emby /Sessions: %s", resp.Status)
	}
	var sessions []embySession
	if err := json.NewDecoder(resp.Body).Decode(&sessions); err != nil {
		return 0, fmt.Errorf("emby /Sessions: decode: %w", err)
	}
	n := 0
	for _, s := range sessions {
		if s.NowPlayingItem != nil && !s.PlayState.IsPaused {
			n++
		}
	}
	return n, nil
}

// --- qBittorrent ---

type qbit struct {
	hc   *http.Client
	base string
}

func (q qbit) do(ctx context.Context, method, path string, form url.Values) ([]byte, error) {
	var body io.Reader
	if form != nil {
		body = strings.NewReader(form.Encode())
	}
	req, err := http.NewRequestWithContext(ctx, method, q.base+path, body)
	if err != nil {
		return nil, err
	}
	if form != nil {
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	}
	resp, err := q.hc.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("qbittorrent %s: %s", path, resp.Status)
	}
	return b, nil
}

// altLimitsOn reports whether alternative speed limits are currently enabled.
func (q qbit) altLimitsOn(ctx context.Context) (bool, error) {
	b, err := q.do(ctx, http.MethodGet, "/api/v2/transfer/speedLimitsMode", nil)
	if err != nil {
		return false, err
	}
	return strings.TrimSpace(string(b)) == "1", nil
}

func (q qbit) toggleAltLimits(ctx context.Context) error {
	_, err := q.do(ctx, http.MethodPost, "/api/v2/transfer/toggleSpeedLimitsMode", url.Values{})
	return err
}

// ensureAltLimits writes the alt limits into qBittorrent's preferences if they differ.
func (q qbit) ensureAltLimits(ctx context.Context, downKiB, upKiB int) (changed bool, err error) {
	b, err := q.do(ctx, http.MethodGet, "/api/v2/app/preferences", nil)
	if err != nil {
		return false, err
	}
	var p struct {
		AltDL     int  `json:"alt_dl_limit"`
		AltUP     int  `json:"alt_up_limit"`
		Scheduler bool `json:"scheduler_enabled"`
	}
	if err := json.Unmarshal(b, &p); err != nil {
		return false, fmt.Errorf("qbittorrent preferences: decode: %w", err)
	}
	if p.Scheduler {
		slog.Warn("qBittorrent's alternative-speed scheduler is enabled and will fight this controller")
	}
	if p.AltDL == downKiB && p.AltUP == upKiB {
		return false, nil
	}
	patch, _ := json.Marshal(map[string]int{"alt_dl_limit": downKiB, "alt_up_limit": upKiB})
	_, err = q.do(ctx, http.MethodPost, "/api/v2/app/setPreferences", url.Values{"json": {string(patch)}})
	return err == nil, err
}

// --- controller ---

type controller struct {
	cfg  config
	emby func(context.Context) (int, error)
	qb   qbit

	throttled   atomic.Bool
	players     atomic.Int64
	transitions atomic.Int64
	lastTick    atomic.Int64 // unix seconds

	lastActive   time.Time // last time a player was seen
	embyDownFrom time.Time // zero while Emby is reachable
	prefsOK      bool      // alt limits known to be in place on the current qbit
}

// wantThrottle updates the playback state from one Emby poll and returns the desired mode.
func (c *controller) wantThrottle(now time.Time, n int, embyErr error) bool {
	if embyErr != nil {
		if c.embyDownFrom.IsZero() {
			c.embyDownFrom = now
			slog.Warn("emby unreachable, holding current state", "err", embyErr)
		}
		if now.Sub(c.embyDownFrom) >= c.cfg.embyFailSafe {
			return false // fail open: never leave qbit throttled on a blind guess
		}
		return c.throttled.Load()
	}
	if !c.embyDownFrom.IsZero() {
		slog.Info("emby reachable again", "down_for", now.Sub(c.embyDownFrom).Round(time.Second))
		c.embyDownFrom = time.Time{}
	}
	c.players.Store(int64(n))
	if n > 0 {
		c.lastActive = now
		return true
	}
	return !c.lastActive.IsZero() && now.Sub(c.lastActive) < c.cfg.releaseDelay
}

func (c *controller) tick(ctx context.Context, now time.Time) {
	n, err := c.emby(ctx)
	want := c.wantThrottle(now, n, err)

	if !c.prefsOK {
		changed, err := c.qb.ensureAltLimits(ctx, c.cfg.downKiB, c.cfg.upKiB)
		if err != nil {
			slog.Error("qbittorrent: set alt limits", "err", err)
			return
		}
		c.prefsOK = true
		if changed {
			slog.Info("qbittorrent alt limits set", "down_kib", c.cfg.downKiB, "up_kib", c.cfg.upKiB)
		}
	}

	on, err := c.qb.altLimitsOn(ctx)
	if err != nil {
		slog.Error("qbittorrent: read mode", "err", err)
		c.prefsOK = false // qbit may have restarted; re-check the prefs next time
		return
	}
	if on != want {
		if err := c.qb.toggleAltLimits(ctx); err != nil {
			slog.Error("qbittorrent: toggle mode", "err", err)
			return
		}
		c.transitions.Add(1)
		slog.Info("speed limits changed", "throttled", want, "players", n)
	}
	c.throttled.Store(want)
	c.lastTick.Store(now.Unix())
}

func (c *controller) run(ctx context.Context) {
	t := time.NewTicker(c.cfg.pollInterval)
	defer t.Stop()
	c.tick(ctx, time.Now())
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-t.C:
			c.tick(ctx, now)
		}
	}
}

// release turns the limits off; used on shutdown so a removed controller never leaves qbit capped.
func (c *controller) release(ctx context.Context) {
	if on, err := c.qb.altLimitsOn(ctx); err == nil && on {
		if err := c.qb.toggleAltLimits(ctx); err != nil {
			slog.Error("release on shutdown failed", "err", err)
			return
		}
		slog.Info("speed limits released on shutdown")
	}
}

func (c *controller) serve(addr string) *http.Server {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		// Healthy while the loop is alive and has talked to qbit recently.
		age := time.Since(time.Unix(c.lastTick.Load(), 0))
		if age > 30*time.Second+c.cfg.pollInterval {
			http.Error(w, "stale: last successful tick "+age.Round(time.Second).String()+" ago", http.StatusServiceUnavailable)
			return
		}
		fmt.Fprintln(w, "ok")
	})
	mux.HandleFunc("/metrics", func(w http.ResponseWriter, _ *http.Request) {
		b2i := func(b bool) int {
			if b {
				return 1
			}
			return 0
		}
		fmt.Fprintf(w, "# TYPE qbit_throttle_active gauge\nqbit_throttle_active %d\n", b2i(c.throttled.Load()))
		fmt.Fprintf(w, "# TYPE qbit_throttle_emby_players gauge\nqbit_throttle_emby_players %d\n", c.players.Load())
		fmt.Fprintf(w, "# TYPE qbit_throttle_transitions_total counter\nqbit_throttle_transitions_total %d\n", c.transitions.Load())
	})
	srv := &http.Server{Addr: addr, Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	go func() {
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("http server", "err", err)
		}
	}()
	return srv
}

func main() {
	cfg, err := loadConfig()
	if err != nil {
		slog.Error("config", "err", err)
		os.Exit(1)
	}
	hc := &http.Client{Timeout: 5 * time.Second}
	c := &controller{
		cfg:  cfg,
		emby: func(ctx context.Context) (int, error) { return activePlayers(ctx, hc, cfg) },
		qb:   qbit{hc: hc, base: cfg.qbitURL},
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	srv := c.serve(cfg.listen)
	slog.Info("started", "emby", cfg.embyURL, "qbit", cfg.qbitURL, "down_kib", cfg.downKiB, "up_kib", cfg.upKiB,
		"poll", cfg.pollInterval, "release_delay", cfg.releaseDelay)

	c.run(ctx)

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	c.release(shutdownCtx)
	_ = srv.Shutdown(shutdownCtx)
}
