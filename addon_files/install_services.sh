#!/bin/sh

sudo cp pservice.worker.plist /Library/LaunchDaemons/pservice.worker.plist
sudo cp pservice.downloader.plist /Library/LaunchDaemons/pservice.downloader.plist

sudo launchctl unload -w /Library/LaunchDaemons/pservice.downloader.plist
sudo launchctl load -w /Library/LaunchDaemons/pservice.downloader.plist

sudo launchctl unload -w /Library/LaunchDaemons/pservice.worker.plist
sudo launchctl load -w /Library/LaunchDaemons/pservice.worker.plist