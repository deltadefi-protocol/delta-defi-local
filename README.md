# DeltaDefi Local build

This repo is to assist in building DeltaDefi locally, it will use a local devnet for testing purposes

### Usage

Give permissions to the scripts `prepare-devnet.sh`, `seed-devnet.sh` and `run-docker.sh`. Then simply

```
./run-docker.sh
```

It will prepare a local devnet with the configs in `devnet-config`

Then run docker images of a single `cardano-node` and 4 separate `hydra-node` then one `hydra-tui` to monitor the health of the hydra cluster.
