<h3 align="center">
Contributing to aniworld-cli
</h3>

<p align="center">
Thank you for your interest in improving aniworld-cli!<br>
This guide covers everything you need to get started.
</p>

## Table of Contents

- [Reporting Bugs](#reporting-bugs)
- [Suggesting Features](#suggesting-features)
- [Development Setup](#development-setup)
- [Branch Naming](#branch-naming)
- [Commit Messages](#commit-messages)
- [Code Style](#code-style)
- [Testing](#testing)
- [Pull Requests](#pull-requests)
- [License](#license)

## Reporting Bugs

Open an [issue](https://github.com/dxmoc/aniworld-cli/issues) and include:

| Field | Description |
|-------|-------------|
| OS & method | e.g. Arch (AUR), macOS (Homebrew), Windows (Scoop) |
| Error message | Complete terminal output |
| Steps to reproduce | Minimal steps to trigger the bug |
| Expected behavior | What you expected to happen |
| Debug log | Run `aniworld-cli -d "anime"` and attach the output |

## Suggesting Features

Open an [issue](https://github.com/dxmoc/aniworld-cli/issues) and describe:

- **What** you want to achieve
- **Why** it would be useful
- **How** it could work (optional, but appreciated)

## Development Setup

<details><summary>Clone and run from source</summary>

```sh
git clone https://github.com/dxmoc/aniworld-cli.git
cd aniworld-cli
chmod +x aniworld-cli
./aniworld-cli
```

</details>

<details><summary>Debug mode</summary>

```sh
bash -x ./aniworld-cli
```

This prints every command before execution — useful for tracing issues.

</details>

## Branch Naming

Create a branch from `main` using one of these prefixes:

| Prefix | Usage | Example |
|--------|-------|---------|
| `feature/` | New functionality | `feature/download-episodes` |
| `fix/` | Bug fixes | `fix/voe-extraction` |
| `docs/` | Documentation only | `docs/update-faq` |
| `refactor/` | Code restructuring | `refactor/hoster-selection` |

## Commit Messages

Use the `type: description` format:

| Type | When to use |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation changes |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test` | Adding or updating tests |
| `chore` | Maintenance (CI, deps, scripts) |

Examples:

```
feat: add episode download support
fix: handle empty search results gracefully
docs: add Windows troubleshooting section
```

Keep the first line under 72 characters. Add a blank line and longer explanation if needed.

## Code Style

| Rule | Example |
|------|---------|
| 4 spaces indentation | `    local query="$1"` |
| Quote all variables | `"${var}"`, not `$var` |
| Function names | `lowercase_with_underscores` |
| Comments | Only for complex logic |
| Language tag | Use `sh` for code blocks |

<details><summary>Example function</summary>

```sh
function search_anime() {
    local query="$1"

    if [[ -z "${query}" ]]; then
        echo "Error: Search query required"
        return 1
    fi

    curl -s "${API_URL}?q=${query}"
}
```

</details>

## Testing

Test your changes with:

| Area | What to check |
|------|---------------|
| Providers | Different video hosters (Vidmoly, VOE) |
| Features | Search, browse, watch, continue |
| Edge cases | Empty results, network errors, missing deps |
| Platforms | At least one of Linux, macOS, Windows |

## Pull Requests

1. Fork and create a [branch](#branch-naming) from `main`
2. Make your changes following the [code style](#code-style)
3. [Test](#testing) on at least one platform
4. Submit a PR with a clear description

### PR Checklist

Before submitting, make sure:

- [ ] Branch is based on latest `main`
- [ ] Commit messages follow the [convention](#commit-messages)
- [ ] Code follows the [style guide](#code-style)
- [ ] Changes have been tested manually
- [ ] No unrelated changes are included
- [ ] PR description explains **what** and **why**

## Questions?

Open an issue on [GitHub](https://github.com/dxmoc/aniworld-cli/issues).

## License

Contributions are licensed under [GPL-3.0](LICENSE).
