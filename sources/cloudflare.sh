#!/usr/bin/env bash

cloudflare_tunnel() {
  cloudflared tunnel --url "${1:-http://localhost:1080}"
}
