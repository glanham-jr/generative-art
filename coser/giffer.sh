#!/bin/sh

ffmpeg -i cool%d.svg -vf scale=480x480 out.gif -y
