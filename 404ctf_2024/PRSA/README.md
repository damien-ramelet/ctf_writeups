# Plongeon Super Rapide Artistique - Cryptanalyse - Moyen

### Énoncé

Vous vous avancez sur le plongeoir, la foule est tellement en liesse que la planche en tremble. C'est le dernier saut avant d'avoir votre note finale et donc votre classement pour ce sport. Vous sautez, le monde se ralentit et, comme à l'entrainement, vous effectuez l'enchaînement de figures que vous avez travaillées. Une fois la tête sortie de l'eau, personne du jury ne montre de note ! Un flash vous frappe, c'est vrai que la note est transmise par chiffrement RSA ! Mais après vos multiples figures aériennes, vous ne vous souvenez que de votre clef publique, et de la trajectoire que vous avez empruntée...

### Code du challenge

```python
from sage.all import *
from Crypto.Util.number import bytes_to_long, isPrime, getRandomNBitInteger
from secret import flag

m = bytes_to_long(flag)

D = 7
R = 32
nbit = 512

def genPoly(deg):
    F = PolynomialRing(ZZ, "x")
    x = F.gen()

    P = 0
    coeffs = []
    for i in range(deg + 1):
        c = getRandomNBitInteger(R)
        coeffs.append(c)
        P += c * x ** i
    P //= GCD(coeffs)
    return P

def genParent(deg):
    P, Q = genPoly(D), genPoly(D)
    while P.gcd(Q) != 1 or len(list(P.change_ring(QQ).factor())) > 1 or len(list(Q.change_ring(QQ).factor())) > 1 :
        P, Q = genPoly(D), genPoly(D)
    return P, Q

def genPrimes(P, Q, l):
    t = (l - R) // D

    r = getRandomNBitInteger(t)
    while not (isPrime(P(r)) and isPrime(Q(r))) :
        r = getRandomNBitInteger(t)

    return P(r), Q(r)

P, Q = genParent(D)
N = P*Q

print("N =", N, "\n")

p, q = genPrimes(P, Q, nbit)

n = p*q
print("n =", p*q)

c = pow(m, 65537, n)

print("c =", c)


# N = 9621137267597279445*x^14 + 18586175928444648302*x^13 + 32676401831531099971*x^12 + 42027592883389639924*x^11 + 51798494845427766041*x^10 + 63869556820398134000*x^9 + 74077517072964271516*x^8 + 79648012933926385783*x^7 + 69354747135812903055*x^6 + 59839859116273822972*x^5 + 48120985784611588945*x^4 + 36521316280908315838*x^3 + 26262107762070282460*x^2 + 16005081865177344119*x + 5810204145325142255 
# n = 60130547801168751450983574194169752606596547774564695794919298973251203587128237799602582911050022571941793197314565314876508860461087209144687558341117955877761335067848122512358149929745084363835027292307961660634453113069168408298081720503728087287329906197832876696742245078666352861209105027134133927
# c = 15129303695051503318505193172155921684909431243538868778377472653134183034984012506799855760917107279844275732327557949646134247015031503441468669978820652020054856908495646419146697920950182671202962511480958513703999302195279666734261744679837757391212026023983284529606062512100507387854428089714836938
```

___

### Résolution

Le flag a été chiffré à l'aide de l'algorithme RSA et l'objectif est de récupérer le clair.

On nous fournit le code qui a été utilisé ainsi que diverses valeurs :

- `c`, le ciphertext (le flag chiffré)
- `n`, le modulo de chiffrement
- `N`, un polynome, à ce stade, je ne suis pas très sur de quoi faire avec cette valeur.

Rapidement, RSA fonctionne de cette manière :

