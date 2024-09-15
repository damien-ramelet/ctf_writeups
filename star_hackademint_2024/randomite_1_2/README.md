# Randomite [1/2] - Crypto

### Challenge description

Mon secret est masqué avec de l'aléatoire sécurisé, jamais tu n'accédera à mes données

(My secret is masked using true random, you’ll never access my data)

### Challenge code

```python
from Crypto.Random.random import randint

FLAG = open("flag.txt", "r").read().encode()

def getByte():
    return randint(0, 256) & 0xff

def xor(a, b):
    return bytes([i ^ j for i, j in zip(a, b)])

while True:
    I = input(">")
    if I[:9] == "J'ai faim":
        for _ in range(I.count("m")):
            key = [getByte() for _ in FLAG]
            print("Mange :", xor(FLAG, key).hex())
    else:
        print("Cowboy terminé")
        exit()
```


---

### Solution

We are given a One Time Pad oracle. It takes an input, `J’ai faim`, and given how many times the letter `m` appears, outputs as many encrypted flag versions.

OTP is an encryption technique [unconditionally secure and impossible to crack](https://en.wikipedia.org/wiki/One-time_pad) if, and only if, a few conditions are met:

- The key must be (at least) as long as the plaintext
- The key must be truly random
- The key must never be reused
- The key must be kept secret (aside from communicating parties)

Studying the snippet, it appears that all of these conditions are met by the oracle:
- This line `key = [getByte() for _ in FLAG]` ensures the key is as long as the plaintext.
- The key is truly random (`Crypto.Random.random.randint` implements `urandom` [hunder the hood](https://github.com/Legrandin/pycryptodome/blob/master/lib/Crypto/Random/__init__.py#L31))
- The key is never reused, each iteration ensures that new bytes are (truly) randomly chosen 
- The key is obviously kept secret from us

However, there is a huge flaw in this implementation. We can ask, as many times as we want, for the same plaintext encrypted using different keys.
Can we take advantage of this ? Not so sure. The flag is usually written in [1337](https://en.wikipedia.org/wiki/Leet), so even if we can ask for thousands of ciphertexts, we won't be able to rely on frequency analysis. Moreover, the flag is in this form:

`Star{s0m3_l337}`

Which means special characters as well.
Let’s take a look at how the bytes are generated. It takes place in this function:
```python
def getByte():
    return randint(0, 256) & 0xff
```

It’s kind of odd. Why not do `randint(0, 255)` ? It would be the same thing. The description was talking about "masked secret", maybe it was about this ?
The author is using [bitmasking](https://en.wikipedia.org/wiki/Mask_(computing)) to ensure the return value is always lower or equal to 255.
But, why ? 256 being the upper bound, isn't it exclusive ?
Let's check the source code of [pycryptodome](https://en.wikipedia.org/wiki/Mask_(computing)):

```python
    def randint(self, a, b):
        """Return a random integer N such that a <= N <= b."""
        if not is_native_int(a) or not is_native_int(b):
            raise TypeError("randint requires integer arguments")
        N = self.randrange(a, b+1)
        assert a <= N <= b
        return N
```

No ! The upper bound is a possible value too. But what is the result of `256 & 255` ? It's 0 !

```python
In [1]: 256 & 255
Out[1]: 0
```

This completely wastes the randomness of this implementation. `0` has 2/256 chances to appear (if `randint` output 0, or 256), while any other bytes have 1/256 chances! Can we take advantage of this ? Certainly.

OTP xor each character of the plaintext with a randomly chosen bytes, xoring a value with `0` gives the same value.

Putting all together, it means that the plaintext characters have twice as many chances to appear that any others !

Collecting sufficiently ciphertexts and the plaintext will leak.

```python
from pwn import *

count = 10000

if args.REMOTE:
    p = remote("challenges.hackademint.org", 31564)
else:
    p = process("./chall.py")

p.recvuntil(b">")
p.sendline(b"J'ai faim"+b"m"*count)
cipher_texts = p.recvuntil(b">")

occurrences = {}
for ct in cipher_texts.split(b"\n"):
    # Mange : 2ddf8cb36aa44525941c05d61f95f083ac89e931a8c887ee0173 -> 2ddf8cb36aa44525941c05d61f95f083ac89e931a8c887ee0173
    ct = ct[8:]
    for i, _byte in enumerate(bytes.fromhex(ct.decode())):
        # printable character
        if 33 <= _byte <= 126:
            if i not in occurrences:
                occurrences[i] = {_byte: 0}
            if _byte not in occurrences[i]:
                occurrences[i][_byte] = 0
            occurrences[i][_byte] += 1

print("Flag is: ", end="")
for p in sorted(list(occurrences)):
    most_common_char = sorted(occurrences[p].items(), key=lambda item: item[1], reverse=True)[0][0]
    print(chr(most_common_char), end="")
print()
```

Let's try locally:

```bash
$ cat flag.txt 
Star{7hi3_1s_4_fak3_f1a6}
$ python exploit.py
[+] Starting local process './chall.py': pid 64915
Flag is: Star{7hi3_1s_4_fak3_f1a6}+
[*] Stopped process './chall.py' (pid 64915)
```

It works !

Now, remotly:

```bash
$ python exploit.py REMOTE  
[+] Opening connection to challenges.hackademint.org on port 31564: Done
Flag is: Star{Why_s0_nuLL_O_o_?l}
[*] Closed connection to challenges.hackademint.org port 3156
```

Flag !
