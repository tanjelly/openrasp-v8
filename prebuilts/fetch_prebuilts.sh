#!/bin/bash

set -e
 
ROOT=$(git rev-parse --show-toplevel || pwd)

if [ $TRAVIS ]; then
  DIR=$HOME/cache
  mkdir -p $DIR
else
  DIR=/tmp
fi

if [[ "$OSTYPE" == "linux-gnu" ]]; then
  FILENAME="openrasp-v8-prebuilts-8.6-linux.tar.gz"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  FILENAME="openrasp-v8-prebuilts-7.8-darwin.tar.gz"
elif [[ "$OSTYPE" == "msys" ]]; then
  FILENAME="openrasp-v8-prebuilts-7.8-windows.tar.gz"
elif [[ "$OSTYPE" == "linux-musl" ]]; then
  FILENAME="openrasp-v8-prebuilts-7.8-linux-musl.tar.gz"
else
  echo "Unsupported os type"
  exit 1
fi

if [[ "$OSTYPE" == "linux-gnu" ]]; then
  curl -# -k -L -o $DIR/$FILENAME.download -z $DIR/$FILENAME https://github.com/tanjelly/openrasp-v8/releases/download/v1/$FILENAME
else
  curl -# -k -L -o $DIR/$FILENAME.download -z $DIR/$FILENAME https://packages.baidu.com/app/openrasp/v8/$FILENAME
fi
[[ -f $DIR/$FILENAME.download ]] && mv $DIR/$FILENAME.download $DIR/$FILENAME
tar zxf $DIR/$FILENAME -C $ROOT/prebuilts
