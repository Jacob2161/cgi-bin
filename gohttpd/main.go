package main

import (
	"log/slog"
	"net/http"
	"net/http/cgi"
	"os"
	"path/filepath"
	"strings"

	echo "github.com/labstack/echo/v4"
)

func main() {
	httpListenAddress := os.Getenv("HTTP_LISTEN_ADDRESS")
	if httpListenAddress == "" {
		httpListenAddress = ":1111"
	}

	// cgiBinDir should be something like "/home/jakegold/cgi-bin"
	cgiBinDir := os.Getenv("CGI_BIN_DIR")
	if cgiBinDir == "" {
		slog.Error("CGI_BIN_DIR environment variable is not set")
		os.Exit(1)
	}

	// urlPrefix should be something like "/~jakegold/cgi-bin"
	urlPrefix := os.Getenv("CGI_URL_PREFIX")
	if urlPrefix == "" {
		slog.Error("CGI_URL_PREFIX environment variable is not set")
		os.Exit(1)
	}

	e := echo.New()
	e.HideBanner, e.HidePort = true, true
	e.HTTPErrorHandler = func(err error, c echo.Context) {
		if !c.Response().Committed {
			c.NoContent(http.StatusInternalServerError)
		}
		slog.Error("handler", "error", err)
	}

	// Handle any .cgi file in the cgi-bin directory
	e.Any(urlPrefix+"/:script", func(c echo.Context) error {
		scriptName := c.Param("script")

		// Basic security checks
		if !strings.HasSuffix(scriptName, ".cgi") {
			return c.NoContent(http.StatusNotFound)
		}
		if strings.Contains(scriptName, "..") || strings.Contains(scriptName, "/") {
			return c.NoContent(http.StatusBadRequest)
		}

		scriptPath := filepath.Join(cgiBinDir, scriptName)

		cgiHandler := &cgi.Handler{
			Path: scriptPath,
			Dir:  cgiBinDir,
		}

		handler := echo.WrapHandler(cgiHandler)
		return handler(c)
	})

	slog.Info("running HTTP server",
		"http_listen_address", httpListenAddress,
		"cgi_bin_dir", cgiBinDir,
		"url_prefix", urlPrefix)

	if err := e.Start(httpListenAddress); err != nil && err != http.ErrServerClosed {
		slog.Error("server closed unexpectedly", "error", err)
	}
}
