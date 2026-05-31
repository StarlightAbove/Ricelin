#!/bin/sh
pgrep -f "qs -c launcher" >/dev/null || exec qs -c launcher -d
