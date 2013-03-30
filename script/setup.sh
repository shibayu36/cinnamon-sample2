#!/bin/bash

sudo aptitude install -y build-essential
sudo aptitude install -y curl
sudo aptitude install -y git-core git-doc
curl -L http://cpanmin.us | perl - --sudo App::cpanminus
