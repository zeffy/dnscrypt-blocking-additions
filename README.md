# dnscrypt-lists ![CI](https://github.com/zeffy/dnscrypt-lists/workflows/CI/badge.svg)
My personal script etc. used in combination with dnscrypt-proxy.

# Configuration

The default [`domain_lists.json`](https://github.com/zeffy/dnscrypt-lists/blob/master/domain_lists.json)
shows most of the implemented configurations, so it makes a good reference.

The root of the JSON object is an array of output lists, which have:

| Property | Description |
| -------- | ----------- |
| `filename` | Output filename of the list |
| `kind` | For validating entries. Can be `dns`, `ipv4` or `ipv6` (see [`UriHostNameType`]) |
| `defaults` | Object that defines *default* properties which are applied to child `sources` (see below) (can contain `comment_token` or `http_headers`) |

The child `sources` object is an array of individual lists

| Property | Description |
| -------- | ----------- |
| `url` | HTTP or HTTPS URL to fetch the source from |
| `file` | Local file path to the source (takes precedence over `url`) |
| `regex` | Regular expression applied to each line of the source to extract the host name |
| `skip_lines` | Skips *n* lines at the head of the file before continuing |
| `rot13` | Applies [ROT13] to the line before processing it |
| `http_headers` | Custom name-value pairs that are sent in the request headers (e.g. `Referer` or `User-Agent`) |
| `comment_token` | String that is used to denote a comment (e.g. `#` or `;`) |

When in doubt refer to [`create_domain_lists.ps1`](https://github.com/zeffy/dnscrypt-lists/blob/master/create_domain_lists.ps1), as this might be outdated.

[`UriHostNameType`]: https://docs.microsoft.com/en-us/dotnet/api/system.urihostnametype?view=netframework-4.8
[ROT13]: https://en.wikipedia.org/wiki/ROT13