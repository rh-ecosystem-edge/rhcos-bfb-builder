#!/bin/sh

export PS1='\u@debug:\W# '
echo "starting shell" > /dev/kmsg

exec setsid /bin/bash -i </dev/hvc0 >/dev/hvc0 2>&1

