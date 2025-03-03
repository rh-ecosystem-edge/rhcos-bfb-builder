#!/bin/sh

exec >/dev/console 2>&1
export PS1='\u@\h \W# '

exec /bin/bash --login
