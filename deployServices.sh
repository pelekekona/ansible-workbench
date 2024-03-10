#!/usr/bin/env bash

  clear

  pipenv run ansible-playbook traefik.yml -i hosts
  pipenv run ansible-playbook watchtower.yml -i hosts
  pipenv run ansible-playbook autoheal.yml -i hosts
  pipenv run ansible-playbook portainer.yml -i hosts
