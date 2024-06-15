# Layers - Crypto

### Challenge description

### Challenge code

```python
import hashlib
import itertools
import os

def xor(key, data):
    return bytes([k ^ d for k, d in zip(itertools.cycle(key), data)])

def encrypt(phrase, message, iters=1000):
    key = phrase.encode()
    for _ in range(iters):
        key = hashlib.md5(key).digest()
        message = xor(key, message)
    return message

print('Welcome to my encryption service!')
print('Surely encrypting multiple times will make it more secure.')
print('1. Encrypt message.')
print('2. Encrypt (hex) message.')
print('3. See encrypted flag!')

phrase = os.environ.get('FLAG', 'missing')

choice = input('Pick 1, 2, or 3 > ')
if choice == '1':
    message = input('Your message > ').encode()
    encrypted = encrypt(phrase, message)
    print(encrypted.hex())
if choice == '2':
    message = bytes.fromhex(input('Your message > '))
    encrypted = encrypt(phrase, message)
    print(encrypted.hex())
elif choice == '3':
    print(encrypt(phrase, phrase.encode()).hex())
else:
    print('Not sure what that means.')
```


---

### Solution

We are given access to an oracle that take an input, cipher it and print it to us. We are also allowed to access the encrypted version of the key used (which appears to also be the flag).
The encryption algorithm is pretty straightforward. It takes the encryption key, hash it using md5 and xor the clear text against it, and do this for 1000 rounds.

We can immediatly see that the encryption algorithm is 100% deterministic. Given the same key, a same character will always lead to the same output.
Since we are allowed to access the encrypted version of the flag, we can try every printable characters against the oracle and keep only those the output match the cipher version of the flag. 

Let’s test it using the snippet given:

```python
from string import printable
from challenge import xor, encrypt

phrase = os.environ.get("FLAG")

cipher_text = encrypt(phrase, phrase.encode())
flag = ""
for _ in range(int(len(cipher_text))):
    for char in printable:
        test_ct = flag + char
        if encrypt(phrase, test_ct.encode()) == cipher_text[:len(test_ct)]:
            flag += char
            print(flag)
```

Which give us the following:

```
$ export FLAG=actf{test_flag} 
$ python exploit.py
a
ac
act
actf
actf{
actf{t
actf{te
actf{tes
actf{test
actf{test_
actf{test_f
actf{test_fl
actf{test_fla
actf{test_flag
actf{test_flag}
```

It works ! After handling the communication with the server, let’s try that against the oracle:

```
$ python exploit.py
a
ac
act
actf
actf{
actf{5
actf{59
actf{593
actf{593a
actf{593a7
actf{593a70
actf{593a704
actf{593a7043
actf{593a7043c
actf{593a7043ca
actf{593a7043ca5
actf{593a7043ca58
actf{593a7043ca58f
actf{593a7043ca58fc
actf{593a7043ca58fca
actf{593a7043ca58fcac
actf{593a7043ca58fcac7
actf{593a7043ca58fcac7e
actf{593a7043ca58fcac7ec
actf{593a7043ca58fcac7ec9
actf{593a7043ca58fcac7ec97
actf{593a7043ca58fcac7ec972
actf{593a7043ca58fcac7ec972e
actf{593a7043ca58fcac7ec972e3
actf{593a7043ca58fcac7ec972e3d
actf{593a7043ca58fcac7ec972e3dc
actf{593a7043ca58fcac7ec972e3dcf
actf{593a7043ca58fcac7ec972e3dcf0
actf{593a7043ca58fcac7ec972e3dcf01
actf{593a7043ca58fcac7ec972e3dcf012
actf{593a7043ca58fcac7ec972e3dcf0126
actf{593a7043ca58fcac7ec972e3dcf01263
actf{593a7043ca58fcac7ec972e3dcf01263}
```

Flag !
