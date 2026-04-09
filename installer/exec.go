package main

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"sync"
	"time"
)

// CmdRunner executes commands with streaming output and sudo support.
type CmdRunner struct {
	ctx      context.Context
	logFunc  func(string) // sends lines to the TUI
	repoRoot string
}

// NewCmdRunner creates a runner bound to a context and log callback.
func NewCmdRunner(ctx context.Context, logFunc func(string), repoRoot string) *CmdRunner {
	return &CmdRunner{ctx: ctx, logFunc: logFunc, repoRoot: repoRoot}
}

// Log sends a message to the TUI log.
func (r *CmdRunner) Log(msg string) {
	r.logFunc(msg)
}

// Run executes a command, streaming stdout/stderr to the TUI.
func (r *CmdRunner) Run(name string, args ...string) error {
	return r.RunInDir("", name, args...)
}

// RunInDir executes a command in a specific directory.
func (r *CmdRunner) RunInDir(dir, name string, args ...string) error {
	cmd := exec.CommandContext(r.ctx, name, args...)
	if dir != "" {
		cmd.Dir = dir
	}
	cmd.Stdin = os.Stdin // allow interactive prompts (e.g. pacman)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("stdout pipe: %w", err)
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return fmt.Errorf("stderr pipe: %w", err)
	}

	r.logFunc(fmt.Sprintf("$ %s %s", name, joinArgs(args)))

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("start %s: %w", name, err)
	}

	// Stream both stdout and stderr concurrently
	var wg sync.WaitGroup
	wg.Add(2)
	go func() { defer wg.Done(); r.scanLines(stdout) }()
	go func() { defer wg.Done(); r.scanLines(stderr) }()
	wg.Wait()

	if err := cmd.Wait(); err != nil {
		if r.ctx.Err() == context.Canceled {
			return fmt.Errorf("cancelled")
		}
		return fmt.Errorf("%s failed: %w", name, err)
	}
	return nil
}

// RunInteractive executes a command with direct terminal access (stdin/stdout/stderr).
// Use this for commands that need user interaction (e.g. pacman Y/n prompts).
func (r *CmdRunner) RunInteractive(name string, args ...string) error {
	return r.RunInteractiveInDir("", name, args...)
}

// RunInteractiveInDir executes a command in a specific directory with direct terminal access.
func (r *CmdRunner) RunInteractiveInDir(dir, name string, args ...string) error {
	cmd := exec.CommandContext(r.ctx, name, args...)
	if dir != "" {
		cmd.Dir = dir
	}
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	r.logFunc(fmt.Sprintf("$ %s %s", name, joinArgs(args)))

	if err := cmd.Run(); err != nil {
		if r.ctx.Err() == context.Canceled {
			return fmt.Errorf("cancelled")
		}
		return fmt.Errorf("%s failed: %w", name, err)
	}
	return nil
}

// RunSudo executes a command with sudo.
func (r *CmdRunner) RunSudo(name string, args ...string) error {
	sudoArgs := append([]string{name}, args...)
	return r.Run("sudo", sudoArgs...)
}

// RunSudoInteractive executes a sudo command with direct terminal access.
func (r *CmdRunner) RunSudoInteractive(name string, args ...string) error {
	sudoArgs := append([]string{name}, args...)
	return r.RunInteractive("sudo", sudoArgs...)
}

// RunSudoIgnoreErr runs a sudo command and ignores errors.
func (r *CmdRunner) RunSudoIgnoreErr(name string, args ...string) {
	_ = r.RunSudo(name, args...)
}

// SudoKeepalive starts a background goroutine that refreshes sudo credentials
// every 60 seconds. Call this after the user has already authenticated with sudo.
// Returns a stop function to cancel the keepalive goroutine.
func SudoKeepalive(ctx context.Context) (stop func()) {
	keepCtx, cancel := context.WithCancel(ctx)
	go func() {
		ticker := time.NewTicker(60 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-keepCtx.Done():
				return
			case <-ticker.C:
				exec.Command("sudo", "-n", "true").Run()
			}
		}
	}()
	return cancel
}

// CommandExists checks if a binary is available in PATH.
func CommandExists(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

func (r *CmdRunner) scanLines(rd io.Reader) {
	scanner := bufio.NewScanner(rd)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for scanner.Scan() {
		r.logFunc(scanner.Text())
	}
}

func joinArgs(args []string) string {
	s := ""
	for i, a := range args {
		if i > 0 {
			s += " "
		}
		s += a
	}
	return s
}
