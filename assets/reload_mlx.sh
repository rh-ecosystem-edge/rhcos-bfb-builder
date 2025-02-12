#!/bin/sh

modprobe -r mlx5_ib
modprobe -r mlx5_fwctl
modprobe -r mlx5_core
sleep 2
modprobe mlx5_ib
