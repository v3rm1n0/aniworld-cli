<p align="center">
<a href="#installation"><img src="https://img.shields.io/badge/os-linux-brightgreen"></a>
<a href="#installation"><img src="https://img.shields.io/badge/os-mac-brightgreen"></a>
<a href="#windows"><img src="https://img.shields.io/badge/os-windows-yellowgreen"></a>
</p>

<h3 align="center">
A CLI to browse and stream anime from <a href="https://aniworld.to/">aniworld.to</a> with German dubs/subs.
</h3>

## Table of Contents

- [Usage](#usage)
- [Install](#install)
  - [Linux](#linux)
  - [macOS](#macos)
  - [Windows](#windows)
  - [From Source](#from-source)
- [Uninstall](#uninstall)
- [Dependencies](#dependencies)
- [Hoster Status](#hoster-status)
- [FAQ](#faq)
- [Contributing](#contributing)
- [Disclaimer](#disclaimer)

## Usage

```
aniworld-cli [OPTIONS] [SEARCH]
```

```
aniworld-cli "One Piece"        # search and play
aniworld-cli -c                  # continue last anime
aniworld-cli -d "Naruto"         # debug mode
```

After each episode a menu appears:

| Command    | Action                              |
|------------|-------------------------------------|
| `next`     | Play next episode                   |
| `replay`   | Replay current episode              |
| `previous` | Go back one episode                 |
| `select`   | Pick a different season/episode     |
| `hoster`   | Manually switch streaming provider  |
| `quit`     | Exit                                |

The best hoster, language (GerDub > GerSub > EngSub) and quality (1080p > 720p) are selected automatically. Language always takes priority over quality and hoster.

## Install

### Linux

<details><summary>Arch (AUR)</summary>

```sh
yay -S aniworld-cli
```

Development version:

```sh
yay -S aniworld-cli-git
```

</details>

<details><summary>Other distros (install script)</summary>

```sh
git clone https://github.com/dxmoc/aniworld-cli.git
cd aniworld-cli
chmod +x install.sh
sudo ./install.sh
```

Supports Ubuntu/Debian, Fedora, Alpine, Void, Gentoo, Solus, NixOS. Installs missing dependencies automatically.

</details>

### macOS

<details><summary>Homebrew</summary>

```sh
brew tap dxmoc/aniworld-cli https://github.com/dxmoc/aniworld-cli.git
brew install aniworld-cli
```

</details>

### Windows

<details><summary>Scoop (Git Bash required)</summary>

PowerShell/CMD are **not** supported. Use Git Bash inside Windows Terminal.

**1. Setup:**

```powershell
# Install scoop (if not installed): https://scoop.sh
scoop install git
scoop bucket add extras
scoop install extras/windows-terminal
```

Add a Git Bash profile in Windows Terminal:
- Command line: `%GIT_INSTALL_ROOT%\bin\bash.exe -i -l`
- Starting directory: `%USERPROFILE%`

**2. Install dependencies and aniworld-cli:**

```sh
scoop bucket add extras
scoop install fzf mpv yt-dlp nodejs jq

scoop bucket add aniworld https://github.com/dxmoc/aniworld-cli.git
scoop install aniworld/aniworld-cli
```

</details>

### From Source

```sh
git clone https://github.com/dxmoc/aniworld-cli.git
sudo ln -s "$(pwd)/aniworld-cli/aniworld-cli" /usr/local/bin/aniworld-cli
```

## Uninstall

<details>

- **AUR:** `yay -R aniworld-cli`
- **Homebrew:** `brew uninstall aniworld-cli`
- **Scoop:** `scoop uninstall aniworld-cli`
- **install.sh:** `cd aniworld-cli && sudo ./uninstall.sh`
- **Manual:** `sudo rm /usr/local/bin/aniworld-cli`

Optionally remove user data:

```sh
rm -rf ~/.local/share/aniworld-cli
```

</details>

## Dependencies

| Dependency | Purpose                   | Required |
|------------|---------------------------|----------|
| curl       | HTTP requests             | yes      |
| grep       | text processing           | yes      |
| sed        | text processing           | yes      |
| fzf        | interactive selection     | yes      |
| mpv / vlc  | video playback            | yes      |
| node       | VOE hoster extraction     | yes      |
| yt-dlp     | enhanced video extraction | recommended |
| jq         | JSON parsing              | optional |

<details><summary>Install commands per platform</summary>

**Arch:**
```sh
sudo pacman -S curl grep sed fzf mpv yt-dlp nodejs jq
```

**Ubuntu/Debian:**
```sh
sudo apt install curl grep sed fzf mpv yt-dlp nodejs jq
```

**Fedora:**
```sh
sudo dnf install curl grep sed fzf mpv yt-dlp nodejs jq
```

**macOS:**
```sh
brew install curl grep gnu-sed fzf mpv yt-dlp node jq
```

**Windows (Git Bash):**
```sh
scoop install fzf mpv yt-dlp nodejs jq
```

</details>

## Hoster Status

| Hoster     | Status  | Notes                                       |
|------------|---------|---------------------------------------------|
| Vidmoly    | working | preferred, m3u8 directly in HTML            |
| VOE        | working | requires Node.js for deobfuscation          |
| Filemoon   | broken  | migrated to SPA (Vite/React), needs headless browser |
| Streamtape | gone    | no longer listed on aniworld.to             |
| Doodstream | gone    | no longer listed on aniworld.to             |

The tool automatically tries hosters in order of reliability. If the first one fails, it falls back to the next.

## FAQ

<details>

- **Can I choose the language?** Automatic: GerDub > GerSub > EngSub. Use `hoster` menu to pick manually.
- **Can I change quality?** Quality is selected automatically (highest available). Use `hoster` menu to switch.
- **Can I download episodes?** Not currently, streaming only.
- **Where is my watch history?** `~/.local/share/aniworld-cli/history.txt`
- **Can I use vlc instead of mpv?** Yes, if mpv is not installed vlc is used automatically.
- **Debug mode?** `aniworld-cli -d "anime"` saves HTML to `~/.local/share/aniworld-cli/debug_episode.html`.

</details>

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Disclaimer

This tool accesses content from aniworld.to. The legality of streaming from this platform is a grey area. Use at your own risk. Support official services like Crunchyroll for legal anime consumption.

## License

[GPL-3.0](LICENSE)

## Credits

- Inspired by [ani-cli](https://github.com/pystardust/ani-cli)
- [fzf](https://github.com/junegunn/fzf), [mpv](https://mpv.io/), [yt-dlp](https://github.com/yt-dlp/yt-dlp)