- Prendre deux nombres premiers `p` et `q`
- Calculer `n`, tel que `n = p * q`
- Calculer `phi`, tel que `phi = (p - 1) * (q - 1)`
- Choisir un nombre premier `e` tel que `1 < e < phi`, c'est l'exposant de chiffrement (la clé publique).
- Calculer `d`, l'inverse modulaire de `e` (en python `d = pow(e, -1, phi)`), c'est l'exposant de déchiffrement (la clé privée, avec les valeurs p et q)
- On peut désormais faire `ciphertext = clear_text ^ e (mod n)` (en python `c = pow(m, e, n)` et `clear_text = ciphertext ^ d (mod n)` (en python `m = pow(c, d, n)`)

Je suis un peu intrigué par la première grosse portion du code qui ne semble pas avoir de grand rapport avec la méthode classique du RSA, sinon que l'on obtient `p` et `q` grâce à `P` et `Q` et via `genPrimes`. Si on décortique le code, `genParent` est appelé en premier et génère deux polynomes de degré 7. `N` est calculé en multipliant ensuite ces deux polynomes. C'est l'une des trois valeurs qui nous est fournie.
En itérant sur un nombre `r` choisi aléatoirement à chaque tour de boucle, `genPrimes` génère `p` et `q` via `P(r)` et `Q(r)`.
À partir de là, on retrouve le déroulement standard du RSA, jusqu'à obtenir le ciphertext.

L'auteur nous aurait-il laissé un indice dans le titre ? `Plongeon Super Rapide Arstistique` :thinking:. Ça ne veut pas dire grand chose. Par contre `PRSA` pourrait signifier `polynomial RSA`, ce qui dans le contexte fait sens. Le premier résultat de la recherche `polynomial RSA` sur Google nous mène droit sur ce mémoire : [Polynomial based RSA ](http://www.diva-portal.se/smash/get/diva2:823505/FULLTEXT01.pdf)

Bingo ! 

Deux heures plus tard et le papier en tête, je ne suis cependant guère plus avancé. J'ai appris beaucoup de choses sur le chiffrement RSA classique, et sur ce qu'apporte PRSA, mais rien d'utile pour la résolution du challenge. Un beau honneypot, mais ça valait le détour.

Reprenons en faisant abstraction de la partie polynomiale. On nous fournit le module de chiffrement, la clé publique, et nous devons obtenir la clé privée afin de pouvoir déchiffrer le flag.

On sait que la clé privée `d` est équivalente à `pub_key ^ -1 (mod phi)` où phi est équivalent à `(p - 1) * (q - 1)`.
Nous devons donc au préalable obtenir la valeur `x` telle que `N(x) = n`. Si on factorise `N` de sorte à obtenir deux polynomes `P` et `Q`, nous pourrons obtenir `p = P(x)` et `q = Q(x)`, calculer `phi` et déterminer la clé privée.

Essayons !

Le script de résolution:
```python
In [1]: from Crypto.Util.number import long_to_bytes, isPrime
   ...:
   ...: ciphertext = 151293036950515033185051931721559216849094312435388687783774726531341830349840125067998557609171072798442757323275579496461342470150315034414686699788206520200548569084956464191466979209501826712029625114809585137039993021952796667342617446798377573
   ...: 91212026023983284529606062512100507387854428089714836938
   ...: pub_key = 65537
   ...:
   ...: # We know that P(x) * Q(x) == N(x) == p*q == n, where p and q are primes
   ...: def N(x):
   ...:     return 9621137267597279445*x**14 + 18586175928444648302*x**13 + 32676401831531099971*x**12 + 42027592883389639924*x**11 + 51798494845427766041*x**10 + 63869556820398134000*x**9 + 74077517072964271516*x**8 + 79648012933926385783*x**7 + 69354747135812903055*x*
   ...: *6 + 59839859116273822972*x**5 + 48120985784611588945*x**4 + 36521316280908315838*x**3 + 26262107762070282460*x**2 + 16005081865177344119*x + 5810204145325142255
   ...:
   ...: n = 601305478011687514509835741941697526065965477745646957949192989732512035871282377996025829110500225719417931973145653148765088604610872091446875583411179558777613350678481225123581499297450843638350272923079616606344531130691684082980817205037280872873299061
   ...: 97832876696742245078666352861209105027134133927
   ...:
   ...: # Using sagemath, we can factorize N and thus obtain P and Q, hence
   ...: def P(x):
   ...:     return (3378269265*x**7 + 2605358264*x**6 + 3892229888*x**5 + 2653862544*x**4 + 3893610093*x**3 + 2932575439*x**2 + 2322600571*x + 2442728695)
   ...: def Q(x):
   ...:     return (2847948613*x**7 + 3305316598*x**6 + 3842203267*x**5 + 3431982396*x**4 + 2380377272*x**3 + 3816048455*x**2 + 4290534204*x + 2378571209)
   ...:
   ...: # We can also solve N(x) = n, which gave us
   ...: x = 259412336263511759112
   ...:
   ...: # Now, can get retrieve p and q
   ...: p = P(x)
   ...: q = Q(x)
   ...:
   ...: # Sanity checks
   ...: assert isPrime(p)
   ...: assert isPrime(q)
   ...: assert p*q == n
   ...:
   ...: phi = (p-1)*(q-1)
   ...:
   ...: priv_key= pow(pub_key, -1, phi)
   ...: flag = long_to_bytes(pow(ciphertext, priv_key, n))
   ...:
   ...: print(flag)
b'404CTF{8rAv0_v0U5_r3u55I5532_av3c_8Ri0_c3773_p3RF0RMaNC3_0daCI3u23}'
```

Flag !

