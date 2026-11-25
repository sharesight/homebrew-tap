Sharesight Homebrew [Tap](https://docs.brew.sh/Taps)

For developers to install specific version of software packages (Formulae in Homebrew parlance).

To use: `brew tap sharesight/tap`

## Redis

`redis@6.2.6` and `redis@7.2.4` are keg-only, so they can be installed side by side and alongside homebrew-core's `redis`. Their binaries aren't on `PATH`; use `$(brew --prefix redis@7.2.4)/bin` (or `brew link --force redis@7.2.4`).

Both listen on port 6379, so only one can run at a time. Each version has its own config and data, so switching versions starts with an empty database.

Install and switch to Redis 7.2.4:

```bash
brew install sharesight/tap/redis@7.2.4
brew services list | grep redis              # see which Redis is running
brew services stop redis@6.2.6               # or: brew services stop redis
brew services start sharesight/tap/redis@7.2.4
```

Verify:

```bash
$(brew --prefix redis@7.2.4)/bin/redis-cli INFO server | grep redis_version
```

Switch back:

```bash
brew services stop redis@7.2.4
brew services start redis@6.2.6
```

| | `redis@6.2.6` | `redis@7.2.4` |
|---|---|---|
| Config | `$(brew --prefix)/etc/redis.conf` | `$(brew --prefix)/etc/redis@7.2.4/redis.conf` |
| Data | `$(brew --prefix)/var/db/redis` | `$(brew --prefix)/var/db/redis@7.2.4` |
| Log | `$(brew --prefix)/var/log/redis.log` | `$(brew --prefix)/var/log/redis@7.2.4.log` |
