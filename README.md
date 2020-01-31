# dnscrypt-lists [![CI](https://github.com/zeffy/dnscrypt-lists/workflows/CI/badge.svg)](https://github.com/zeffy/dnscrypt-lists/actions) ![ISC](https://img.shields.io/github/license/zeffy/dnscrypt-lists)
My personal script etc. used in combination with [dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy).

## Configuration

The default [`domain_lists.json`](https://github.com/zeffy/dnscrypt-lists/blob/master/domain_lists.json)
shows most of the implemented configurations, so it makes a good reference.

The root of the JSON object is an array of output lists, which have:

| Type | Property | Description |
| ---- | -------- | ----------- |
| `string` | `filename` | Output filename, can be absolute or relative. |
| [`UriHostNameType`] | `kind` | For validating entries. Can be `dns`, `ipv4` or `ipv6`. |
| `object` | `defaults` | Object that defines *default* properties which are applied to child `sources` (see below). Only `regex`, `comment_token` and `http_headers` are valid. Default HTTP headers are merged, and if there is a collision the default is overriden. |

The child `sources` object is an array of individual list sources:

| Type | Property | Description |
| ---- | -------- | ----------- |
| `string` | `url` | HTTP or HTTPS URL to fetch. |
| `string` | `file` | Local file path to fetch, can be absolute or relative (takes precedence over `url`). |
| `string` | `regex` | Regular expression applied to each line of the source to extract the host name. |
| `int` | `skip_lines` | Skips *n* lines at the head of the file before continuing. |
| `bool` | `rot13` | Applies [ROT13] to each line before processing it. |
| `string` | `comment_token` | String that is used to denote a comment (e.g. `#` or `;`). |
| `object` | `http_headers` | Custom name-value pairs that are added to the request headers (e.g. `Referer` or `User-Agent`). |

When in doubt refer to [`create_domain_lists.ps1`](https://github.com/zeffy/dnscrypt-lists/blob/master/create_domain_lists.ps1), as this might be outdated.

## Updater

This repository also contains `updater.ps1`, a PowerShell script that can be used to auto-update both dnscrypt-proxy and dnscrypt-lists.

By default it pulls `whitelist.txt` and `family-friendly-blacklist.txt` from the latest release, but can easily be modified to your needs.

[`UriHostNameType`]: https://docs.microsoft.com/en-us/dotnet/api/system.urihostnametype?view=netframework-4.8
[ROT13]: https://en.wikipedia.org/wiki/ROT13