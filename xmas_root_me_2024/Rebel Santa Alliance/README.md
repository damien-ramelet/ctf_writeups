# Rebel Santa Allianc - Crypto

### Challenge description

After years of battle, Santa finally lost the war against The Grinch who took power over Christmas. To fight for a better future, Santa started to build the resistance to reclaim its rightful reign. This movement has been named the Rebel Santa Alliance.

### Challenge code

```python
from Crypto.PublicKey import RSA
from Crypto.Cipher import PKCS1_OAEP
from Crypto.Util.number import bytes_to_long

sk = RSA.generate(2048)
pk = sk.public_key()
rebel = pk.n
santa = pow(sk.p + sk.q, 25_12, sk.n)
alliance = pow(sk.p + 2024,  sk.q, sk.n)
grinch = bytes_to_long(PKCS1_OAEP.new(pk).encrypt(open("flag.txt", "rb").read()))
print(f"{rebel = }")
print(f"{santa = }")
print(f"{alliance = }")
print(f"{grinch = }")
```

And the output:
```
rebel = 22565061734039416113482972045260378850335551437603658289704615027418557202724145368752149375889961980363950180328323175210320614855936633182393255865179856287531160520701504181536636178888957690581313854928560767072864352042737573507134186874192330515294832153222689620292170062536844410158394875422189502091059641377172877646733866246591028663640957757623024460547759402035334150076953624006427372367403531317508296240139348595881946971512709010668970161839227064298658561166783993816926121542224966430871213596301099976336198714307311340588307183266135926332579316881966662145397817192575093538782843784869276100533
santa = 7090676761511038537715990241548422453589203615488971276028090010135172374067879024595027390319557301451711645742582972722821701885251846126401984831564226357658717867308193240479414897592113603389326639780104216744439110171644024870374198268635821406653829289038223890558052776266036276837616987636724890369390862354786266974335834195770641383651623579785433573634779559259801143085171276694299511739790904917106980811500310945911314872523635880520036346563681629465732398370718884575152165241470126313266744867672885335455602309001507861735607115050144930850784907731581914537046453363905996837218231392462387930807
alliance = 4807856659746554540384761225066384015772406312309222087365335807512750906135069862937039445867248288889534863419734669057747347873310770686781920717735265966670386330747307885825069770587158745071342289187203571110391360979885681860651287497925857531184647628597729278701941784086778427361417975825146507365759546940436668188428639773713612411058202635094262874088878972789112883390157572057747869114692970492381330563011664859153989944153981298671522781443901759988719136517303438758819537082141804649484207969208736143196893611193421172099870279407909171591480711301772653211746249092574185769806854290727386897332
grinch = 21347444708084802799009803643009154957516780623513439256397111284232540925976405404037717619209767862025457480966156406137212998283220183850004479260766295026179409197591604629092400433020507437961259179520449648954561486537590101708148916291332356063463410603926027330689376982238081346262884223521443089140193435193866121534545452893346753443625552713799639857846515709632076996793452083702019956813802268746647146317605419578838908535661351996182059305808616421037741561956252825591468392522918218655115102457839934797969736587813630818348913788139083225532326860894187123104070953292506518972382789549134889771498
```

### Solution

We are given a RSA-based challenge. For this task we have the output of the encryption, `grinch`, which is our encrypted flag, and the moduli (`n`, `rebel` in this case). We are given additionnals "hints", `santa` and `alliance`:

`santa` is the result of the sum of `p` and `q` (prime factors used to compute `n` by their product) raised to the power of `2512` modulo `n`

$`santa \equiv (p + q)^{2512} \mod{n}`$

`alliance` is the result of the sum of `p` and `2024` raised to the power of `q`, modulo `n`.

$`alliance \equiv (p+2024)^q \mod{n}`$

At this point, my goal is to either retrieve the sum of the value of $`(p+q)`$, which would allow me to directly compute $`\varphi{(n)}`$ and thus the private key, or to retrieve the value of `p`, allowing to factor `n` and in the same way compute $`\varphi{(n)}`$ and thus the private key.

We have two unknown variables mixed up together, it would be great if we could get rid of one of them, and solve one of the equation using substitution.

Actually, using modular arithmetic properties, it's possible !

