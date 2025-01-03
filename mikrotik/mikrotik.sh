#!/usr/bin/env bash

ssh -p 46496 zen@192.168.88.1 "/export file=mikrotik-home"

scp -P 46496 zen@192.168.88.1:mikrotik-home.rsc .
