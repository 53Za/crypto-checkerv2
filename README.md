Overview
This project is an educational tool designed to generate private keys and mnemonic phrases for Bitcoin (BTC) and Ethereum (ETH) wallets, derive their corresponding public addresses, and check for existing balances on the blockchain. It uses the BIP-39 standard for mnemonic phrases and integrates with public APIs (e.g., Blockchain.info, Etherscan) to verify balances. The tool supports fallback APIs to handle rate limits or blocks and saves results to files when balances are found.
Note: This is for learning purposes only. Randomly generating and checking private keys could theoretically access existing funds, but the odds are astronomically low (1 in 2^256). Using this tool to exploit funds is unethical and illegal.

Features
Private Key Generation: Creates 256-bit private keys for BTC and ETH using cryptographically secure random numbers.

BIP-39 Mnemonic Phrases: Generates mock 12-word seed phrases from the full 2048-word BIP-39 English word list.

Address Derivation: Converts private keys to BTC addresses (via bitcoinlib) and ETH addresses (via eth_account).

Balance Checking:
BTC: Primary (Blockchain.info), Fallback (Blockcypher).

ETH: Primary (Etherscan), Fallback (Ethplorer).

File Output: Saves private keys, seed phrases, addresses, and balances to btc_finds.txt or eth_finds.txt when a balance is detected.

Continuous Operation: Loops until a balance is found or can be configured to keep searching.

Prerequisites
Python 3.6+

Required libraries:

pip install bitcoinlib eth-account requests mnemonic
--------------------------------


Example Output

Attempt 1: Checking BTC address 1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa
No BTC balance for 1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa
Attempt 1: Checking ETH address 0x1234567890abcdef1234567890abcdef12345678
No ETH balance for 0x1234567890abcdef1234567890abcdef12345678

If a balance is found:

Found BTC balance! Address: 1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa, Balance: 0.001 BTC
Saved to btc_finds.txt: 1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa with 0.001 BTC
-----------------------------------
