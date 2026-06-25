#!/usr/bin/env bash
# Install build dependencies on RHEL 8 / Rocky Linux 8 / AlmaLinux 8 (CI and local containers).
set -euo pipefail

dnf install -y dnf-plugins-core
dnf config-manager --set-enabled powertools 2>/dev/null \
  || dnf config-manager --set-enabled crb 2>/dev/null \
  || true

# EPEL optional (some images already include needed packages)
dnf install -y epel-release 2>/dev/null || true

dnf install -y \
  gcc gcc-c++ make cmake git pkgconfig \
  autoconf automake libtool zlib-devel \
  flex bison gawk \
  tcl tcl-devel tk tk-devel \
  cairo-devel libXpm-devel libXrender-devel libxcb-devel libX11-devel
