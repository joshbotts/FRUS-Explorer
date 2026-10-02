#!/bin/sh
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# The Office of the Historian report's public-site checks (#1309): fetch each URL of urls.txt and
# print its HTTP status. Read-only. The list carries its own controls: a page and an image known to
# exist beside each one the report says is absent, and one invented path per host (d99999, 9999.png),
# so a status reads against what the same host answers for something that is there and something that
# cannot be. Measured 2026-10-01: static.history.state.gov answers 403 for an image that does not
# exist. history.state.gov answers 404 for a page that does not exist, and 403 for ANY page once it
# has had a few dozen requests in a minute (a first run answered pg_654 with 200 and a second, run
# straight after, with 403), so this script waits between requests and asks a 403 page again.
#
#   sh tools/oh-report/check_urls.sh > Planning/OH-Report-<date>/web-checks.txt
here=$(dirname "$0")
while read -r url; do
  [ -z "$url" ] && continue
  tries=0
  while :; do
    code=$(curl -s -o /dev/null -L --max-time 40 -w '%{http_code}' "$url")
    tries=$((tries + 1))
    case "$url" in
      https://history.state.gov/*)
        if [ "$code" = 403 ] && [ "$tries" -lt 4 ]; then sleep 45; continue; fi ;;
    esac
    break
  done
  echo "$code $url"
  sleep 5
done < "$here/urls.txt"
