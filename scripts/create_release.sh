#!/bin/bash
VERSION=0.09
tar --transform=s,^,tool-${VERSION}/, -czf benchmarktool-${VERSION}.tgz benchmarks config Helper_Scripts *.py README.txt ansible

