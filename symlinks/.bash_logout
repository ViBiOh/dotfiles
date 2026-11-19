#!/usr/bin/env bash

# Comparison with 2 (instead of 1), because pgrep is run in a subshell, who runs bash
if [[ $(pgrep -a bash | wc -l) -eq 2 ]]; then
  if [[ $(type -t "ssh_agent_stop") == "function" ]]; then
    ssh_agent_stop
  fi

  if [[ $(type -t "gpg_agent_stop") == "function" ]]; then
    gpg_agent_stop
  fi

  if [[ $(type -t "workspaces_daemon_stop") == "function" ]]; then
    workspaces_daemon_stop
  fi

  if [[ $(type -t "kube_clean_contexts") == "function" ]]; then
    kube_clean_contexts
  fi
fi

clear
