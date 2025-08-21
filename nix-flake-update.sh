# Running nix flake update somtimes hit the github rate limit.
# This script allows you to update flakes using a GitHub access token to bypass the rate limit. 

nix flake update --option access-tokens "github.com=$(gh auth token)"

# or
# $ nix flake update --option access-tokens "github.com=<your-token>"


