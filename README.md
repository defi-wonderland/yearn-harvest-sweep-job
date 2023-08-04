# Harvest Sweep Stealth Job

Build on top of the stealth harvest, this job adds 2 new features:
- Sweep: Sweep old strategies which are not profitable, during a defined period of time, at the end of a reward period, using only any extra credit left.
- Packed set strategies: Instead of using 3 different storage slots in v2keeper, with OpenZeppelin Enumerable set for the strategy addresses, this uses a packed struct with the address-last work timestamp-required gas amount within a single storage slot, reducing gas consumption a lot (as these 3 are accessed within the same context).

Sweep mechanic:
![image](https://user-images.githubusercontent.com/83670532/225085034-8c97ac86-52a2-4a9d-b45b-c71dc25c3730.png)


This repo is [Foundry powered](https://book.getfoundry.sh/), see [the template commands](https://github.com/defi-wonderland/solidity-hardhat-boilerplate) for a list of available functionnalities.