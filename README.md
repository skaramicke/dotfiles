# skaramicke/dotfiles

Opinionated macOS Zsh setup with Starship prompt, Ghostty terminal config, and a few handy scripts.

## What’s inside

- Zsh
	- `.zshrc` loads everything in `.zshrc.d/*.sh`.
	- Helpers for Git, Kubernetes, ports, text processing, sealed secrets, AI helpers, and VS Code shell integration.
- Starship prompt
	- `starship/config.toml` and `starship/init.sh` wire Starship with a lean, fast prompt and useful VCS/status symbols.
- Ghostty (terminal)
	- `ghostty/config` with theme, Monaco font, padding, and a rich set of keybinds.
	- `ghostty/docs.*` are upstream docs/reference snapshots to keep keybinds and options discoverable offline.
- Scripts
	- `scripts/add_md_tags.sh` adds/merges YAML frontmatter tags into Markdown files.
	- `test_md_tags.sh` self-contains a small harness to demonstrate and verify the tag script using fixtures in `test_source/`.

## Quick setup (macOS)

Prereqs (via Homebrew suggested):

- zsh (macOS default is fine)
- starship: `brew install starship`
- Optional utilities used by some functions: `jq`, `yq`, `kubectl`, `op` (1Password CLI), `kubeseal`, `lsof`, `nc`, `curl`

Link the Zsh config and start a new shell:

```sh
ln -sf "$PWD/.zshrc" ~/.zshrc
exec zsh -l
```

Starship is auto-initialized by `.zshrc.d/starship.sh` and will use this repo’s `starship/config.toml`.

Ghostty config (if you use Ghostty):

```sh
mkdir -p ~/.config/ghostty
ln -sf "$PWD/ghostty/config" ~/.config/ghostty/config
```

## Zsh modules (highlights)

- `.zshrc.d/dir_automation.sh`
	- On `cd`: source `.zshrc.local` if present; auto `nvm use` when `.nvmrc` exists.
- `.zshrc.d/git.sh`
	- `git-prune`: reset default branch to origin and delete local branches.
	- `feature <name>`: create `feature/<name>` off `develop` (after prune).
- `.zshrc.d/kubernetes.sh`
	- Creates aliases for all kube contexts from `~/.kube/config` (requires `yq`).
	- `status <resource> <name>` and `statusw` to watch.
- `.zshrc.d/ports.sh`
	- `port <num>` shows PIDs/listeners; `killport <num>` kills listeners.
- `.zshrc.d/sealed_secrets.sh`
	- `generate-sealed-secret <name> [--namespace NS] --KEY op://vault/item/field ...`
	- Reads secrets via 1Password CLI (`op`), creates a Kubernetes Secret (dry-run) and pipes into `kubeseal`.
- `.zshrc.d/text_processing.sh`
	- `prepend "*.md" "Line 1" "Line 2" ...` to prepend lines to matching files.
- `.zshrc.d/ai.sh`
	- `ai "prompt"` chat to a locally reachable vLLM server (port-forwarded with `kubectl`).
	- `ais "prompt"` streams output.
	- `aip "task"` asks AI for a Python script, runs it in a contained Python, and retries once on failure.
	- Requires `jq`, `kubectl`, working vLLM deployment, and network access to the cluster. No API keys are used.

## Ghostty notes

- Theme: `Github-Dark-High-Contrast`, font: `Monaco`, with small window padding.
- Useful binds (subset):
	- Resize splits: `⌘⌃←/→/↑/↓` (±10), `⌘⌃⇧←/→/↑/↓` (±100), and fine `⌘⌃⌥←/→/↑/↓` (±1).
	- New split/tab: `⌘D` (right), `⌘⇧D` (down), `⌘T` (tab); Fullscreen: `⌘⏎`.
	- Copy fenced block helper: `⌘⇧C` wraps clipboard in backticks and copies back.
- See `ghostty/docs.config`, `docs.actions`, `docs.keybinds` for the full map and options reference snapshot.

## Starship prompt

- Compact, informative prompt with symbols for git state and common runtimes.
- Managed by `starship/init.sh` which sets `STARSHIP_CONFIG` to this repo’s `starship/config.toml`.

## Markdown tags helper

Script: `scripts/add_md_tags.sh`

- Adds a YAML frontmatter block if missing, or merges into an existing `tags:` list.
- Leaves files unchanged when all tags already exist.

Usage:

```sh
./scripts/add_md_tags.sh path/to/a.md path/to/b.md -- tag1 tag2 tag3
```

Try the demo test harness:

```sh
./test_md_tags.sh
```

Fixtures live in `test_source/` and are copied to a transient `./test/` dir during the run.

## Troubleshooting

- AI helpers: ensure `kubectl` context points at a cluster running vLLM and that `jq` is installed. Port-forwarding will auto-start on a free local port.
- Kubernetes helpers: require `yq` and a valid `~/.kube/config`.
- Starship not loading: confirm `.zshrc` sources `.zshrc.d/starship.sh` (this repo’s `.zshrc` does).
- Ghostty: place `ghostty/config` into `~/.config/ghostty/config` and reload config via `⌘⇧,` if needed.

---

Last updated: 2025-08-25

