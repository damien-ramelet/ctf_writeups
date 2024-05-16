# Poor Random Number Generator 2/2 - Cryptanalyse - Moyen

### Énoncé

Félicitations ! C'est vrai que mon PRNG précédent n'était pas terrible, on aurait pu voler mes affaires...
Je l'ai donc patché pour pouvoir rentrer habillé ! J'ai chiffré un nouveau fichier PNG et, cette fois-ci, j'ai essayé de limiter les données en clair qui ont fuité. Essayez de casser celui-là.

### Code du challenge

Le code source et les fichiers fournis se trouvent le fichier `challenge.zip`

___

### Résolution

On nous fournit le code source qui a servi à chiffrer le flag, le flag chiffré ainsi qu’une toute petite portion du clair (35 bytes) qui correspondent à l’entête du png.

```bash
 $ cat 404ctf_2024/poor_random_number_generator_2_2/flag.png.part
�PNG
�
IHDR����C%
```

L’image a été chiffrée en effectuant un `xor` de chaque byte du clair avec un byte issu de `CombinerGenerator`.
Cette classe prend en entrée une fonction `combine` et trois [LFSR](https://en.wikipedia.org/wiki/Linear-feedback_shift_register).

Quelques mots sur les LFSR du code fourni :

Chaque LFSR est initialisé avec une liste de 19 bits et les exposants de trois polynomes. Chaque LFSR va générer un bit, directement dépendant du state et du polynome avec lequel il a été initialisé. Chaque nouveau bit va prendre la place du premier dans le state, et l’ensemble est décalé vers la droite. À chaque génération de nouveau bit, on perd donc l’information du plus à droite. Au bout de 19 appels à `LFSR.generateBit`, on a donc perdu le state initial, qui a été remplacé par 19 nouveaux bits, dont les valeurs dépendent **directement du state et du polynome**.

Pour obtenir chaque byte utilisé pour chiffrer le flag (obtenue via `CombinerGenerator.generateByte`), on passe par les étapes suivantes :

- Appel à `L1.generateBit` pour obtenir un bit b1
- Appel à `L2.generateBit` pour obtiner un bit b2
- Appel à `L3.generateBit` pour obtenir un bit b3
- Obtenir un bit b4 grâce à l’appel de `combine(b1, b2, b3)` (ligne 20, dans generator.py)
- Répétez 8 fois ces étapes pour obtenir un byte de notre clé de chiffrement

Ces bytes de chiffrement dépendent exclusivement des bits de sorties de nos LFSR. Eux-même ne dépendant que du state avec lequel ils ont été initialisés, et l’opération `xor` étant parfaitement réversible (si vous avez `c = a ^ b`, vous pouvez retrouver `b` en faisant `a ^ c`), si on parvient à retrouver les 19 bits de chaque state, on peut effectuer l’opération inverse et déchiffrer le flag !

Comment faire alors ?

On peut pour commencer `xor` notre petite portion de clair avec le flag chiffré pour obtenir les premier bytes de chiffrement.

On sait que chaque bit `n` de chacun de ces bytes de chiffrement seront le résultat de `combine(L1.generateBit(), L2.generateBit(), L3.generateBit()`.

On sait également que nos states sont une liste de 19 bits, 3 successions de 19 0 ou 1.

On a donc une série de contraintes (3 listes de 19 éléments, qui sont soit un 0 soit un 1), ainsi qu’une série d’équation `n = (b1 * b2) ^ (b1 * b3) ^ (b2 * b3)`.

On peut dégainer `z3` et tenter de résoudre tout ça.

Le script de résolution :

```python
import z3
from LFSR import LFSR
from generator import CombinerGenerator

# Took from encrypt.py
def xor(b1, b2):
	return bytes(a ^ b for a, b in zip(b1, b2))

# Took from encrypt.py
poly1 = [19,5,2,1] # x^19+x^5+x^2+x
poly2 = [19,6,2,1] # x^19+x^6+x^2+x
poly3 = [19,9,8,5] # x^19+x^9+x^8+x^5

def combine(x1, x2, x3):
    """Rewrite `combine` using arithmetic equivalent of `AND`: multiplication""" 
    return (x1 * x2) ^ (x1 * x3) ^ (x2 * x3)

with open("flag.png.part", "rb") as f:
    clear_partial_content = f.read()

with open("flag.png.enc", "rb") as f:
    encrypted_content = f.read()

# We now have our first bytes used to cipher the flag
key = xor(clear_partial_content, encrypted_content)

# Turn the bytes into bits
bits = [int(bit) for byte in key for bit in format(byte, "08b")]

solver = z3.Solver()

# Define our constraints, we are looking for 3 array of 19 bits
state_1 = [z3.BitVec(f"s1_{i}", 1) for i in range(19)]
state_2 = [z3.BitVec(f"s2_{i}", 1) for i in range(19)]
state_3 = [z3.BitVec(f"s3_{i}", 1) for i in range(19)]

L1 = LFSR(fpoly=poly1, state=state_1)
L2 = LFSR(fpoly=poly2, state=state_2)
L3 = LFSR(fpoly=poly3, state=state_3)

# Defining our equations
# Every bit in the key is the result of `combine(b1, b2, b3)`
for bit in bits:
    solver.add(bit == combine(L1.generateBit(), L2.generateBit(), L3.generateBit()))

assert solver.check() == z3.sat

print(solver.model())

#[s2_16 = 1,
# s3_10 = 1,
# s2_9 = 0,
# s1_6 = 1,
# s1_11 = 1,
#...
#]

# We successfully retrieve our states, we can simply copy/paste the source code we are given
# and reverse the operation
result = {
"s2_16": 1,
"s3_10": 1,
"s2_9": 0,
"s1_6": 1,
"s1_11": 1,
"s1_7": 1,
"s3_2": 0,
"s3_9": 0,
"s2_14": 1,
"s2_3": 0,
"s2_18": 0,
"s2_2": 0,
"s2_15": 0,
"s2_8": 1,
"s1_9": 0,
"s1_12": 0,
"s1_1": 0,
"s3_1": 1,
"s2_5": 1,
"s3_8": 0,
"s1_13": 0,
"s2_11": 0,
"s3_15": 1,
"s1_4": 1,
"s1_15": 1,
"s3_7": 0,
"s3_18": 1,
"s2_12": 1,
"s3_6": 1,
"s2_6": 1,
"s1_2": 1,
"s2_4": 0,
"s3_4": 0,
"s2_1": 0,
"s2_0": 1,
"s2_7": 1,
"s3_13": 0,
"s2_10": 0,
"s3_12": 0,
"s1_17": 1,
"s1_10": 1,
"s2_17": 1,
"s3_16": 1,
"s1_3": 0,
"s1_18": 1,
"s3_11": 0,
"s1_8": 1,
"s1_16": 1,
"s3_0": 1,
"s3_14": 1,
"s3_3": 1,
"s3_5": 0,
"s1_5": 1,
"s2_13": 1,
"s1_0": 1,
"s1_14": 1,
"s3_17": 1
}

L1 = LFSR(fpoly=poly1, state=[result[f"s1_{i}"] for i in range(19)])
L2 = LFSR(fpoly=poly2, state=[result[f"s2_{i}"] for i in range(19)])
L3 = LFSR(fpoly=poly3, state=[result[f"s3_{i}"] for i in range(19)])

generator = CombinerGenerator(combine, L1, L2, L3)

# read the encrypted flag
with open("flag.png.enc","rb") as f:
	encrypted_flag = f.read()

#decrypt the flag
decrypted_flag = b''
for i in range(len(encrypted_flag)):
	random = generator.generateByte()
	byte = [encrypted_flag[i]]
	decrypted_flag += xor(byte,random)

#write decrypted flag
with open("decrypted_flag.png","wb") as f:
	f.write(decrypted_flag)
```

```bash
$ file decrypted_flag.png 
decrypted_flag.png: PNG image data, 1920 x 1080, 8-bit/color RGBA, non-interlaced
$ open decrypted_flag.png
```

![flag](decrypted_flag.png)
Flag !


### Solution intended

Après discussion avec l'auteur du challenge, il s'avère que la solution attendue était une attaque statistique.
Il fallait en effet remarquer que la fonction `combine` permettait une [correlation attack](https://en.wikipedia.org/wiki/Correlation_attack).
Les bits de sorties du générateur pouvaient en effet être très fortement corrélées aux bits d'entrées des LFSR.


Le script de résolution en utilisant cette attaque statistique (écrit très rapidement):


```python
from itertools import product, permutations
from generator import CombinerGenerator
from LFSR import LFSR
poly1 = [19, 5, 2, 1]  # x^19+x^5+x^2+x
poly2 = [19, 6, 2, 1]  # x^19+x^6+x^2+x
poly3 = [19, 9, 8, 5]  # x^19+x^9+x^8+x^5


def xor(b1, b2):
    return bytes(a ^ b for a, b in zip(b1, b2))


def combine(x1, x2, x3):
    return (x1 and x2) ^ (x1 and x3) ^ (x2 and x3)


with open("flag.png.part", "rb") as f:
    clear_part_content = f.read()

with open("flag.png.enc", "rb") as f:
    encrypted_content = f.read()

key = xor(clear_part_content, encrypted_content)

key_as_bits = [int(bit) for byte in key for bit in format(byte, "08b")]

# We are looking an array of 19 bits, 0 or 1. Which give us 2**19 possibilities.
possible_initial_state_1 = []
for state in product([0, 1], repeat=19):
    rate = 0
    L = LFSR(fpoly=poly1, state=list(state))
    for i in key_as_bits:
        if i == L.generateBit():
            rate += 1
    if 0.70 <= rate / len(key_as_bits) <= 0.80:
        possible_initial_state_1.append(state)
print(f"Found {len(possible_initial_state_1)} for state_1", possible_initial_state_1)
# Found 1 for state_1 [(1, 0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0, 1, 1, 1, 1, 1)]

possible_initial_state_2 = []
for state in product([0, 1], repeat=19):
    rate = 0
    L = LFSR(fpoly=poly2, state=list(state))
    for i in key_as_bits:
        if i == L.generateBit():
            rate += 1
    if 0.70 <= rate / len(key_as_bits) <= 0.80:
        possible_initial_state_2.append(state)
print(f"Found {len(possible_initial_state_2)} for state_2", possible_initial_state_2)
# Found 1 for state_2 [(1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 0)]

possible_initial_state_3 = []
for state in product([0, 1], repeat=19):
    rate = 0
    L = LFSR(fpoly=poly3, state=list(state))
    for i in key_as_bits:
        if i == L.generateBit():
            rate += 1
    if 0.70 <= rate / len(key_as_bits) <= 0.80:
        possible_initial_state_3.append(state)
print(f"Found {len(possible_initial_state_3)} for state_3", possible_initial_state_3)
# Found 1 for state_3 [(1, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1)]

for state_1, state_2, state_3 in permutations([*possible_initial_state_1, *possible_initial_state_2, *possible_initial_state_3], 3):
    L1 = LFSR(fpoly=poly1, state=list(state_1))
    L2 = LFSR(fpoly=poly2, state=list(state_2))
    L3 = LFSR(fpoly=poly3, state=list(state_3))

    generator = CombinerGenerator(combine, L1, L2, L3)

    key_attempt = [generator.generateBit() for i in range(len(key_as_bits))]

    if key_attempt == key_as_bits:
        L1 = LFSR(fpoly=poly1, state=list(state_1))
        L2 = LFSR(fpoly=poly2, state=list(state_2))
        L3 = LFSR(fpoly=poly3, state=list(state_3))

        generator = CombinerGenerator(combine, L1, L2, L3)

        with open("flag.png.enc", "rb") as f:
            encrypted_content = f.read()

        clear_content = b""

        for enc_byte in encrypted_content:
            clear_content += xor([enc_byte], generator.generateByte())

        with open("decrypted_flag_correlation_attack.png", "wb") as f:
            f.write(clear_content)
```

```bash
$ file decrypted_flag_correlation_attack.png
decrypted_flag_correlation_attack.png: PNG image data, 1920 x 1080, 8-bit/color RGBA, non-interlaced
$ open decrypted_flag_correlation_attack.png
```

![flag](decrypted_flag.png)
Flag !

