#!/usr/bin/env bash

chisel_auth() {
  export AUTH="$(pass_get "infra/chisel" "password")"
}
