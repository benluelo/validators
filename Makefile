# NIX_SSHOPTS='-i bonlulu-testnet' 
bonlulu-testnet:
	GIT_LFS_SKIP_SMUDGE=1 nixos-rebuild switch --flake .#bonlulu --target-host root@testnet.bonlulu.uno -L --show-trace