[Chinese remainder theorem](https://en.wikipedia.org/wiki/Chinese_remainder_theorem) tells us that i we have a system of congruence such as:

$`x \equiv a1 \mod{n1}`$

$`x \equiv a2 \mod{n2}`$

If, and only if, $`n1`$ and $`n2`$ coprime, the following is also true:

$`x \equiv a1a2 \mod{n1n2}`$

This is exactly our situation, $`n`$ being a product of prime numbers, they are by definition coprimes. 


### Reducing our equations to one unknown variable

According to the [binomial theorem](https://en.wikipedia.org/wiki/Binomial_theorem), every power $`(x + y)^n`$ expands into something like

$`x^n + ... + y^n`$

All the middle term(s) being a multiple of `n`, they cancel out while wrapping around modulo `n`. Which give us this simple version:

$`santa \equiv p^{2512} + q^{2512} \mod{n}`$

As seen earlier, CRT allow us to write our equation wrapped around modulo $`q`$, conveniently cancelling out the `q` term:

$`santa \equiv p^{2512} \mod{q}`$

Repeating the process for the `alliance` equation gives the following:

$`alliance \equiv (p+2024) \mod{q}`$

We did it ! We now can express `p` using only known values and do some substitutions:

$`p \equiv alliance - 2024 \mod{q}`$

$`santa \equiv (alliance - 2024)^{2512} \mod{q}`$

Going a little further, we can rework the `santa` equation:

$`santa - (alliance - 2024)^{2512} \equiv 0 \mod{q}`$

What the above equation is telling us ? That $`santa - (alliance - 2024)^{2512}`$ is a multiple of $`q`$ !

### Recovering the flag

We can compute the `gcd` of rebel and the above value, and effectively $factor `n` !

$`q = gcd(rebel, santa - (alliance - 2024)^{2512})`$

We can now successfully decrypt the `grinch` value and recover the flag:

```python
In [1]: import math

In [2]: from Crypto.PublicKey import RSA
   ...: from Crypto.Cipher import PKCS1_OAEP
   ...: from Crypto.Util.number import bytes_to_long, long_to_bytes

In [3]: rebel = 2256506173403941611348297204526037885033555143760365828970461502741855720272414536875214937588996198036395018032832317521032061485593663318239325586517985628753116052070150418153663617888895769058131385492856076707286435204273757350713418687419233051529483
   ...: 215322268962029217006253684441015839487542218950209105964137717287764673386624659102866364095775762302446054775940203533415007695362400642737236740353131750829624013934859588194697151270901066897016183922706429865856116678399381692612154222496643087121359630109997
   ...: 6336198714307311340588307183266135926332579316881966662145397817192575093538782843784869276100533
   ...: santa = 7090676761511038537715990241548422453589203615488971276028090010135172374067879024595027390319557301451711645742582972722821701885251846126401984831564226357658717867308193240479414897592113603389326639780104216744439110171644024870374198268635821406653829
   ...: 289038223890558052776266036276837616987636724890369390862354786266974335834195770641383651623579785433573634779559259801143085171276694299511739790904917106980811500310945911314872523635880520036346563681629465732398370718884575152165241470126313266744867672885335
   ...: 455602309001507861735607115050144930850784907731581914537046453363905996837218231392462387930807
   ...: alliance = 4807856659746554540384761225066384015772406312309222087365335807512750906135069862937039445867248288889534863419734669057747347873310770686781920717735265966670386330747307885825069770587158745071342289187203571110391360979885681860651287497925857531184
   ...: 647628597729278701941784086778427361417975825146507365759546940436668188428639773713612411058202635094262874088878972789112883390157572057747869114692970492381330563011664859153989944153981298671522781443901759988719136517303438758819537082141804649484207969208736
   ...: 143196893611193421172099870279407909171591480711301772653211746249092574185769806854290727386897332
   ...: grinch = 213474447080848027990098036430091549575167806235134392563971112842325409259764054040377176192097678620254574809661564061372129982832201838500044792607662950261794091975916046290924004330205074379612591795204496489545614865375901017081489162913323560634634
   ...: 106039260273306893769822380813462628842235214430891401934351938661215345454528933467534436255527137996398578465157096320769967934520837020199568138022687466471463176054195788389085356613519961820593058086164210377415619562528255914683925229182186551151024578399347
   ...: 97969736587813630818348913788139083225532326860894187123104070953292506518972382789549134889771498

In [4]: q = math.gcd(rebel, santa - (alliance - 2024)**2512)

In [5]: p = rebel//q

In [6]: assert p*q==rebel

In [7]: n = rebel

In [8]: e = 2**16 + 1

In [9]: phi = (p-1)*(q-1)

In [10]: d = pow(e, -1, phi)

In [11]: PKCS1_OAEP.new(RSA.construct((n, e, d))).decrypt(long_to_bytes(grinch))
Out[11]: b'RM{63e90e80f5fd4d6797d146ce86608c9b6a937929a6f0498a389abe7bfc0dc185}'
```

Flag !