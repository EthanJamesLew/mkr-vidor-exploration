## Nix Development on M2

I developed some of the nix flake environment on my M2 machine. This is complicated as some
of the tooling specifically requires x86_64 linux/Windows. I tested some of the builds via Docker

First, you will need docker to build x86_64 images. This is done by configuring docker to build x86
images via setting the environment variable
```shell
export DOCKER_DEFAULT_PLATFORM=linux/x86_64
```

Now, create and enter a docker image
```shell
docker pull nixos/nix
docker run -it -v $PWD:/vidor nixos/nix
```

Nix may error out when building--I found disabling the syscall filtering fixes this
```shell
export NIX_CONFIG="filter-syscalls = false"
```

Now, you can build and develop via
```shell
nix develop --extra-experimental-features nix-command --extra-experimental-features flakes
```