bonlulu-testnet:
	NIX_SSHOPTS='-i ~/.ssh/validators/union/bonlulu-testnet' GIT_LFS_SKIP_SMUDGE=1 nixos-rebuild switch --flake .#bonlulu --target-host root@testnet.bonlulu.uno -L --show-trace
