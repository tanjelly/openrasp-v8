#!/bin/bash

set -ev

### begin conf
all_proxy=

# commit or branch or tag
v8_commit=8.6.395.17

# true or false
skip_v8_sync=true

# true or false
build_musl=true
### end conf

# true or false
build_arm64 = true

### v8 sync
if [[ $skip_v8_sync != "true" ]]; then
  export all_proxy

  if [[ ! -d depot_tools ]]; then
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
  fi

  PATH=$PATH:`pwd`/depot_tools

  if [[ ! -d v8 ]]; then
    fetch --nohooks v8
  fi

  pushd v8

  git checkout $v8_commit

  gclient sync

  popd

fi

### build
pushd v8

mkdir -p out/monolith.x64
mkdir -p out/monolith.x86
mkdir -p out/monolith.arm64

cat > out/monolith.x64/args.gn <<EOF
is_debug = false
target_cpu = "x64"
symbol_level = 0
is_component_build = false
treat_warnings_as_errors = false
#use_custom_libcxx = true
libcxx_abi_unstable = false
v8_embedder_string = " <OpenRASP>"
v8_monolithic = true
v8_enable_i18n_support = false
v8_use_snapshot = true
v8_use_external_startup_data = false
v8_enable_shared_ro_heap = true
EOF

cat > out/monolith.x86/args.gn <<EOF
is_debug = false
target_cpu = "x86"
symbol_level = 0
is_component_build = false
treat_warnings_as_errors = false
#use_custom_libcxx = true
libcxx_abi_unstable = false
v8_embedder_string = " <OpenRASP>"
v8_monolithic = true
v8_enable_i18n_support = false
v8_use_snapshot = true
v8_use_external_startup_data = false
v8_enable_shared_ro_heap = true
EOF

cat > out/monolith.arm64/args.gn <<EOF
is_debug = false
target_cpu = "arm64"
symbol_level = 0
is_component_build = false
treat_warnings_as_errors = false
#use_custom_libcxx = false
libcxx_abi_unstable = false
v8_embedder_string = " <OpenRASP>"
v8_monolithic = true
v8_enable_i18n_support = false
v8_use_snapshot = true
v8_use_external_startup_data = false
v8_enable_shared_ro_heap = true
EOF

if [[ "$OSTYPE" != "msys" ]]; then
  cat >> out/monolith.x64/args.gn <<EOF
use_custom_libcxx = false
EOF

  cat >> out/monolith.arm64/args.gn <<EOF
use_custom_libcxx = false
EOF

  cat >> out/monolith.x86/args.gn <<EOF
use_custom_libcxx = false
EOF
fi

if [[ "$build_musl" != "true" ]]; then
  gn gen out/monolith.x64
  ninja -C out/monolith.x64 v8_monolith
  
  if [[ "$build_arm64" = "true" ]]; then
    gn gen out/monolith.arm64
    ninja -C out/monolith.arm64 v8_monolith
  fi
fi

if [[ "$OSTYPE" != "darwin"* && "$OSTYPE" != "linux-musl" && "$build_musl" != "true" ]]; then
  gn gen out/monolith.x86
  ninja -C out/monolith.x86 v8_monolith
fi

if [[ "$build_musl" == "true" ]]; then
  sudo docker build -t libv8-alpine-env -<<EOF
FROM alpine:3.8
ENV http_proxy=$all_proxy https_proxy=$all_proxy
RUN apk add --no-cache bash curl tar xz alpine-sdk curl-dev zlib-dev libexecinfo-dev linux-headers glib-dev ninja
RUN curl -#fL http://nl.alpinelinux.org/alpine/edge/testing/x86_64/gn-0_git20200320-r0.apk | tar zx -C /
RUN cp /usr/bin/python2 /usr/bin/python3
EOF

  cat >> out/monolith.x64/args.gn <<EOF
binutils_path = "/usr/bin"
use_custom_libcxx = false
use_sysroot = false
is_clang = false
use_gold = false
EOF

  sudo docker run --name libv8-alpine-env -it --rm -v `pwd`:/share -w /share libv8-alpine-env bash -c "gn gen out/monolith.x64 && ninja -C out/monolith.x64 v8_monolith"
fi

popd

mkdir -p output/lib64
if [[ "$build_arm64" = "true" ]]; then
  mkdir -p output/arm64
fi
mkdir -p output/lib32

cp -r v8/include output/include

if [[ "$OSTYPE" != "msys" ]]; then
  cp v8/out/monolith.x64/obj/libv8_monolith.a output/lib64/libv8_monolith.a
  if [[ "$build_arm64" = "true" ]]; then
    cp v8/out/monolith.arm64/obj/libv8_monolith.a output/arm64/libv8_monolith.a
  fi
  cp v8/out/monolith.x86/obj/libv8_monolith.a output/lib32/libv8_monolith.a || true
else
  cp v8/out/monolith.x64/obj/v8_monolith.lib output/lib64/v8_monolith.lib
  if [[ "$build_arm64" = "true" ]]; then
    cp v8/out/monolith.arm64/obj/libv8_monolith.a output/arm64/libv8_monolith.a
  fi
  cp v8/out/monolith.x86/obj/v8_monolith.lib output/lib32/v8_monolith.lib
fi
