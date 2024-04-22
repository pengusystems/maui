# Overview
We don't store The source of [grpc](https://github.com/grpc/grpc) in here since it has MANY MANY dependencies. Instead, [this script](../../scripts/cpp/build_ext_grpc.sh) will clone the source code from github, get the submodules and then build to the destination folder: `/build/ext/grpc/build`
