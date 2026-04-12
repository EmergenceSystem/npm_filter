# npm_filter
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE.md)

An [em_filter](https://hex.pm/packages/em_filter) agent that searches the [npm registry](https://www.npmjs.com/) and returns package information as [Emergence](https://github.com/EmergenceSystem/em_disco) results.

## Query

Any keyword, package name, or author query accepted by the npm search API.

| Field | Source | Example |
|---|---|---|
| title | `name` + `version` | `lodash v4.17.21` |
| resume | `description` + publisher | `Lodash modular utilities. by johnnyreilly` |
| url | npmjs.com package page | `https://www.npmjs.com/package/lodash` |
| source | `npmjs.com` | |

Up to 10 results are returned per query.

## Usage

**Via curl (direct to em_disco):**

```bash
# Search by package name
curl -X POST http://localhost:8080/query \
  -H "Content-Type: application/json" \
  -d '{"value": "lodash", "capabilities": ["npm"]}'

# Search by keyword
curl -X POST http://localhost:8080/query \
  -H "Content-Type: application/json" \
  -d '{"value": "http client fetch", "capabilities": ["npm"]}'

# Search TypeScript packages
curl -X POST http://localhost:8080/query \
  -H "Content-Type: application/json" \
  -d '{"value": "typescript orm", "capabilities": ["npm"]}'
```

**Via Erlang shell:**

```erlang
emquest_cli:query(<<"lodash">>).
emquest_cli:query(<<"react hooks">>).
```

## Installation

```bash
git clone https://github.com/EmergenceSystem/npm_filter.git
cd npm_filter
rebar3 shell --apps npm_filter
```

Requires `em_disco` running on `localhost:8080` (configured in `emergence.conf`).

## Capabilities

`search`, `query`, `npm`, `javascript`, `typescript`, `nodejs`, `packages`

## License

Apache 2.0 — see [LICENSE.md](LICENSE.md).
