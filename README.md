# dnscrypt-blocking-additions

## Blacklists

File name | Description
--------- | -----------
`activation.txt` | License validation hosts for various software
`ads.txt` | Ad hosts used in various software
`anticheat.txt` | Hosts related to various video game anti-cheat software
`fakenews.txt` | Sites that deliberately spread hoaxes and disinformation
`misc.txt` | Other hosts that don't fit into either of the above files
`tracking.txt` | Tracking and telemetry hosts used in various software

## Whitelists

File name | Description
--------- | -----------
`amazon.txt` | Amazon domains
`cdn.txt` | Popular Content Distribution Network (CDN) domains
`crl.txt` | Certificate Revocation List domains
`github.txt` | GitHub domains
`microsoft.txt` | Microsoft domains (MSDN, TechNet, Visual Studio)
`misc.txt` | Other domains that have been blocked at some point which I've had to manually whitelist
`ocsp.txt` | Online Certificate Status Protocol (OCSP) domains
`social.txt` | Social media sites (Twitter, Discord)
`video.txt` | Video hosting sites (Dumpert, Twitch)

## Files in the `script` folder

Files that are sourced from the dnscrypt repository's own `contrib` folder are denoted with an asterisk(*),
and have a separate license than the rest of this repository. See `contrib\COPYING.dnscrypt`.

File name | Description
--------- | -----------
`blacklist.conf`* | List of various hosts files from around the web, and the ones in this repository
`whitelist.conf` | List of various hosts files to **exclude** from the blacklist
`make_blacklist.py`* | Modified version of the `generate-domains-blacklist.py` script from dnscrypt

### How to use `make_blacklist.py`

```bat
$ py -2 .\make_blacklist.py
```

The final blacklist result is written to `blacklist.txt`, and the exclusions are written to `whitelist.tmp` (only needed for debugging).

Parameter | Default value | Description
--------- | ------------- | -----------
`-c` or `--config` | `domains-blacklist.conf` | file containing domain list sources
`-w` or `--whitelist` | `domains-whitelist.conf` | file containing a set of names to exclude from the blacklist
`-r` or `--time-restricted` | `time-restricted.txt` | file containing a set of names to be time restricted
`-i` or `--ignore-retrieval-failure` | - | generate list even if some urls couldn't be retrieved
`-t` or `--timeout` | `30` | URL open timeout
