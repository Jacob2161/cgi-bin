package main

import (
	"log/slog"
	"net/http"
	"net/http/cgi"
	"os"
	"path/filepath"

	echo "github.com/labstack/echo/v4"
)

const (
	path   = "/~jakegold/cgi-bin/guestbook.cgi"
	script = "/home/jakegold/cgi-bin/guestbook.cgi"
)

func main() {
	httpListenAddress := os.Getenv("HTTP_LISTEN_ADDRESS")
	if httpListenAddress == "" {
		httpListenAddress = ":1111"
	}

	cgiHandler := &cgi.Handler{
		Path: script,
		Dir:  filepath.Dir(script),
	}

	e := echo.New()
	e.HideBanner, e.HidePort = true, true
	e.HTTPErrorHandler = func(err error, c echo.Context) {
		if !c.Response().Committed {
			c.NoContent(http.StatusInternalServerError)
		}
		slog.Error("handler", "error", err)
	}
	e.Any(path, echo.WrapHandler(cgiHandler))

	slog.Info("running HTTP server", "http_listen_address", httpListenAddress, "script", script)
	if err := e.Start(httpListenAddress); err != nil && err != http.ErrServerClosed {
		slog.Error("server closed unexpectedly", "error", err)
	}
}
