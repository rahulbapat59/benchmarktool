#!/usr/bin/env bash

hash uvt-kvm 2>/dev/null || ( echo "uvt-kvm not installed, installing..." && apt -y install uvtool )
uvt-simplestreams-libvirt sync release=xenial arch=amd64

uvt-kvm create secondtest release=xenial
uvt-kvm ssh secondtest