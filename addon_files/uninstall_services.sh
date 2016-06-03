#!/bin/sh

sudo launchctl unload -w /Library/LaunchDaemons/pservice.downloader.plist
sudo launchctl unload -w /Library/LaunchDaemons/pservice.worker.plist