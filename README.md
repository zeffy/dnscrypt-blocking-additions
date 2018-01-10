# dnscrypt-blocking-additions


## Files in the `hosts` folder

File name | Description
--------- | -----------
`activation.txt` | License validation hosts for various software.
`anticheat.txt` | Hosts related to various video game anti-cheat software.
`miscellaneous.txt` | Other hosts that don't fit into either of the above files.

## Files in the `contrib` folder

Files that are sourced from the dnscrypt repository's own `contrib` folder are denoted with an asterisk(*),
and have a separate license than the rest of this repository. See `contrib\COPYING.dnscrypt`.

File name | Description
--------- | -----------
`domains-blacklist.conf`* | List of various hosts files from around the web.
`domains-blacklist-local-additions.txt`* | Local blacklist additions.
`domains-exclusions.conf` | List of various hosts files that you want to **exclude** from the blacklist. Currently contains a list of known Windows Update hosts from crazy-max's [WindowsSpyBlocker] project.
`domains-exclusions-local-additions.txt` | List of exclusions to filter out more zealous hosts lists so less things break.
`generate-domains-list.py`* | Modified version of the `generate-domains-blacklist.py` script from dnscrypt.

### How to use `generate-domains-list.py`

```bat
$ python .\generate-domains-list.py
```

Unlike the original, it is not necessary to pipe the output to a file, it does that automatically.
The final blacklist result is written to `mybase.txt`, and the exclusions are written to `domain-exclusions.txt` (only needed for debugging).

Parameter | Default value | Description
--------- | ------------- | -----------
`-c` or `--config` | `domains-blacklist.conf` | file containing domain list sources
`-x` or `--exclusions-config` | `domains-exclusions.conf` | file containing a set of names to exclude from the blacklist
`-i` or `--ignore-retrieval-failure` | - | generate list even if some urls couldn't be retrieved

[WindowsSpyBlocker]: https://github.comcom/crazy-max/WindowsSpyBlocker
