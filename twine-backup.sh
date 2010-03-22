#!/bin/bash
mkdir backup
DATE=`date -u +%Y%m%d.%H%M%S`
echo backup/partitions.$DATE.zip
zip -9ryq backup/partitions.$DATE.zip partitions
