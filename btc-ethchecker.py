import secrets
import random
import requests
from bitcoinlib.keys import Key  # For BTC key to address
from eth_account import Account  # For ETH key to address
import time

# Simplified BIP-39 wordlist (for demo purposes)
word_list = ["apple", "brave", "cloud", "dream", "eagle", "flame", "grape", "honey", 
             "island", "jazz", "kitten", "lemon", "mango", "night", "ocean", "piano"]

def generate_btc():
    private_key = secrets.token_hex(32)
    seed_phrase = " ".join(random.choice(word_list) for _ in range(12))
    key = Key(private_key, is_private=True)
    address = key.address()
    return private_key, seed_phrase, address

def generate_eth():
    private_key = secrets.token_hex(32)
    seed_phrase = " ".join(random.choice(word_list) for _ in range(12))
    account = Account.from_key(private_key)
    address = account.address
    return private_key, seed_phrase, address

def check_btc_balance(address):
    # Primary: Blockchain.info
    url = f"https://blockchain.info/q/addressbalance/{address}"
    try:
        response = requests.get(url)
        if response.status_code == 200:
            balance_satoshi = int(response.text)
            return balance_satoshi / 10**8
        else:
            print(f"Blockchain.info failed for BTC {address}: {response.status_code}")
    except Exception as e:
        print(f"Blockchain.info error for BTC {address}: {e}")

    # Fallback: Blockcypher
    url = f"https://api.blockcypher.com/v1/btc/main/addrs/{address}/balance"
    try:
        response = requests.get(url)
        if response.status_code == 200:
            data = response.json()
            return data['balance'] / 10**8
        else:
            print(f"Blockcypher failed for BTC {address}: {response.status_code}")
    except Exception as e:
        print(f"Blockcypher error for BTC {address}: {e}")
    return 0

def check_eth_balance(address):
    # Primary: Etherscan (requires API key in real use)
    url = f"https://api.etherscan.io/api?module=account&action=balance&address={address}&tag=latest"
    try:
        response = requests.get(url)
        if response.status_code == 200:
            data = response.json()
            if data['status'] == "1":
                return int(data['result']) / 10**18  # Wei to ETH
            else:
                print(f"Etherscan failed for ETH {address}: {data['message']}")
        else:
            print(f"Etherscan failed for ETH {address}: {response.status_code}")
    except Exception as e:
        print(f"Etherscan error for ETH {address}: {e}")

    # Fallback: Ethplorer
    url = f"https://api.ethplorer.io/getAddressInfo/{address}?apiKey=freekey"
    try:
        response = requests.get(url)
        if response.status_code == 200:
            data = response.json()
            return float(data['ETH']['balance'])
        else:
            print(f"Ethplorer failed for ETH {address}: {response.status_code}")
    except Exception as e:
        print(f"Ethplorer error for ETH {address}: {e}")
    return 0

def save_to_file(filename, private_key, seed_phrase, address, balance):
    with open(filename, "a") as f:
        f.write(f"Date: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Private Key: {private_key}\n")
        f.write(f"Seed Phrase: {seed_phrase}\n")
        f.write(f"Address: {address}\n")
        f.write(f"Balance: {balance} {'BTC' if 'btc' in filename else 'ETH'}\n")
        f.write("====================\n")
    print(f"Saved to {filename}: {address} with {balance} {'BTC' if 'btc' in filename else 'ETH'}")

if __name__ == "__main__":
    attempts = 0
    while True:
        attempts += 1
        # BTC Check
        btc_priv, btc_seed, btc_addr = generate_btc()
        print(f"Attempt {attempts}: Checking BTC address {btc_addr}")
        btc_balance = check_btc_balance(btc_addr)
        if btc_balance > 0:
            print(f"Found BTC balance! Address: {btc_addr}, Balance: {btc_balance} BTC")
            save_to_file("btc_finds.txt", btc_priv, btc_seed, btc_addr, btc_balance)
        else:
            print(f"No BTC balance for {btc_addr}")

        # ETH Check
        eth_priv, eth_seed, eth_addr = generate_eth()
        print(f"Attempt {attempts}: Checking ETH address {eth_addr}")
        eth_balance = check_eth_balance(eth_addr)
        if eth_balance > 0:
            print(f"Found ETH balance! Address: {eth_addr}, Balance: {eth_balance} ETH")
            save_to_file("eth_finds.txt", eth_priv, eth_seed, eth_addr, eth_balance)
        else:
            print(f"No ETH balance for {eth_addr}")

        time.sleep(1)  # Avoid rate limits
